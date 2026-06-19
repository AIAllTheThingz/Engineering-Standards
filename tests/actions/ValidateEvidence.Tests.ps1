Describe 'Validate evidence action' {
    BeforeAll {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("evidence-tests-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
        }
    }

    Context 'contradictory status' {
        It 'rejects Passed evidence with NotRun tests' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path "$PSScriptRoot/../.." -EvidencePath 'tests/fixtures/invalid/completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }
    }

    Context 'artifact integrity' {
        It 'rejects an artifact hash mismatch' {
            New-Item -ItemType Directory -Path (Join-Path $script:tempRoot 'evidence') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/report.json') -Value '{}'
            $evidence = Get-Content "$PSScriptRoot/../fixtures/valid/completion-result.json" -Raw | ConvertFrom-Json -AsHashtable
            $evidence.artifacts[0].path = 'evidence/report.json'
            $evidence.artifacts[0].sha256 = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
            $evidence | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $script:tempRoot 'completion-result.json')

            & pwsh -NoProfile -File "$PSScriptRoot/../../actions/validate-evidence/Invoke-EvidenceValidation.ps1" -Path $script:tempRoot -EvidencePath 'completion-result.json'
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
}
