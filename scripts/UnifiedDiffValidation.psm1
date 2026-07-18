Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-UnifiedDiff {
    <#
    .SYNOPSIS
    Statically validates the structure and hunk counts of a unified diff.
    .DESCRIPTION
    Reads a diff as inert text. The function never invokes the referenced files or
    any command found in the diff. Invalid input produces a deterministic,
    sanitized error containing only a repository-relative path, parser location,
    and fixed diagnostic category.
    .PARAMETER LiteralPath
    Path to the unified diff file to validate as inert text.
    .PARAMETER RepositoryRoot
    Repository boundary used to enforce containment and produce a relative path.
    .EXAMPLE
    Assert-UnifiedDiff -LiteralPath examples/demo/samples/change.diff -RepositoryRoot .
    .OUTPUTS
    A result object containing Path, HunkCount, and Passed status.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RepositoryRoot
    )

    try {
        $root = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($RepositoryRoot))
        $path = [System.IO.Path]::GetFullPath($LiteralPath)
    }
    catch {
        throw [System.IO.InvalidDataException]::new('Unified diff input or repository root path is invalid.')
    }

    try {
        $relativePath = [System.IO.Path]::GetRelativePath($root, $path)
    }
    catch {
        throw [System.IO.InvalidDataException]::new('Unified diff input path could not be evaluated safely.')
    }

    if (
        [System.IO.Path]::IsPathRooted($relativePath) -or
        $relativePath -eq '..' -or
        $relativePath.StartsWith("..$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::Ordinal) -or
        $relativePath.StartsWith("..$([System.IO.Path]::AltDirectorySeparatorChar)", [System.StringComparison]::Ordinal)
    ) {
        throw [System.IO.InvalidDataException]::new('Unified diff input must be beneath the repository root.')
    }

    $relativePath = $relativePath.Replace([System.IO.Path]::DirectorySeparatorChar, '/')
    if ([System.IO.Path]::AltDirectorySeparatorChar -ne [System.IO.Path]::DirectorySeparatorChar) {
        $relativePath = $relativePath.Replace([System.IO.Path]::AltDirectorySeparatorChar, '/')
    }

    try {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf -ErrorAction Stop)) {
            throw [System.IO.FileNotFoundException]::new()
        }

        $inputItem = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if (($inputItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw [System.IO.InvalidDataException]::new()
        }

        $candidate = $inputItem.Directory
        while ($null -ne $candidate -and $candidate.FullName -ne $root) {
            if (($candidate.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw [System.IO.InvalidDataException]::new()
            }

            $candidate = $candidate.Parent
        }
        if ($null -eq $candidate) {
            throw [System.IO.InvalidDataException]::new()
        }
    }
    catch {
        throw [System.IO.InvalidDataException]::new('Unified diff input does not exist, is not a file, or cannot be read safely.')
    }

    function New-DiffError {
        param(
            [Parameter(Mandatory)][string]$Category,
            [Parameter(Mandatory)][int]$InputLine,
            [Parameter(Mandatory)][int]$FileSection,
            [Parameter(Mandatory)][int]$Hunk,
            [Parameter(Mandatory)][string]$State,
            [int]$ExpectedOld,
            [int]$ExpectedNew,
            [int]$ActualOld,
            [int]$ActualNew
        )

        $description = switch ($Category) {
            'HunkCountMismatch' { "Hunk count mismatch; expected old=$ExpectedOld and new=$ExpectedNew, actual old=$ActualOld and new=$ActualNew." }
            'HunkBeforeFileHeaders' { 'Hunk appears before complete file headers.' }
            'MalformedHunkHeader' { 'Malformed or incomplete hunk header.' }
            'InvalidNumericRange' { 'Hunk header contains a numeric field outside the supported range.' }
            'FileSectionWithoutHunks' { 'File section contains no hunks.' }
            'EmptyHunkContent' { 'Empty hunk content line lacks a unified-diff prefix.' }
            'UnexpectedHunkContent' { 'Unexpected hunk content prefix.' }
            'UnexpectedContentBeforeFile' { 'Unexpected content before the first file section.' }
            'DuplicateOldFileHeader' { 'Duplicate or out-of-order old file header.' }
            'InvalidNewFileHeader' { 'New file header must follow exactly one old file header.' }
            'MetadataAfterFileHeaders' { 'Metadata appears after a file header.' }
            'UnexpectedContentOutsideHunk' { 'Unexpected content outside a recognized hunk.' }
            'NoFileSection' { 'No file section was found.' }
            default { 'The unified diff is invalid.' }
        }

        $message = "Invalid unified diff '$relativePath' at input line $InputLine, file section $FileSection, hunk $Hunk, state $State [$Category]: $description"
        [System.IO.InvalidDataException]::new($message)
    }

    try {
        $lines = @(Get-Content -LiteralPath $path -ErrorAction Stop)
    }
    catch {
        throw [System.IO.InvalidDataException]::new("Unified diff '$relativePath' could not be read safely.")
    }

    $inFile = $false
    $sawOldHeader = $false
    $sawNewHeader = $false
    $fileHasHunk = $false
    $hunkActive = $false
    $hunkStartLine = 0
    $expectedOld = 0
    $expectedNew = 0
    $actualOld = 0
    $actualNew = 0
    $hunkCount = 0
    $fileSection = 0
    $sectionHunk = 0
    $state = 'BeforeFile'

    function Complete-Hunk {
        if (-not $hunkActive) { return }
        if ($actualOld -ne $expectedOld -or $actualNew -ne $expectedNew) {
            throw (New-DiffError -Category 'HunkCountMismatch' -InputLine $hunkStartLine -FileSection $fileSection -Hunk $sectionHunk -State 'Hunk' -ExpectedOld $expectedOld -ExpectedNew $expectedNew -ActualOld $actualOld -ActualNew $actualNew)
        }
        Set-Variable -Name hunkActive -Value $false -Scope 1
    }

    function Start-Hunk {
        param(
            [Parameter(Mandatory)][string]$Header,
            [Parameter(Mandatory)][int]$InputLine
        )

        $nextHunk = $sectionHunk + 1
        if (-not $sawOldHeader -or -not $sawNewHeader) {
            throw (New-DiffError -Category 'HunkBeforeFileHeaders' -InputLine $InputLine -FileSection $fileSection -Hunk $nextHunk -State $state)
        }

        $match = [regex]::Match($Header, '^@@ -(?<oldStart>\d+)(?:,(?<oldCount>\d+))? \+(?<newStart>\d+)(?:,(?<newCount>\d+))? @@(?: .*)?$')
        if (-not $match.Success) {
            throw (New-DiffError -Category 'MalformedHunkHeader' -InputLine $InputLine -FileSection $fileSection -Hunk $nextHunk -State 'FileHeaders')
        }

        $numericValues = @{}
        foreach ($name in @('oldStart', 'oldCount', 'newStart', 'newCount')) {
            if (-not $match.Groups[$name].Success) { continue }
            $value = 0
            if (-not [int]::TryParse($match.Groups[$name].Value, [System.Globalization.NumberStyles]::None, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
                throw (New-DiffError -Category 'InvalidNumericRange' -InputLine $InputLine -FileSection $fileSection -Hunk $nextHunk -State 'FileHeaders')
            }
            $numericValues[$name] = $value
        }

        Set-Variable -Name hunkActive -Value $true -Scope 1
        Set-Variable -Name hunkStartLine -Value $InputLine -Scope 1
        Set-Variable -Name expectedOld -Value $(if ($numericValues.ContainsKey('oldCount')) { $numericValues['oldCount'] } else { 1 }) -Scope 1
        Set-Variable -Name expectedNew -Value $(if ($numericValues.ContainsKey('newCount')) { $numericValues['newCount'] } else { 1 }) -Scope 1
        Set-Variable -Name actualOld -Value 0 -Scope 1
        Set-Variable -Name actualNew -Value 0 -Scope 1
        Set-Variable -Name fileHasHunk -Value $true -Scope 1
        Set-Variable -Name hunkCount -Value ($hunkCount + 1) -Scope 1
        Set-Variable -Name sectionHunk -Value $nextHunk -Scope 1
        Set-Variable -Name state -Value 'Hunk' -Scope 1
    }

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $inputLine = $index + 1

        if ($hunkActive) {
            if ($line.StartsWith('@@', [System.StringComparison]::Ordinal)) {
                Complete-Hunk
                Start-Hunk -Header $line -InputLine $inputLine
                continue
            }
            if ($line.StartsWith('diff --git ', [System.StringComparison]::Ordinal)) {
                Complete-Hunk
                if (-not $fileHasHunk) {
                    throw (New-DiffError -Category 'FileSectionWithoutHunks' -InputLine $inputLine -FileSection $fileSection -Hunk $sectionHunk -State $state)
                }
                $fileSection++
                $sectionHunk = 0
                $inFile = $true
                $sawOldHeader = $false
                $sawNewHeader = $false
                $fileHasHunk = $false
                $state = 'FileMetadata'
                continue
            }
            if ($line -eq '\ No newline at end of file') { continue }
            if ($line.Length -eq 0) {
                throw (New-DiffError -Category 'EmptyHunkContent' -InputLine $inputLine -FileSection $fileSection -Hunk $sectionHunk -State 'Hunk')
            }
            switch ($line[0]) {
                ' ' { $actualOld++; $actualNew++ }
                '+' { $actualNew++ }
                '-' { $actualOld++ }
                default { throw (New-DiffError -Category 'UnexpectedHunkContent' -InputLine $inputLine -FileSection $fileSection -Hunk $sectionHunk -State 'Hunk') }
            }
            continue
        }

        if ($line.StartsWith('diff --git ', [System.StringComparison]::Ordinal)) {
            if ($inFile -and -not $fileHasHunk) {
                throw (New-DiffError -Category 'FileSectionWithoutHunks' -InputLine $inputLine -FileSection $fileSection -Hunk $sectionHunk -State $state)
            }
            $fileSection++
            $sectionHunk = 0
            $inFile = $true
            $sawOldHeader = $false
            $sawNewHeader = $false
            $fileHasHunk = $false
            $state = 'FileMetadata'
            continue
        }
        if (-not $inFile) {
            throw (New-DiffError -Category 'UnexpectedContentBeforeFile' -InputLine $inputLine -FileSection 0 -Hunk 0 -State 'BeforeFile')
        }
        if ($line.StartsWith('--- ', [System.StringComparison]::Ordinal)) {
            if ($sawOldHeader -or $sawNewHeader) {
                throw (New-DiffError -Category 'DuplicateOldFileHeader' -InputLine $inputLine -FileSection $fileSection -Hunk 0 -State $state)
            }
            $sawOldHeader = $true
            $state = 'FileHeaders'
            continue
        }
        if ($line.StartsWith('+++ ', [System.StringComparison]::Ordinal)) {
            if (-not $sawOldHeader -or $sawNewHeader) {
                throw (New-DiffError -Category 'InvalidNewFileHeader' -InputLine $inputLine -FileSection $fileSection -Hunk 0 -State $state)
            }
            $sawNewHeader = $true
            $state = 'FileHeaders'
            continue
        }
        if ($line.StartsWith('@@', [System.StringComparison]::Ordinal)) {
            Start-Hunk -Header $line -InputLine $inputLine
            continue
        }
        if ($line -match '^(?:new file mode|deleted file mode|old mode|new mode|similarity index|dissimilarity index|rename from|rename to|copy from|copy to|index) ') {
            if ($sawOldHeader -or $sawNewHeader) {
                throw (New-DiffError -Category 'MetadataAfterFileHeaders' -InputLine $inputLine -FileSection $fileSection -Hunk 0 -State $state)
            }
            continue
        }
        throw (New-DiffError -Category 'UnexpectedContentOutsideHunk' -InputLine $inputLine -FileSection $fileSection -Hunk $sectionHunk -State $state)
    }

    Complete-Hunk
    $endLine = [Math]::Max($lines.Count, 1)
    if (-not $inFile) {
        throw (New-DiffError -Category 'NoFileSection' -InputLine $endLine -FileSection 0 -Hunk 0 -State 'BeforeFile')
    }
    if (-not $fileHasHunk) {
        throw (New-DiffError -Category 'FileSectionWithoutHunks' -InputLine $endLine -FileSection $fileSection -Hunk $sectionHunk -State $state)
    }

    [pscustomobject]@{
        Path = $relativePath
        HunkCount = $hunkCount
        Status = 'Passed'
    }
}

Export-ModuleMember -Function Assert-UnifiedDiff
