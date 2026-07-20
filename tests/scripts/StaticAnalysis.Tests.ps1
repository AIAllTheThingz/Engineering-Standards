BeforeAll {
    $repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repoRoot 'scripts/StaticAnalysisTools.psm1') -Force
}

Describe 'Trusted Python and Bash source discovery' {
    BeforeEach { $root=Join-Path $TestDrive ([guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $root|Out-Null }

    It 'selects Python source, ignores generated directories, and reports only the exact reviewed exclusion' {
        New-Item -ItemType Directory (Join-Path $root 'samples'),(Join-Path $root 'build')|Out-Null
        Set-Content (Join-Path $root 'samples/unsafe.py') 'eval("x")'
        Set-Content (Join-Path $root 'samples/adjacent.py') 'value = 1'
        Set-Content (Join-Path $root 'build/generated.py') 'broken('
        $files=@(Get-TrustedSourceFiles -Root $root -Language Python -ExcludedRelativePath @('samples/unsafe.py'))
        @($files.relativePath) | Should -Contain 'samples/adjacent.py'
        @($files.relativePath) | Should -Not -Contain 'build/generated.py'
        ($files|Where-Object relativePath -eq 'samples/unsafe.py').excluded | Should -BeTrue
        ($files|Where-Object relativePath -eq 'samples/adjacent.py').excluded | Should -BeFalse
    }

    It 'detects extensionless Bash only through a bounded explicit Bash shebang' {
        Set-Content (Join-Path $root 'maintain') "#!/usr/bin/env bash`nprintf '%s' ok"
        Set-Content (Join-Path $root 'plain') 'printf test'
        $files=@(Get-TrustedSourceFiles -Root $root -Language Bash)
        @($files.relativePath) | Should -BeExactly @('maintain')
    }

    It 'fails closed for oversized source' {
        Set-Content (Join-Path $root 'large.py') ('x' * 20) -NoNewline
        { Get-TrustedSourceFiles -Root $root -Language Python -MaximumBytesPerFile 10 } | Should -Throw '*exceeds*byte limit*'
    }
}

Describe 'Static validator prerequisite honesty' {
    It 'returns Blocked evidence when trusted Ruff is missing' {
        $root=Join-Path $TestDrive 'python-missing';New-Item -ItemType Directory $root|Out-Null;Set-Content (Join-Path $root 'safe.py') 'value = 1'
        & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/Test-PythonStaticAnalysis.ps1') -Path $root -RuffPath (Join-Path $root 'missing-ruff') -OutputJson result.json
        $LASTEXITCODE | Should -Be 3
        (Get-Content (Join-Path $root 'result.json') -Raw|ConvertFrom-Json).status | Should -BeExactly 'Blocked'
    }

    It 'returns Blocked evidence when trusted ShellCheck is missing' {
        $root=Join-Path $TestDrive 'bash-missing';New-Item -ItemType Directory $root|Out-Null;Set-Content (Join-Path $root 'safe.sh') "#!/usr/bin/env bash`nprintf '%s' ok"
        & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/Test-BashStaticAnalysis.ps1') -Path $root -ShellCheckPath (Join-Path $root 'missing-shellcheck') -OutputJson result.json
        $LASTEXITCODE | Should -Be 3
        (Get-Content (Join-Path $root 'result.json') -Raw|ConvertFrom-Json).status | Should -BeExactly 'Blocked'
    }
}
