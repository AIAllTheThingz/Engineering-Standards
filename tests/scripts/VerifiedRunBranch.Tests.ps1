BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    Import-Module (Join-Path $script:root 'scripts/GovernanceValidation.psm1') -Force
}

Describe 'Verified-run branch provenance' {
    It 'accepts Git-valid branch fixture <Fixture> through document and exported object validation' -ForEach @(
        @{ Fixture = 'pr-branch.json' },
        @{ Fixture = 'underscore-feature.json' },
        @{ Fixture = 'at-sign.json' }
    ) {
        $path = Join-Path $script:root "tests/fixtures/verified-run-branches/valid/$Fixture"
        $record = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable

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

    It 'rejects malformed branch fixture <Fixture> through document and exported object validation' -ForEach @(
        @{ Fixture = 'full-ref.json' },
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
