Describe 'Markdown link validation' {
    Context 'relative links' {
        It 'passes for repository markdown' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-MarkdownLinks.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }
    }
}
