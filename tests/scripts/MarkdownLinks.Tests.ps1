Describe "Markdown links" { It "validates" { & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-MarkdownLinks.ps1" -Path "$PSScriptRoot/../.."; $LASTEXITCODE | Should -Be 0 } }
