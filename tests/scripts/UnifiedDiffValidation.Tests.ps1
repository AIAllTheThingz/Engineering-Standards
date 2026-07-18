BeforeAll {
    $script:root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $script:root 'scripts/UnifiedDiffValidation.psm1') -Force

    function New-TestDiff {
        param(
            [Parameter(Mandatory)][string[]]$Lines,
            [string]$Name = (([guid]::NewGuid().ToString('N')) + '.diff')
        )
        $path = Join-Path $TestDrive $Name
        [System.IO.File]::WriteAllLines($path, $Lines)
        $path
    }

    function Get-DiffFailureMessage {
        param(
            [Parameter(Mandatory)][string]$LiteralPath,
            [Parameter(Mandatory)][string]$RepositoryRoot
        )

        try {
            Assert-UnifiedDiff -LiteralPath $LiteralPath -RepositoryRoot $RepositoryRoot | Out-Null
            throw 'Expected Assert-UnifiedDiff to reject the fixture.'
        }
        catch [System.IO.InvalidDataException] {
            $_.Exception.Message
        }
    }
}

Describe 'Unified diff validation' {
    It 'accepts a valid added-file diff' {
        $path = New-TestDiff @('diff --git a/demo.txt b/demo.txt','new file mode 100644','--- /dev/null','+++ b/demo.txt','@@ -0,0 +1,2 @@','+one','+two')
        (Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive).Status | Should -BeExactly 'Passed'
    }

    It 'accepts a valid diff when the repository root has a trailing separator' {
        $path = New-TestDiff @('diff --git a/demo.txt b/demo.txt','--- a/demo.txt','+++ b/demo.txt','@@ -1 +1 @@',' context')
        $rootWithSeparator = $TestDrive + [System.IO.Path]::DirectorySeparatorChar
        (Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $rootWithSeparator).Status | Should -BeExactly 'Passed'
    }

    It 'rejects an incorrect new-line count' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -1,1 +1,3 @@',' same','+added')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*Hunk count mismatch*'
    }

    It 'rejects an incorrect old-line count' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -1,2 +1,1 @@',' same')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*Hunk count mismatch*'
    }

    It 'rejects a malformed hunk header' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -1,1 +1,1 @',' same')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*Malformed or incomplete hunk header*'
    }

    It 'counts context additions and removals in both ranges' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -2,3 +2,3 @@',' context','-before','+after',' tail')
        (Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive).HunkCount | Should -Be 1
    }

    It 'does not count file headers as hunk additions or removals' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -1 +1 @@','-before','+after')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Not -Throw
    }

    It 'accepts every committed review home-lab diff' {
        $paths = @(
            'examples/python-review-home-lab/samples/unsafe-maintenance.diff'
            'examples/bash-review-home-lab/samples/unsafe-maintenance.diff'
            'examples/terraform-review-home-lab/samples/unsafe-main.diff'
            'examples/powershell-review-home-lab/samples/unsafe-maintenance.diff'
        )
        foreach ($relativePath in $paths) {
            { Assert-UnifiedDiff -LiteralPath (Join-Path $script:root $relativePath) -RepositoryRoot $script:root } | Should -Not -Throw
        }
    }

    It 'detects the Terraform 35-versus-36 regression through generic counting' {
        $lines = @('diff --git a/main.tf b/main.tf','new file mode 100644','--- /dev/null','+++ b/main.tf','@@ -0,0 +1,35 @@') + @(1..36 | ForEach-Object { "+line $_" })
        $path = New-TestDiff $lines
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*expected old=0 and new=35, actual old=0 and new=36*'
    }

    It 'accepts multiple file sections and multiple hunks' {
        $path = New-TestDiff @(
            'diff --git a/one b/one','--- a/one','+++ b/one','@@ -1 +1 @@',' first',
            '@@ -3 +3 @@','-before','+after',
            'diff --git a/two b/two','--- a/two','+++ b/two','@@ -0,0 +1 @@','+second'
        )
        (Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive).HunkCount | Should -Be 3
    }

    It 'accepts the no-newline marker without changing hunk counts' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -0,0 +1 @@','+one','\ No newline at end of file')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Not -Throw
    }

    It 'rejects content outside the unified-diff grammar' {
        $path = New-TestDiff @('not a unified diff')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*UnexpectedContentBeforeFile*'
    }

    It 'never includes untrusted parser content in diagnostics' {
        $credentialAssignment = @('pass', 'word=ExampleOnlyCredential') -join ''
        $headerCredential = @('pass', 'word=EXAMPLE_HEADER_VALUE') -join ''
        $privateKeyMarker = @('-----BEGIN PRIVATE', ' KEY-----') -join ''
        $cases = @(
            @{
                Name = 'before-file.diff'; Line = 1; Section = 0; Hunk = 0; State = 'BeforeFile'; Category = 'UnexpectedContentBeforeFile'
                Lines = @($credentialAssignment)
            },
            @{
                Name = 'after-metadata.diff'; Line = 2; Section = 1; Hunk = 0; State = 'FileMetadata'; Category = 'UnexpectedContentOutsideHunk'
                Lines = @('diff --git a/demo b/demo','Bearer EXAMPLE_TOKEN_VALUE')
            },
            @{
                Name = 'after-headers.diff'; Line = 4; Section = 1; Hunk = 0; State = 'FileHeaders'; Category = 'UnexpectedContentOutsideHunk'
                Lines = @('diff --git a/demo b/demo','--- a/demo','+++ b/demo',"$privateKeyMarker EXAMPLE_ONLY")
            },
            @{
                Name = 'hunk-prefix.diff'; Line = 5; Section = 1; Hunk = 1; State = 'Hunk'; Category = 'UnexpectedHunkContent'
                Lines = @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -1 +1 @@','!ghp_EXAMPLEONLY_DO_NOT_USE_123456789')
            },
            @{
                Name = 'malformed-header.diff'; Line = 4; Section = 1; Hunk = 1; State = 'FileHeaders'; Category = 'MalformedHunkHeader'
                Lines = @('diff --git a/demo b/demo','--- a/demo','+++ b/demo',"@@ -1 +1 @ $headerCredential")
            },
            @{
                Name = 'metadata-after-header.diff'; Line = 4; Section = 1; Hunk = 0; State = 'FileHeaders'; Category = 'MetadataAfterFileHeaders'
                Lines = @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','index Bearer_EXAMPLE_INDEX_VALUE')
            },
            @{
                Name = 'second-section.diff'; Line = 9; Section = 2; Hunk = 1; State = 'FileHeaders'; Category = 'MalformedHunkHeader'
                Lines = @('diff --git a/one b/one','--- a/one','+++ b/one','@@ -0,0 +1 @@','+one','diff --git a/two b/two','--- a/two','+++ b/two','@@ -0,0 +1 @ internal-hostname.example.invalid/EXAMPLE')
            }
        )
        $forbidden = @(
            'ExampleOnlyCredential','EXAMPLE_TOKEN_VALUE','PRIVATE KEY','ghp_EXAMPLE',
            'EXAMPLE_HEADER_VALUE','Bearer_EXAMPLE_INDEX_VALUE','internal-hostname.example.invalid','!'
        )

        foreach ($case in $cases) {
            $path = New-TestDiff -Lines $case.Lines -Name $case.Name
            $message = Get-DiffFailureMessage -LiteralPath $path -RepositoryRoot $TestDrive
            $expectedPrefix = "Invalid unified diff '$($case.Name)' at input line $($case.Line), file section $($case.Section), hunk $($case.Hunk), state $($case.State) [$($case.Category)]"
            $message | Should -Match ([regex]::Escape($expectedPrefix))
            $message | Should -Not -Match ([regex]::Escape($TestDrive))
            $message | Should -Not -Match ([regex]::Escape($case.Lines[$case.Line - 1]))
            foreach ($value in $forbidden) {
                $message | Should -Not -Match ([regex]::Escape($value))
            }
        }
    }

    It 'sanitizes an oversized hunk numeric field' {
        $rawNumber = '999999999999999999999999999999999999999999'
        $path = New-TestDiff -Name 'oversized.diff' -Lines @('diff --git a/demo b/demo','--- a/demo','+++ b/demo',"@@ -$rawNumber +1 @@",' same')
        $message = Get-DiffFailureMessage -LiteralPath $path -RepositoryRoot $TestDrive
        $message | Should -Match ([regex]::Escape('[InvalidNumericRange]'))
        $message | Should -Not -Match ([regex]::Escape($rawNumber))
    }

    It 'does not retain optional hunk text in count errors' {
        $suffix = @('pass', 'word=EXAMPLE_TRAILING_HEADER_VALUE') -join ''
        $path = New-TestDiff -Name 'trailing-text.diff' -Lines @('diff --git a/demo b/demo','--- a/demo','+++ b/demo',"@@ -1 +1,2 @@ $suffix",' same')
        $message = Get-DiffFailureMessage -LiteralPath $path -RepositoryRoot $TestDrive
        $message | Should -Match ([regex]::Escape('[HunkCountMismatch]'))
        $message | Should -Not -Match ([regex]::Escape($suffix))
    }

    It 'sanitizes missing and external input path errors' {
        $missingName = 'missing-credential-shaped-ExampleOnlyCredential.diff'
        $missingPath = Join-Path $TestDrive $missingName
        $missingMessage = Get-DiffFailureMessage -LiteralPath $missingPath -RepositoryRoot $TestDrive
        $missingMessage | Should -BeExactly 'Unified diff input does not exist, is not a file, or cannot be read safely.'
        $missingMessage | Should -Not -Match ([regex]::Escape($missingName))

        $externalName = "external-credential-shaped-ExampleOnlyCredential-$([guid]::NewGuid().ToString('N')).diff"
        $externalPath = Join-Path (Split-Path -Parent $TestDrive) $externalName
        try {
            [System.IO.File]::WriteAllLines($externalPath, @((@('pass', 'word=ExampleOnlyCredential') -join '')))
            $externalMessage = Get-DiffFailureMessage -LiteralPath $externalPath -RepositoryRoot $TestDrive
            $externalMessage | Should -BeExactly 'Unified diff input must be beneath the repository root.'
            $externalMessage | Should -Not -Match ([regex]::Escape($externalName))
            $externalMessage | Should -Not -Match ([regex]::Escape((Split-Path -Parent $TestDrive)))
        }
        finally {
            Remove-Item -LiteralPath $externalPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects a linked input without disclosing the linked target' {
        $targetName = "target-credential-shaped-ExampleOnlyCredential-$([guid]::NewGuid().ToString('N')).diff"
        $targetPath = Join-Path (Split-Path -Parent $TestDrive) $targetName
        $linkPath = Join-Path $TestDrive 'linked-input.diff'
        try {
            [System.IO.File]::WriteAllLines($targetPath, @((@('pass', 'word=ExampleOnlyCredential') -join '')))
            try {
                New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -ErrorAction Stop | Out-Null
            }
            catch {
                Set-ItResult -Skipped -Because 'Symbolic-link creation is unavailable on this platform.'
                return
            }

            $message = Get-DiffFailureMessage -LiteralPath $linkPath -RepositoryRoot $TestDrive
            $message | Should -BeExactly 'Unified diff input does not exist, is not a file, or cannot be read safely.'
            $message | Should -Not -Match ([regex]::Escape($targetName))
            $message | Should -Not -Match 'ExampleOnlyCredential'
        }
        finally {
            Remove-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue
        }
    }
}
