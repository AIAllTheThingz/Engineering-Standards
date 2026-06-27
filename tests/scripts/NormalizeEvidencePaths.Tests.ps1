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
}
