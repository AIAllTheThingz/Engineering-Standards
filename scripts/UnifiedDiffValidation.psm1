Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-UnifiedDiff {
    <#
    .SYNOPSIS
    Statically validates the structure and hunk counts of a unified diff.
    .DESCRIPTION
    Reads a diff as inert text. The function never invokes the referenced files or
    any command found in the diff. Invalid input produces a deterministic error
    containing the repository-relative path and offending hunk when available.
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

    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $path = [System.IO.Path]::GetFullPath($LiteralPath)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Unified diff '$LiteralPath' does not exist or is not a file."
    }

    $relativePath = [System.IO.Path]::GetRelativePath($root, $path).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
    if ($relativePath -eq '..' -or $relativePath.StartsWith('../', [System.StringComparison]::Ordinal)) {
        throw "Unified diff '$path' must be beneath repository root '$root'."
    }

    function New-DiffError {
        param(
            [Parameter(Mandatory)][string]$Message,
            [string]$HunkHeader
        )

        $location = if ([string]::IsNullOrEmpty($HunkHeader)) { $relativePath } else { "$relativePath [$HunkHeader]" }
        [System.IO.InvalidDataException]::new("Invalid unified diff '$location': $Message")
    }

    $lines = @(Get-Content -LiteralPath $path)
    $inFile = $false
    $sawOldHeader = $false
    $sawNewHeader = $false
    $fileHasHunk = $false
    $hunkHeader = $null
    $expectedOld = 0
    $expectedNew = 0
    $actualOld = 0
    $actualNew = 0
    $hunkCount = 0

    function Complete-Hunk {
        if ($null -eq $hunkHeader) { return }
        if ($actualOld -ne $expectedOld -or $actualNew -ne $expectedNew) {
            throw (New-DiffError -Message "hunk count mismatch; header declares old=$expectedOld and new=$expectedNew, but content has old=$actualOld and new=$actualNew." -HunkHeader $hunkHeader)
        }
        Set-Variable -Name hunkHeader -Value $null -Scope 1
    }

    function Start-Hunk {
        param([Parameter(Mandatory)][string]$Header)

        if (-not $sawOldHeader -or -not $sawNewHeader) {
            throw (New-DiffError -Message 'hunk appears before complete --- and +++ file headers.' -HunkHeader $Header)
        }
        $match = [regex]::Match($Header, '^@@ -(?<oldStart>\d+)(?:,(?<oldCount>\d+))? \+(?<newStart>\d+)(?:,(?<newCount>\d+))? @@(?: .*)?$')
        if (-not $match.Success) {
            throw (New-DiffError -Message 'malformed or incomplete hunk header.' -HunkHeader $Header)
        }
        Set-Variable -Name hunkHeader -Value $Header -Scope 1
        Set-Variable -Name expectedOld -Value $(if ($match.Groups['oldCount'].Success) { [int]$match.Groups['oldCount'].Value } else { 1 }) -Scope 1
        Set-Variable -Name expectedNew -Value $(if ($match.Groups['newCount'].Success) { [int]$match.Groups['newCount'].Value } else { 1 }) -Scope 1
        Set-Variable -Name actualOld -Value 0 -Scope 1
        Set-Variable -Name actualNew -Value 0 -Scope 1
        Set-Variable -Name fileHasHunk -Value $true -Scope 1
        Set-Variable -Name hunkCount -Value ($hunkCount + 1) -Scope 1
    }

    foreach ($line in $lines) {
        if ($null -ne $hunkHeader) {
            if ($line.StartsWith('@@', [System.StringComparison]::Ordinal)) {
                Complete-Hunk
                Start-Hunk -Header $line
                continue
            }
            if ($line.StartsWith('diff --git ', [System.StringComparison]::Ordinal)) {
                Complete-Hunk
                if (-not $fileHasHunk) { throw (New-DiffError -Message 'file section contains no hunks.') }
                $inFile = $true
                $sawOldHeader = $false
                $sawNewHeader = $false
                $fileHasHunk = $false
                continue
            }
            if ($line -eq '\ No newline at end of file') { continue }
            if ($line.Length -eq 0) {
                throw (New-DiffError -Message 'empty hunk content line lacks a unified-diff prefix.' -HunkHeader $hunkHeader)
            }
            switch ($line[0]) {
                ' ' { $actualOld++; $actualNew++ }
                '+' { $actualNew++ }
                '-' { $actualOld++ }
                default { throw (New-DiffError -Message "unexpected hunk content prefix '$($line[0])'." -HunkHeader $hunkHeader) }
            }
            continue
        }

        if ($line.StartsWith('diff --git ', [System.StringComparison]::Ordinal)) {
            if ($inFile -and -not $fileHasHunk) { throw (New-DiffError -Message 'file section contains no hunks.') }
            $inFile = $true
            $sawOldHeader = $false
            $sawNewHeader = $false
            $fileHasHunk = $false
            continue
        }
        if (-not $inFile) {
            throw (New-DiffError -Message "unexpected content outside a file section: '$line'.")
        }
        if ($line.StartsWith('--- ', [System.StringComparison]::Ordinal)) {
            if ($sawOldHeader -or $sawNewHeader) { throw (New-DiffError -Message 'duplicate or out-of-order --- file header.') }
            $sawOldHeader = $true
            continue
        }
        if ($line.StartsWith('+++ ', [System.StringComparison]::Ordinal)) {
            if (-not $sawOldHeader -or $sawNewHeader) { throw (New-DiffError -Message '+++ file header must follow exactly one --- file header.') }
            $sawNewHeader = $true
            continue
        }
        if ($line.StartsWith('@@', [System.StringComparison]::Ordinal)) {
            Start-Hunk -Header $line
            continue
        }
        if ($line -match '^(?:new file mode|deleted file mode|old mode|new mode|similarity index|dissimilarity index|rename from|rename to|copy from|copy to|index) ') {
            if ($sawOldHeader -or $sawNewHeader) { throw (New-DiffError -Message "metadata appears after a file header: '$line'.") }
            continue
        }
        throw (New-DiffError -Message "unexpected content outside a recognized hunk: '$line'.")
    }

    Complete-Hunk
    if (-not $inFile) { throw (New-DiffError -Message 'no diff --git file section was found.') }
    if (-not $fileHasHunk) { throw (New-DiffError -Message 'file section contains no hunks.') }

    [pscustomobject]@{
        Path = $relativePath
        HunkCount = $hunkCount
        Status = 'Passed'
    }
}

Export-ModuleMember -Function Assert-UnifiedDiff
