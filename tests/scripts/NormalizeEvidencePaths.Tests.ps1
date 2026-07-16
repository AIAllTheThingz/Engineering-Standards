Describe 'Normalize-EvidencePaths' {
    BeforeAll {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("normalize-evidence-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
        $script:normalizer = Resolve-Path "$PSScriptRoot/../../scripts/Normalize-EvidencePaths.ps1"
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
        }
    }

    It 'fails when absolute paths remain in evidence files' {
        $evidenceRoot = Join-Path $script:tempRoot 'evidence'
        New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
        @'
{
  "results": [
    {
      "path": "C:\\stale\\repo\\scripts\\Test-JsonSchemas.ps1"
    }
  ]
}
'@ | Set-Content -LiteralPath (Join-Path $evidenceRoot 'aggregate-governance.json') -Encoding utf8

        & pwsh -NoProfile -File $script:normalizer -Path $script:tempRoot -EvidencePath 'evidence'
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'preserves JSON escaping in parameterized test names while normalizing paths' {
        $evidenceRoot = Join-Path $script:tempRoot 'parameterized-evidence'
        New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
        $testName = '"}")'
        [ordered]@{
            tests = @(
                [ordered]@{
                    name = $testName
                    path = (Join-Path $script:tempRoot 'tests/Synthetic.Tests.ps1')
                }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'pester-details.json') -Encoding utf8

        & pwsh -NoProfile -File $script:normalizer -Path $script:tempRoot -EvidencePath $evidenceRoot

        $LASTEXITCODE | Should -Be 0
        $raw = Get-Content -LiteralPath (Join-Path $evidenceRoot 'pester-details.json') -Raw
        { $raw | ConvertFrom-Json } | Should -Not -Throw
        $result = $raw | ConvertFrom-Json
        $result.tests[0].name | Should -BeExactly $testName
        $result.tests[0].path | Should -BeExactly 'tests/Synthetic.Tests.ps1'
    }

    It 'preserves empty strings while normalizing nested evidence values' {
        $evidenceRoot = Join-Path $script:tempRoot 'empty-string-evidence'
        New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
        [ordered]@{
            failureReason = ''
            results = @(
                [ordered]@{
                    path = (Join-Path $script:tempRoot 'scripts/Synthetic.ps1')
                    message = ''
                }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $evidenceRoot 'failure.json') -Encoding utf8

        & pwsh -NoProfile -File $script:normalizer -Path $script:tempRoot -EvidencePath $evidenceRoot

        $LASTEXITCODE | Should -Be 0
        $result = Get-Content -LiteralPath (Join-Path $evidenceRoot 'failure.json') -Raw | ConvertFrom-Json
        $result.failureReason | Should -BeExactly ''
        $result.results[0].message | Should -BeExactly ''
        $result.results[0].path | Should -BeExactly 'scripts/Synthetic.ps1'
    }

    It 'fails closed for malformed evidence JSON' {
        $evidenceRoot = Join-Path $script:tempRoot 'malformed-evidence'
        New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
        '{"name": "broken"' | Set-Content -LiteralPath (Join-Path $evidenceRoot 'broken.json') -Encoding utf8

        & pwsh -NoProfile -File $script:normalizer -Path $script:tempRoot -EvidencePath $evidenceRoot 2>$null

        $LASTEXITCODE | Should -Not -Be 0
    }
}
