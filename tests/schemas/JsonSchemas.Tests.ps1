Describe "JSON schema validation" { It "validates fixtures" { & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-JsonSchemas.ps1" -Path "$PSScriptRoot/../.."; $LASTEXITCODE | Should -Be 0 } }
