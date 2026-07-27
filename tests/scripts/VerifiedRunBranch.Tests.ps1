BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    Import-Module (Join-Path $script:root 'scripts/GovernanceValidation.psm1') -Force
}

Describe 'Verified-run branch provenance' {
    It 'accepts GitHub-valid branch fixture <Fixture> through document and exported object validation' -ForEach @(
        @{ Fixture = 'pr-branch.json' },
        @{ Fixture = 'underscore-feature.json' }
    ) {
        $path = Join-Path $script:root "tests/fixtures/verified-run-branches/valid/$Fixture"
        $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable

        @((Test-GovernanceJsonDocument -Path $path -Kind verified-run) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
        @((Test-VerifiedRunObject -Run $record -Path $path) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
    }

    It 'accepts a long multi-component GitHub branch fixture without a synthetic total-length cap' {
        $path = Join-Path $script:root 'tests/fixtures/verified-run-branches/valid/at-sign.json'
        $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable

        $record.branch.Length | Should -BeGreaterThan 255
        @($record.branch -split '/') | Should -HaveCount 3
        @((Test-GovernanceJsonDocument -Path $path -Kind verified-run) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
        @((Test-VerifiedRunObject -Run $record -Path $path) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
    }

    It 'accepts an astral-Unicode branch through both public validators' {
        $record = Get-Content -LiteralPath (Join-Path $script:root 'evidence/latest-verified-run.json') -Raw |
            ConvertFrom-Json -AsHashtable
        $record.branch = (('😀' * 50) + '/' + ('😀' * 50) + '/' + ('😀' * 50))
        $path = Join-Path $TestDrive 'unicode-branch.json'
        $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding utf8

        @((Test-GovernanceJsonDocument -Path $path -Kind verified-run) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
        @((Test-VerifiedRunObject -Run $record -Path $path) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
    }

    It 'preserves backward compatibility for master records' {
        $path = Join-Path $script:root 'tests/fixtures/valid/verified-run.json'
        $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable

        @((Test-GovernanceJsonDocument -Path $path -Kind verified-run) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
        @((Test-VerifiedRunObject -Run $record -Path $path) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
    }

    It 'returns a controlled failure when a required member is missing' {
        $path = Join-Path $script:root 'tests/fixtures/verified-run-branches/invalid/full-ref.json'
        { $script:missingMemberResults = @(Test-GovernanceJsonDocument -Path $path -Kind verified-run) } |
            Should -Not -Throw
        @($script:missingMemberResults | Where-Object status -EQ Failed).Count |
            Should -BeGreaterThan 0
    }

    It 'rejects the GitHub-reserved refs prefix through both public validators' {
        $record = Get-Content -LiteralPath (Join-Path $script:root 'evidence/latest-verified-run.json') -Raw |
            ConvertFrom-Json -AsHashtable
        $record.branch = 'refs/heads/main'
        $path = Join-Path $TestDrive 'refs-prefix.json'
        $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding utf8

        @((Test-GovernanceJsonDocument -Path $path -Kind verified-run) | Where-Object status -EQ Failed).Count |
            Should -BeGreaterThan 0
        @((Test-VerifiedRunObject -Run $record -Path $path) | Where-Object status -EQ Failed).Count |
            Should -BeGreaterThan 0
    }

    It 'rejects malformed or reserved branch fixture <Fixture> through both public validators' -ForEach @(
        @{ Fixture = 'double-slash.json' },
        @{ Fixture = 'lock-suffix.json' },
        @{ Fixture = 'head.json' }
    ) {
        $path = Join-Path $script:root "tests/fixtures/verified-run-branches/invalid/$Fixture"
        $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable

        @((Test-GovernanceJsonDocument -Path $path -Kind verified-run) | Where-Object status -EQ Failed).Count |
            Should -BeGreaterThan 0
        @((Test-VerifiedRunObject -Run $record -Path $path) | Where-Object status -EQ Failed).Count |
            Should -BeGreaterThan 0
    }
}
