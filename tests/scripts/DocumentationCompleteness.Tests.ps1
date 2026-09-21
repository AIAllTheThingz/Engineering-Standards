Describe 'Documentation completeness' {
    Context 'maintained downstream examples' {
        It 'validates configured documentation for <ExampleName>' -ForEach @(
            Get-ChildItem "$PSScriptRoot/../../examples" -Filter governance.config.json -Recurse | ForEach-Object {
                @{ ExampleName = $_.Directory.Name; ExamplePath = $_.Directory.FullName }
            }
        ) {
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $ExamplePath 2>&1)
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        }
    }

    Context 'repository documents' {
        It 'passes for the rebuilt repository' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'downstream configured documentation' {
        BeforeAll {
            $script:downstreamTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("downstream-doc-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:downstreamTempRoot -Force | Out-Null
        }

        BeforeEach {
            Copy-Item -LiteralPath "$PSScriptRoot/../../README.md" -Destination (Join-Path $script:downstreamTempRoot 'README.md')
            @{ workflowProfile = 'downstream'; requiredDocumentationPaths = @('README.md') } |
                ConvertTo-Json -Depth 10 |
                Set-Content -LiteralPath (Join-Path $script:downstreamTempRoot 'governance.config.json')
        }

        AfterAll {
            if ($script:downstreamTempRoot -and (Test-Path -LiteralPath $script:downstreamTempRoot)) {
                Remove-Item -LiteralPath $script:downstreamTempRoot -Recurse -Force
            }
        }

        It 'uses downstream requiredDocumentationPaths instead of central-only documents' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot
            $LASTEXITCODE | Should -Be 0
        }

        It 'fails when a configured downstream document is missing' {
            $config = Get-Content -LiteralPath (Join-Path $script:downstreamTempRoot 'governance.config.json') -Raw | ConvertFrom-Json
            $config.requiredDocumentationPaths = @('README.md', 'MISSING.md')
            $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:downstreamTempRoot 'governance.config.json')
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'MISSING\.md.*missing'
        }

        It 'rejects downstream <Name> content' -ForEach @(
            @{ Name = 'empty'; Content = '' }
            @{ Name = 'whitespace'; Content = '   ' }
            @{ Name = 'one-line'; Content = 'See the administrator.' }
            @{ Name = 'headings-only'; Content = "# Project`n## Usage`n## Checks" }
        ) {
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value $Content
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'README\.md.*(empty|shallow)'
        }

        It 'accepts substantive downstream documentation without central policy vocabulary' {
            $body = 'Install the application and configure its settings before running the documented command. Check the output and contact the maintainer if execution fails. ' * 2
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "# Project`n$body`n## Usage`n$body`n## Checks`n$body"
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot
            $LASTEXITCODE | Should -Be 0
        }

        It 'does not count code-sample headings as downstream sections: <Fence>' -ForEach @(
            @{ Fence = '```'; Close = '```' }
            @{ Fence = '~~~'; Close = '~~~~' }
            @{ Fence = '````'; Close = '' }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "# Project`n$body`n$Fence`n## Example one`ncommands`n## Example two`ncommands`n$Close"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'README\.md.*too few meaningful sections'
        }

        It 'rejects hidden section structure in HTML comments: <Name>' -ForEach @(
            @{ Name = 'multiline'; Content = "<!--`n## Hidden one`ntext`n## Hidden two`ntext`n-->" }
            @{ Name = 'unclosed'; Content = "<!--`n## Hidden one`ntext`n## Hidden two`ntext" }
            @{ Name = 'empty body'; Content = "## Visible one`n<!-- hidden body -->`n## Visible two`nvisible body" }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "# Project`n$body`n$Content"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'README\.md.*(too few meaningful sections|empty heading)'
        }

        It 'preserves code literals and ignores commented fences before visible sections' {
            $body = 'Documented operational instructions and verification steps. ' * 25
            $content = '# Project', $body, '<!--', '```', '-->', '## Usage', '```html', '<!-- example literal', '```', '## Checks', 'Verify the result.'
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value ($content -join "`n")
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot
            $LASTEXITCODE | Should -Be 0
        }

        It 'rejects a rendered-empty heading title: <Name>' -ForEach @(
            @{ Name = 'comment only'; Heading = '## <!-- TODO -->' }
            @{ Name = 'indented comment'; Heading = '  ### <!-- TODO -->' }
            @{ Name = 'closing hashes'; Heading = '## <!-- TODO --> ##' }
            @{ Name = 'marker only'; Heading = '##' }
        ) {
            Set-Content (Join-Path $script:downstreamTempRoot 'NOTES.md') -Value "$Heading`nVisible section body."
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'NOTES\.md.*empty heading title'
            Remove-Item -LiteralPath (Join-Path $script:downstreamTempRoot 'NOTES.md')
        }

        It 'preserves inline comment syntax literals: <Name>' -ForEach @(
            @{ Name = 'single backticks'; Literal = 'Use `<!--` to start a comment.' }
            @{ Name = 'multiple backticks'; Literal = 'Use ``<!-- `literal` `` to describe syntax.' }
            @{ Name = 'multiline span'; Literal = 'Use ``<!--' + "`n" + 'literal`` to describe syntax.' }
            @{ Name = 'mixed real comment'; Literal = 'Use `<!--` to start. <!-- real comment --> Continue here.' }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "# Project`n$Literal`n`n## Usage`n$body`n## Checks`nVerify the result."
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot
            $LASTEXITCODE | Should -Be 0
        }

        It 'accepts headings indented by <Spaces> spaces and rejects empty indented sections' -ForEach @(
            @{ Spaces = 1 }, @{ Spaces = 2 }, @{ Spaces = 3 }
        ) {
            $indent = ' ' * $Spaces
            $body = 'Documented operational instructions and verification steps. ' * 25
            $path = Join-Path $script:downstreamTempRoot 'README.md'
            Set-Content $path -Value "${indent}# Project`n$body`n${indent}## Usage`nRun the command.`n${indent}## Checks`nVerify the result."
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot
            $LASTEXITCODE | Should -Be 0
            Add-Content $path -Value "${indent}## Empty`n<!-- instructions -->"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'README\.md.*empty heading'
        }

        It 'does not count indented code-sample headings as sections' {
            $body = 'Documented operational instructions and verification steps. ' * 25
            $content = '# Project', $body, '```', ' ## Example one', 'commands', '   ## Example two', 'commands', '```'
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value ($content -join "`n")
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'README\.md.*too few meaningful sections'
        }

        It 'allows unfilled GitHub templates but still checks other GitHub documents' {
            $github = Join-Path $script:downstreamTempRoot '.github'
            New-Item -ItemType Directory -Path $github -Force | Out-Null
            if ($IsWindows) {
                $directory = Get-Item -LiteralPath $github -Force
                $directory.Attributes = $directory.Attributes -bor [IO.FileAttributes]::Hidden
            }
            $gitMetadata = Join-Path $script:downstreamTempRoot '.git'
            New-Item -ItemType Directory -Path $gitMetadata -Force | Out-Null
            Set-Content (Join-Path $gitMetadata 'internal.md') -Value '# Internal metadata is not repository documentation'
            Set-Content (Join-Path $github 'pull_request_template.md') -Value "## Summary`n<!-- Fill in the summary. -->"
            $issueTemplates = Join-Path $github 'ISSUE_TEMPLATE'
            New-Item -ItemType Directory -Path $issueTemplates -Force | Out-Null
            Set-Content (Join-Path $issueTemplates 'bug_report.md') -Value "## Steps to reproduce`n<!-- Fill in the steps. -->"
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot
            $LASTEXITCODE | Should -Be 0
            Set-Content (Join-Path $github 'GUIDE.md') -Value "## Usage`n<!-- hidden body -->"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'GUIDE\.md.*empty heading'
        }
    }

    Context 'invalid documentation' {
        BeforeAll {
            $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("doc-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
            Copy-Item -LiteralPath "$PSScriptRoot/../../README.md" -Destination (Join-Path $script:tempRoot 'README.md')
            Copy-Item -LiteralPath "$PSScriptRoot/../../SECURITY.md" -Destination (Join-Path $script:tempRoot 'SECURITY.md')
            Copy-Item -LiteralPath "$PSScriptRoot/../../CONTRIBUTING.md" -Destination (Join-Path $script:tempRoot 'CONTRIBUTING.md')
            foreach ($dir in @('governance','agents','docs')) {
                New-Item -ItemType Directory -Path (Join-Path $script:tempRoot $dir) -Force | Out-Null
                Get-ChildItem -LiteralPath "$PSScriptRoot/../../$dir" -Filter '*.md' -File | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $script:tempRoot $dir)
                }
            }
            Set-Content -LiteralPath (Join-Path $script:tempRoot 'docs/MAINTAINER_GUIDE.md') -Value "# Maintainer Guide`n`nToo short."
        }

        AfterAll {
            if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
                Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
            }
        }

        It 'fails shallow authoritative documents' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:tempRoot
            $LASTEXITCODE | Should -Not -Be 0
        }
    }

    Context 'downstream canary guide enforcement' {
        BeforeAll {
            $script:canaryTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("canary-doc-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:canaryTempRoot -Force | Out-Null
            foreach ($file in @('README.md','SECURITY.md','CONTRIBUTING.md')) {
                Copy-Item -LiteralPath "$PSScriptRoot/../../$file" -Destination (Join-Path $script:canaryTempRoot $file)
            }
            foreach ($dir in @('governance','agents','docs')) {
                New-Item -ItemType Directory -Path (Join-Path $script:canaryTempRoot $dir) -Force | Out-Null
                Get-ChildItem -LiteralPath "$PSScriptRoot/../../$dir" -Filter '*.md' -File | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $script:canaryTempRoot $dir)
                }
            }
            $script:canaryGuideSource = "$PSScriptRoot/../../docs/DOWNSTREAM_CANARY.md"
            $script:canaryGuideFixture = Join-Path $script:canaryTempRoot 'docs/DOWNSTREAM_CANARY.md'
            $script:documentationValidator = "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1"
        }

        BeforeEach {
            Copy-Item -LiteralPath $script:canaryGuideSource -Destination $script:canaryGuideFixture -Force
        }

        AfterAll {
            if ($script:canaryTempRoot -and (Test-Path -LiteralPath $script:canaryTempRoot)) {
                Remove-Item -LiteralPath $script:canaryTempRoot -Recurse -Force
            }
        }

        It 'accepts the current authoritative canary guide' {
            & pwsh -NoProfile -File $script:documentationValidator -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }

        It 'fails when the authoritative canary guide is missing' {
            Remove-Item -LiteralPath $script:canaryGuideFixture
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'docs/DOWNSTREAM_CANARY\.md.*missing'
        }

        It 'evaluates the authoritative canary guide word count' {
            Set-Content -LiteralPath $script:canaryGuideFixture -Value "# Canary`n`n## Validation`nMUST validate.`n`n## Evidence`nEvidence.`n`n## Exception`nException.`n`n## Related`nRelated." -Encoding utf8
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'DOWNSTREAM_CANARY\.md.*too shallow'
        }

        It 'evaluates required concepts in the authoritative canary guide' {
            $text = (Get-Content -LiteralPath $script:canaryGuideFixture -Raw) -replace '(?i)exception', 'waiver'
            Set-Content -LiteralPath $script:canaryGuideFixture -Value $text -Encoding utf8
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match "DOWNSTREAM_CANARY\.md.*missing required concept 'Exception'"
        }

        It 'evaluates heading count in the authoritative canary guide' {
            $words = ('governance ' * 320)
            Set-Content -LiteralPath $script:canaryGuideFixture -Value "# Canary`n`nMUST Validation Evidence Exception Related $words`n`n## Operation`n$words`n`n## Verification`n$words`n`n## Recovery`n$words" -Encoding utf8
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'DOWNSTREAM_CANARY\.md.*too few meaningful sections'
        }

        It 'detects an empty heading in the authoritative canary guide' {
            Add-Content -LiteralPath $script:canaryGuideFixture -Value "`n## Empty Canary Heading`n"
            $output = @(& pwsh -NoProfile -File $script:documentationValidator -Path $script:canaryTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'DOWNSTREAM_CANARY\.md.*empty heading'
        }
    }

    Context 'backlog reference enforcement' {
        BeforeAll {
            $script:backlogTempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("backlog-doc-tests-" + [guid]::NewGuid())
            New-Item -ItemType Directory -Path $script:backlogTempRoot -Force | Out-Null
            foreach ($file in @('README.md','SECURITY.md','CONTRIBUTING.md')) {
                Copy-Item -LiteralPath "$PSScriptRoot/../../$file" -Destination (Join-Path $script:backlogTempRoot $file)
            }
            foreach ($dir in @('governance','agents','docs')) {
                New-Item -ItemType Directory -Path (Join-Path $script:backlogTempRoot $dir) -Force | Out-Null
                Get-ChildItem -LiteralPath "$PSScriptRoot/../../$dir" -Filter '*.md' -File | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $script:backlogTempRoot $dir)
                }
            }
            $script:skillPlanSource = "$PSScriptRoot/../../docs/CODEX_SKILLS.md"
            $script:skillPlanFixture = Join-Path $script:backlogTempRoot 'docs/CODEX_SKILLS.md'
            $script:backlogGuideFixture = Join-Path $script:backlogTempRoot 'docs/BACKLOG_MANAGEMENT.md'
            $script:backlogDocumentationValidator = "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1"
        }

        BeforeEach {
            Copy-Item -LiteralPath $script:skillPlanSource -Destination $script:skillPlanFixture -Force
            Copy-Item -LiteralPath "$PSScriptRoot/../../docs/BACKLOG_MANAGEMENT.md" -Destination $script:backlogGuideFixture -Force
        }

        AfterAll {
            if ($script:backlogTempRoot -and (Test-Path -LiteralPath $script:backlogTempRoot)) {
                Remove-Item -LiteralPath $script:backlogTempRoot -Recurse -Force
            }
        }

        It 'accepts the current issue-linked demo resolution inventory' {
            & pwsh -NoProfile -File $script:backlogDocumentationValidator -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }

        It 'fails when a demo-resolved skill loses its authoritative issue link' {
            $text = (Get-Content -LiteralPath $script:skillPlanFixture -Raw) -replace '\[#43\]\(https://github\.com/AIAllTheThingz/Engineering-Standards/issues/43\)', 'Issue pending'
            Set-Content -LiteralPath $script:skillPlanFixture -Value $text -Encoding utf8
            $output = @(& pwsh -NoProfile -File $script:backlogDocumentationValidator -Path $script:backlogTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match "powershell-review.*authoritative GitHub issue-linked"
        }

        It 'fails when a demo-resolved skill is also represented as prose-only work' {
            Add-Content -LiteralPath $script:skillPlanFixture -Value "`n1. ``powershell-review```n"
            $output = @(& pwsh -NoProfile -File $script:backlogDocumentationValidator -Path $script:backlogTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match "powershell-review.*prose-only"
        }

        It 'fails when the authoritative backlog guide is missing' {
            Remove-Item -LiteralPath $script:backlogGuideFixture
            $output = @(& pwsh -NoProfile -File $script:backlogDocumentationValidator -Path $script:backlogTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'BACKLOG_MANAGEMENT\.md.*missing'
        }
    }
}
