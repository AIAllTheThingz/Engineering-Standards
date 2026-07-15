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
