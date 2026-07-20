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

    It 'locks Ruff and ShellCheck with exact installation metadata and includes both in the SBOM' {
        $lock=Import-ValidatorDependencyLock -Path (Join-Path $repoRoot '.github/dependencies/validator-dependencies.psd1')
        $ruff=@($lock.Packages|Where-Object Name -eq 'Ruff')[0];$shell=@($lock.Packages|Where-Object Name -eq 'ShellCheck')[0]
        $ruff.InstallationKind | Should -BeExactly 'PythonWheel';$ruff.Sha256 | Should -Match '^[0-9a-f]{64}$'
        $shell.InstallationKind | Should -BeExactly 'TarXzExecutable';$shell.SourceUri | Should -Match '/releases/download/v0\.11\.0/'
        $sbom=New-ValidatorDependencySbom -Lock $lock -RuntimeInventory @([pscustomobject]@{name='Synthetic';declaredVersion='1.0.0';actualVersion='1.0.0';executableSha256=$null}) -SerialNumber ([guid]::NewGuid())
        @($sbom.components.name) | Should -Contain 'Ruff';@($sbom.components.name) | Should -Contain 'ShellCheck'
        ($sbom.components|Where-Object name -eq ShellCheck).type | Should -BeExactly 'application'
    }

    It 'rejects duplicate package names and extra or missing Python requirements' {
        $lock=Import-ValidatorDependencyLock -Path (Join-Path $repoRoot '.github/dependencies/validator-dependencies.psd1')
        $lock.Packages=@($lock.Packages)+@($lock.Packages[0])
        $req=Join-Path $testRoot 'requirements.txt';Copy-Item (Join-Path $repoRoot '.github/dependencies/workflow-validation-requirements.txt') $req
        @(Test-ValidatorDependencyLock -Lock $lock -LockPath lock.psd1 -RequirementsPath $req|Where-Object ruleId -eq DEP007).Count | Should -BeGreaterThan 0
        Add-Content $req 'extra==1.0.0 --hash=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        @(Test-ValidatorDependencyLock -Lock $lock -LockPath lock.psd1 -RequirementsPath $req|Where-Object ruleId -eq DEP010).Count | Should -BeGreaterThan 0
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

    It 'hash-approves candidate configurations separately from immutable evaluator code and bounds all inputs' {
        $policy = Import-PowerShellDataFile -LiteralPath (Join-Path $repoRoot '.github/dependencies/codex-evaluator/behavior-trust-policy.psd1')
        $hashes = @($policy.ApprovedConfigurations | ForEach-Object Sha256)

        $policy.EvaluatorPaths | Should -Contain '.github/dependencies/codex-evaluator/behavior-trust-policy.psd1'
        $policy.EvaluatorPaths | Should -Contain 'scripts/CodexSkillBehaviorActionsEvaluation.psm1'
        $policy.EvaluatorPaths | Should -Contain 'scripts/Invoke-CodexSkillBehaviorActionsEvaluation.ps1'
        $policy.EvaluatorPaths | Should -Contain 'scripts/Invoke-CodexSkillBehaviorActionsModel.ps1'
        $policy.EvaluatorPaths | Should -Contain 'scripts/Test-CodexSkillBehaviorActionsEvidence.ps1'
        $policy.EvaluatorPaths | Should -Not -Contain 'scripts/CodexSkillBehaviorEvaluation.psm1'
        $policy.EvaluatorPaths | Should -Not -Contain $policy.ConfigurationPath
        $hashes | Should -Contain '26edd6a335bfcc359e32f35959cf1a5bd514125f0fd94d88b688083c782f1515'
        $hashes | Should -Contain '9a24ce3d74448b2787e3470dbb9cace027aa5ae9fddbeff507a0019ccd700de6'
        $policy.InputLimits.MaximumPromptFileCount | Should -BeGreaterThan 0
        $policy.InputLimits.MaximumPromptBytesPerFile | Should -BeGreaterThan 0
        $policy.InputLimits.MaximumAggregateSkillBytes | Should -BeGreaterThan 0
        $policy.InputLimits.MaximumAggregateAuthorityBytes | Should -BeGreaterThan 0
        @($policy.InputLimits.ApprovedCategories).Count | Should -BeGreaterThan 0
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
