BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/GovernanceValidation.psm1" -Force
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("standards-consistency-alias-tests-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
    }
}

Describe 'Standards-consistency releaseReadiness alias semantics' {
    It 'accepts the current valid schema 1.1.0 alias' {
        $path = Join-Path $script:repoRoot 'governance/standards-consistency.json'
        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
    }

    It 'rejects a schema 1.1.0 alias without a reason' {
        $document = Get-Content (Join-Path $script:repoRoot 'governance/standards-consistency.json') -Raw | ConvertFrom-Json -AsHashtable
        $document.releaseReadiness.Remove('reason')
        $path = Join-Path $script:tempRoot 'missing-alias-reason.json'
        $document | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding utf8

        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -eq "Deprecated releaseReadiness alias is missing required member 'reason'." }) | Should -HaveCount 1
    }

    It 'rejects a schema 1.1.0 alias with a reason shorter than the schema minimum' {
        $document = Get-Content (Join-Path $script:repoRoot 'governance/standards-consistency.json') -Raw | ConvertFrom-Json -AsHashtable
        $document.releaseReadiness.reason = 'Too short'
        $path = Join-Path $script:tempRoot 'short-alias-reason.json'
        $document | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding utf8

        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -eq 'Deprecated releaseReadiness alias reason must contain at least 20 non-whitespace characters.' }) | Should -HaveCount 1
    }
}
