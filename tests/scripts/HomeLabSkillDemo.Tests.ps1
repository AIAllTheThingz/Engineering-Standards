Describe 'Home-lab shared runner boundaries' {
    BeforeAll {
        $script:root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $script:runner = Join-Path $script:root 'scripts/Test-HomeLabSkillDemo.ps1'
    }

    It 'rejects a nested linked directory before Pester execution' {
        $project = Join-Path $script:root ("examples/.home-lab-link-test-" + [guid]::NewGuid())
        $target = Join-Path ([IO.Path]::GetTempPath()) ("home-lab-link-target-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $project, $target -Force | Out-Null
        try {
            $linkPath = Join-Path $project 'tests'
            try {
                $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
                New-Item -ItemType $linkType -Path $linkPath -Target $target -ErrorAction Stop | Out-Null
            }
            catch {
                Set-ItResult -Skipped -Because "Directory link creation is unavailable: $($_.Exception.Message)"
                return
            }

            $output = & pwsh -NoProfile -File $script:runner -ProjectPath $project -SkillName link-boundary-test 2>&1
            $LASTEXITCODE | Should -Not -Be 0
            ($output -join "`n") | Should -Match 'must not contain links or reparse points'
        }
        finally {
            if (Test-Path -LiteralPath (Join-Path $project 'tests')) {
                Remove-Item -LiteralPath (Join-Path $project 'tests') -Force
            }
            Remove-Item -LiteralPath $project, $target -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
