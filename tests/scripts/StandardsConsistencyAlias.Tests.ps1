BeforeAll {
    Import-Module "$PSScriptRoot/../../scripts/GovernanceValidation.psm1" -Force
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("standards-consistency-alias-tests-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null

    function script:New-ConsistencyTestDocument {
        param(
            [Parameter(Mandatory)][string]$Name,
            [Parameter(Mandatory)][scriptblock]$Mutate
        )

        $document = Get-Content (Join-Path $script:repoRoot 'governance/standards-consistency.json') -Raw | ConvertFrom-Json -AsHashtable
        & $Mutate $document
        $path = Join-Path $script:tempRoot "$Name.json"
        $document | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding utf8
        $path
    }
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
    }
}

Describe 'Standards-consistency release-state schema and semantics' {
    It 'accepts the current valid schema 1.1.0 record' {
        $path = Join-Path $script:repoRoot 'governance/standards-consistency.json'
        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object status -eq 'Failed').Count | Should -Be 0
    }

    It 'rejects a schema 1.1.0 alias without a reason' {
        $path = New-ConsistencyTestDocument -Name 'missing-alias-reason' -Mutate {
            param($document)
            $document.releaseReadiness.Remove('reason')
        }

        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -eq "Deprecated releaseReadiness alias is missing required member 'reason'." }) | Should -HaveCount 1
    }

    It 'rejects a schema 1.1.0 alias with a reason shorter than the schema minimum' {
        $path = New-ConsistencyTestDocument -Name 'short-alias-reason' -Mutate {
            param($document)
            $document.releaseReadiness.reason = 'Too short'
        }

        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -eq 'Deprecated releaseReadiness alias reason must contain at least 20 non-whitespace characters.' }) | Should -HaveCount 1
    }

    It 'rejects a null published release as a structured validation failure' {
        $path = New-ConsistencyTestDocument -Name 'null-published-release' -Mutate {
            param($document)
            $document.publishedRelease = $null
        }

        $results = @(Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency')

        @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -eq 'publishedRelease must be an object.' }) | Should -HaveCount 1
    }

    It 'rejects a published release reason shorter than the authoritative schema minimum' {
        $path = New-ConsistencyTestDocument -Name 'short-published-reason' -Mutate {
            param($document)
            $document.publishedRelease.reason = 'Short'
        }

        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -like 'Standards-consistency JSON Schema validation failed*' }).Count | Should -BeGreaterThan 0
    }

    It 'rejects unknown properties on the authoritative published release record' {
        $path = New-ConsistencyTestDocument -Name 'published-extra-property' -Mutate {
            param($document)
            $document.publishedRelease.unreviewedField = 'not allowed'
        }

        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -like 'Standards-consistency JSON Schema validation failed*' }).Count | Should -BeGreaterThan 0
    }

    It 'rejects unknown properties on the authoritative next-release record' {
        $path = New-ConsistencyTestDocument -Name 'next-release-extra-property' -Mutate {
            param($document)
            $document.nextReleaseReadiness.unreviewedField = 'not allowed'
        }

        $results = Test-GovernanceJsonDocument -Path $path -Kind 'standards-consistency'

        @($results | Where-Object { $_.status -eq 'Failed' -and $_.message -like 'Standards-consistency JSON Schema validation failed*' }).Count | Should -BeGreaterThan 0
    }
}
