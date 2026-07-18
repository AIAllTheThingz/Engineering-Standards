BeforeAll {
    $script:root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $script:root 'scripts/UnifiedDiffValidation.psm1') -Force

    function New-TestDiff {
        param([Parameter(Mandatory)][string[]]$Lines)
        $path = Join-Path $TestDrive (([guid]::NewGuid().ToString('N')) + '.diff')
        [System.IO.File]::WriteAllLines($path, $Lines)
        $path
    }
}

Describe 'Unified diff validation' {
    It 'accepts a valid added-file diff' {
        $path = New-TestDiff @('diff --git a/demo.txt b/demo.txt','new file mode 100644','--- /dev/null','+++ b/demo.txt','@@ -0,0 +1,2 @@','+one','+two')
        (Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive).Status | Should -BeExactly 'Passed'
    }

    It 'rejects an incorrect new-line count' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -1,1 +1,3 @@',' same','+added')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*hunk count mismatch*'
    }

    It 'rejects an incorrect old-line count' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -1,2 +1,1 @@',' same')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*hunk count mismatch*'
    }

    It 'rejects a malformed hunk header' {
        $path = New-TestDiff @('diff --git a/demo b/demo','--- a/demo','+++ b/demo','@@ -1,1 +1,1 @',' same')
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*malformed or incomplete hunk header*'
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
        { Assert-UnifiedDiff -LiteralPath $path -RepositoryRoot $TestDrive } | Should -Throw '*header declares old=0 and new=35, but content has old=0 and new=36*'
    }
}
