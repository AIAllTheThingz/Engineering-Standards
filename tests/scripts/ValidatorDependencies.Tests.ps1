BeforeAll {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    Import-Module (Join-Path $repoRoot 'scripts/ValidatorDependencyTools.psm1') -Force
}

Describe 'Validator dependency integrity controls' {
    BeforeEach {
        $testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    }

    It 'accepts the reviewed lock and exact hash-locked Python requirements' {
        $lockPath = Join-Path $repoRoot '.github/dependencies/validator-dependencies.psd1'
        $requirementsPath = Join-Path $repoRoot '.github/dependencies/workflow-validation-requirements.txt'
        $lock = Import-ValidatorDependencyLock -Path $lockPath

        $results = @(Test-ValidatorDependencyLock -Lock $lock -LockPath '.github/dependencies/validator-dependencies.psd1' -RequirementsPath $requirementsPath)

        @($results | Where-Object status -in @('Failed','Blocked')).Count | Should -Be 0
        @($results | Where-Object ruleId -eq 'DEP000').Count | Should -Be 1
    }

    It 'pins the trusted Codex evaluator package and lock integrity without package scripts' {
        $package = Get-Content -LiteralPath (Join-Path $repoRoot '.github/dependencies/codex-evaluator/package.json') -Raw | ConvertFrom-Json -AsHashtable
        $lock = Get-Content -LiteralPath (Join-Path $repoRoot '.github/dependencies/codex-evaluator/package-lock.json') -Raw | ConvertFrom-Json -AsHashtable
        $lockedCodex = $lock.packages['node_modules/@openai/codex']

        $package.dependencies['@openai/codex'] | Should -BeExactly '0.144.0-alpha.4'
        $package.ContainsKey('scripts') | Should -BeFalse
        $lock.lockfileVersion | Should -Be 3
        $lockedCodex.version | Should -BeExactly '0.144.0-alpha.4'
        $lockedCodex.integrity | Should -BeExactly 'sha512-Uf915avv7ETTv5PFLPf+Bw2KICFXgW8M+5vMzoUlrJkcRlCOTs5FgzjLZPvawWOJqZEgFsrQuJeLMRog0XSxxQ=='
    }

    It 'requires lifecycle-disabled npm installation in the trusted workflow' {
        $workflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github/workflows/codex-skill-behavior.yml') -Raw
        $workflow | Should -Match 'npm ci --ignore-scripts --no-audit --no-fund'
        $workflow | Should -Not -Match '(?m)^\s*working-directory:\s*candidate(?:/|\\|\s|$)'
    }

    It 'requires exact evaluator provenance and CycloneDX artifact inventory' {
        $workflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github/workflows/codex-skill-behavior.yml') -Raw
        $workflow | Should -Match "nodeVersion\s+-cne\s+'v22\.17\.0'"
        $workflow | Should -Match "codexVersion\s+-cne\s+'codex-cli 0\.144\.0-alpha\.4'"
        $workflow | Should -Match 'codex-evaluator-provenance\.json'
        $workflow | Should -Match 'codex-evaluator-sbom\.cdx\.json'
        $workflow | Should -Match "bomFormat\s*=\s*'CycloneDX'"
        $workflow | Should -Match 'Get-FileHash'
    }

    It 'fails when the Python requirement hash does not match the dependency lock' {
        $lock = Import-ValidatorDependencyLock -Path (Join-Path $repoRoot '.github/dependencies/validator-dependencies.psd1')
        $requirementsPath = Join-Path $testRoot 'requirements.txt'
        @('--only-binary=:all:','PyYAML==6.0.2 --hash=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa') |
            Set-Content -LiteralPath $requirementsPath -Encoding utf8

        $results = @(Test-ValidatorDependencyLock -Lock $lock -LockPath 'lock.psd1' -RequirementsPath $requirementsPath)

        @($results | Where-Object ruleId -eq 'DEP010' | Where-Object status -eq 'Failed').Count | Should -Be 1
    }

    It 'reports Blocked when a required package is missing in offline mode' {
        $lock = @{ Packages=@(@{ Name='Synthetic'; PackageFile='Synthetic.1.0.0.nupkg'; Sha256=('a' * 64) }) }

        $results = @(Test-ValidatorPackageCache -Lock $lock -PackageCachePath $testRoot -Offline)

        $results.Count | Should -Be 1
        $results[0].ruleId | Should -BeExactly 'DEP011'
        $results[0].status | Should -BeExactly 'Blocked'
    }

    It 'fails when cached dependency content is mismatched or tampered' {
        $packagePath = Join-Path $testRoot 'Synthetic.1.0.0.nupkg'
        Set-Content -LiteralPath $packagePath -Value 'tampered-content' -Encoding utf8
        $lock = @{ Packages=@(@{ Name='Synthetic'; PackageFile='Synthetic.1.0.0.nupkg'; Sha256=('b' * 64) }) }

        $results = @(Test-ValidatorPackageCache -Lock $lock -PackageCachePath $testRoot -Offline)

        $results.Count | Should -Be 1
        $results[0].ruleId | Should -BeExactly 'DEP012'
        $results[0].status | Should -BeExactly 'Failed'
    }

    It 'passes when cached dependency content matches the reviewed hash' {
        $packagePath = Join-Path $testRoot 'Synthetic.1.0.0.nupkg'
        Set-Content -LiteralPath $packagePath -Value 'reviewed-content' -Encoding utf8
        $expectedHash = Get-ValidatorFileSha256 -Path $packagePath
        $lock = @{ Packages=@(@{ Name='Synthetic'; PackageFile='Synthetic.1.0.0.nupkg'; Sha256=$expectedHash }) }

        $results = @(Test-ValidatorPackageCache -Lock $lock -PackageCachePath $testRoot -Offline)

        $results.Count | Should -Be 1
        $results[0].ruleId | Should -BeExactly 'DEP013'
        $results[0].status | Should -BeExactly 'Passed'
    }

    It 'rejects traversal in a hash-verified module archive before extraction' {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archivePath = Join-Path $testRoot 'unsafe.nupkg'
        $stream = [System.IO.File]::Open($archivePath, [System.IO.FileMode]::CreateNew)
        $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            $entry = $archive.CreateEntry('../escape.txt')
            $writer = [System.IO.StreamWriter]::new($entry.Open())
            try { $writer.Write('unsafe') } finally { $writer.Dispose() }
        }
        finally { $archive.Dispose(); $stream.Dispose() }

        { Expand-ValidatorModulePackage -PackagePath $archivePath -DestinationPath (Join-Path $testRoot 'module') } |
            Should -Throw '*unsafe archive entry*'
        Test-Path -LiteralPath (Join-Path $testRoot 'escape.txt') | Should -BeFalse
    }
}
