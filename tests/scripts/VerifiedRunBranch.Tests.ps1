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

    It 'accepts a refs-prefixed branch shorthand through document and exported object validation' {
        $record = Get-Content -LiteralPath (Join-Path $script:root 'evidence/latest-verified-run.json') -Raw |
            ConvertFrom-Json -AsHashtable
        $record.branch = 'refs/feature'
        $path = Join-Path $TestDrive 'refs-prefix.json'
        $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding utf8

        @((Test-GovernanceJsonDocument -Path $path -Kind verified-run) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
        @((Test-VerifiedRunObject -Run $record -Path $path) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
    }

    It 'counts Unicode branch length by code point in both public validators' {
        $record = Get-Content -LiteralPath (Join-Path $script:root 'evidence/latest-verified-run.json') -Raw |
            ConvertFrom-Json -AsHashtable
        $record.branch = (('😀' * 50) + '/' + ('😀' * 50) + '/' + ('😀' * 50))
        $path = Join-Path $TestDrive 'unicode-branch.json'
        $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding utf8

        @((Test-GovernanceJsonDocument -Path $path -Kind verified-run) | Where-Object status -EQ Failed) |
            Should -HaveCount 0
        @((Test-VerifiedRunObject -Run $record -Path $path) | Where-Object status -EQ Failed) |
            Should -HaveCount 0

        $record.branch = ('a' * 256)
        $tooLongPath = Join-Path $TestDrive 'overlong-branch.json'
        $record | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $tooLongPath -Encoding utf8
        @((Test-GovernanceJsonDocument -Path $tooLongPath -Kind verified-run) | Where-Object status -EQ Failed).Count |
            Should -BeGreaterThan 0
        @((Test-VerifiedRunObject -Run $record -Path $tooLongPath) | Where-Object status -EQ Failed).Count |
            Should -BeGreaterThan 0
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
