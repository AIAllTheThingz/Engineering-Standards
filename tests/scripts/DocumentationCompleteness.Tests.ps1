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

        It 'resolves legacy <SchemaVersion> documentation with maintainer identity <Maintainer>' -ForEach @(
            foreach ($version in @('1.0.0','1.1.0')) {
                foreach ($maintainer in @($false,$true)) { @{ SchemaVersion = $version; Maintainer = $maintainer } }
            }
        ) {
            $config = Get-Content "$PSScriptRoot/../fixtures/valid/governance-config.json" -Raw | ConvertFrom-Json -AsHashtable
            $config.schemaVersion = $SchemaVersion
            $config.requiredDocumentationPaths = @('README.md')
            $config | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $script:downstreamTempRoot 'governance.config.json')
            $manifest = Get-Content "$PSScriptRoot/../fixtures/valid/project-manifest.json" -Raw | ConvertFrom-Json -AsHashtable
            $manifest.schemaVersion = $SchemaVersion
            if ($Maintainer) { $manifest.repository = 'AIAllTheThingz/Engineering-Standards' }
            $manifestPath = Join-Path $script:downstreamTempRoot 'project-manifest.json'
            $manifest | ConvertTo-Json -Depth 20 | Set-Content $manifestPath
            try {
                $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
                if ($Maintainer) {
                    $LASTEXITCODE | Should -Be 1
                    $output -join "`n" | Should -Match 'governance/ORGANIZATION_CONTRACT\.md.*missing'
                    $config.workflowProfile = 'downstream'
                    $config.manifestPath = 'alternate-manifest.json'
                    $config | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $script:downstreamTempRoot 'governance.config.json')
                    $manifest.repository = 'example-org/fixture'
                    $manifest | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $script:downstreamTempRoot 'alternate-manifest.json')
                    $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
                    $LASTEXITCODE | Should -Be 1
                    $output -join "`n" | Should -Match 'governance/ORGANIZATION_CONTRACT\.md.*missing'
                }
                else { $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n") }
            }
            finally {
                Remove-Item -LiteralPath $manifestPath
                $alternate = Join-Path $script:downstreamTempRoot 'alternate-manifest.json'
                if (Test-Path -LiteralPath $alternate) { Remove-Item -LiteralPath $alternate }
            }
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

        It 'rejects markup-only titles without counting them as sections: <Title>' -ForEach @(
            @{ Title = '<span></span>' }
            @{ Title = '*<span></span>*' }
            @{ Title = '[<span></span>](https://example.invalid)' }
            @{ Title = '&nbsp;' }
            @{ Title = '&#32;' }
            @{ Title = '` `' }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "# $Title`n$body`n## $Title`n$body`n### $Title`n$body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'README\.md.*empty heading title'
            $output -join "`n" | Should -Match 'too few meaningful sections \(0 headings\)'
        }

        It 'rejects invisible prose in word counts and section bodies: <Name>' -ForEach @(
            @{ Name = 'space entities'; Body = '&nbsp; ' * 110 }
            @{ Name = 'format entities'; Body = '&#8203; ' * 110 }
            @{ Name = 'empty inline markup'; Body = '<span></span> ' * 110 }
            @{ Name = 'HTML attributes'; Body = '<div title="' + ('invisible ' * 110) + '"></div>' }
            @{ Name = 'script content'; Body = '<script>' + ('invisible ' * 110) + '</script>' }
            @{ Name = 'style content'; Body = '<style>' + ('invisible ' * 110) + '</style>' }
        ) {
            $path = Join-Path $script:downstreamTempRoot 'README.md'
            Set-Content $path -Value "# Project`n$Body`n`n## Usage`n$Body`n`n## Checks`n$Body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'too shallow'
            $output -join "`n" | Should -Match 'empty heading'
            $prose = 'Documented operational instructions and verification steps. ' * 25
            Set-Content $path -Value "# Project`n$prose`n`n## Usage`n$Body`n`n## Checks`nVerify results."
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'empty heading'
            $output -join "`n" | Should -Not -Match 'too shallow'
        }

        It 'preserves visible prose and code literals: <Name>' -ForEach @(
            @{ Name = 'inline code'; Body = '`&nbsp;` ' * 110 }
            @{ Name = 'fenced code'; Body = "```````n" + ('&nbsp; ' * 110) + "`n``````" }
            @{ Name = 'HTML text'; Body = '<div>' + ('Visible prose ' * 60) + '</div>' }
            @{ Name = 'adjacent HTML blocks'; Body = '<div>word</div>' * 110 }
            @{ Name = 'entity text'; Body = '&amp; ' * 110 }
        ) {
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "# Project`n$Body`n`n## Usage`n$Body`n`n## Checks`n$Body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        }

        It 'does not split words at inline HTML tags' {
            $body = '<div>' + ('<span>w</span>' * 110) + '</div>'
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "# Project`n$body`n`n## Usage`n$body`n`n## Checks`n$body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'too shallow'
            $output -join "`n" | Should -Not -Match 'empty heading'
        }

        It 'rejects invisible-only <Style> titles: <Name>' -ForEach @(
            foreach ($style in @('ATX','Setext')) {
                @{ Style = $style; Name = 'format entity'; Title = '&#8203;' }
                @{ Style = $style; Name = 'literal format'; Title = [string][char]0x200D }
                @{ Style = $style; Name = 'literal control'; Title = [string][char]0x0007 }
            }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            $text = if ($Style -eq 'ATX') { "# $Title`n$body`n## $Title`n$body`n### $Title`n$body" }
            else { "$Title`n===`n$body`n`n$Title`n---`n$body`n`n$Title`n---`n$body" }
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value $text
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'README\.md.*empty heading title'
            $output -join "`n" | Should -Match 'too few meaningful sections \(0 headings\)'
        }

        It 'preserves visible inline title content: <Title>' -ForEach @(
            @{ Title = '** **' }
            @{ Title = '**Usage**' }
            @{ Title = '<span>Usage</span>' }
            @{ Title = '`<span></span>`' }
            @{ Title = '[Usage](https://example.invalid)' }
            @{ Title = '<https://example.invalid>' }
            @{ Title = '&amp;' }
            @{ Title = '![Usage](image.png)' }
            @{ Title = 'Use&#8203;age' }
            @{ Title = "Use$([char]0x200D)age" }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "# $Title`n$body`n## $Title`n$body`n### $Title`n$body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        }

        It 'excludes YAML front matter from Setext headings and document words: <ClosingMarker>' -ForEach @(
            @{ ClosingMarker = '---' }
            @{ ClosingMarker = '...' }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            $metadata = "---`n# Metadata`n## More metadata`n### Further metadata`nsummary: $body`n$ClosingMarker`n"
            $path = Join-Path $script:downstreamTempRoot 'README.md'
            Set-Content $path -Value "$metadata`n# Project`nShort body."
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'too shallow'
            $output -join "`n" | Should -Match 'too few meaningful sections \(1 headings\)'
            Set-Content $path -Value "$metadata`nProject`n===`n$body`n`nUsage`n---`n$body`n`nChecks`n---`n$body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        }

        It 'accepts substantive Setext sections: <Title>' -ForEach @(
            @{ Title = 'Usage' }
            @{ Title = "Multi`nline title" }
            @{ Title = '`#`' }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "$Title`n===`n$body`n`n$Title`n---`n$body`n`n$Title`n---`n$body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        }

        It 'accepts mixed heading styles with <Ending> line endings' -ForEach @(
            @{ Ending = 'LF'; Newline = "`n" }
            @{ Ending = 'CRLF'; Newline = "`r`n" }
            @{ Ending = 'CR'; Newline = "`r" }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            $lines = '# Project', $body, '', 'Usage', '---', $body, '', '### Checks', $body
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -NoNewline -Value ($lines -join $Newline)
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        }

        It 'preserves word boundaries in multiline Setext titles' {
            $title = (@('word  ') * 95) -join "`n"
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "$title`n===`nBody.`n`nUsage`n---`nRun.`n`nChecks`n---`nVerify."
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        }

        It 'rejects empty Setext section bodies' {
            $body = 'Documented operational instructions and verification steps. ' * 25
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "Project`n===`n$body`n`nUsage`n---`n`nChecks`n---`n$body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'README\.md.*empty heading'
            $output -join "`n" | Should -Not -Match 'too few meaningful sections'
        }

        It 'rejects markup-only Setext titles' {
            $body = 'Documented operational instructions and verification steps. ' * 25
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value "**<span></span>**`n===`n$body`n`n&nbsp;`n---`n$body`n`n**<span></span>**`n---`n$body"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'README\.md.*empty heading title'
            $output -join "`n" | Should -Match 'too few meaningful sections \(0 headings\)'
        }

        It 'does not count fenced Setext samples or thematic breaks as sections' {
            $body = 'Documented operational instructions and verification steps. ' * 25
            $sample = '# Project', $body, '', '---', '', '```', 'Usage', '===', '', 'Checks', '---', '```'
            Set-Content (Join-Path $script:downstreamTempRoot 'README.md') -Value ($sample -join "`n")
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Be 1
            $output -join "`n" | Should -Match 'too few meaningful sections \(1 headings\)'
        }

        It 'does not treat raw HTML as Markdown headings: <Tag>' -ForEach @(
            @{ Tag = 'pre' }, @{ Tag = 'div' }
        ) {
            $body = 'Documented operational instructions and verification steps. ' * 25
            $path = Join-Path $script:downstreamTempRoot 'README.md'
            Set-Content $path -Value "# Project`n$body`n`n<$Tag>`n## Hidden one`n## Hidden two`n</$Tag>`n"
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'too few meaningful sections'
            Set-Content $path -Value "# Project`n$body`n`n## Usage`n<$Tag>`n##`n~~~`n</$Tag>`n`n## Checks`nVerify the result."
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot
            $LASTEXITCODE | Should -Be 0
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

        It 'allows supported PR templates but checks them when explicitly required: <TemplatePath>' -ForEach @(
            'pull_request_template.md', 'docs/pull_request_template.md', '.github/pull_request_template.md',
            'PULL_REQUEST_TEMPLATE/change.md', 'docs/PULL_REQUEST_TEMPLATE/change.md', '.github/PULL_REQUEST_TEMPLATE/change.md' |
                ForEach-Object { @{ TemplatePath = $_ } }
        ) {
            $template = Join-Path $script:downstreamTempRoot $TemplatePath
            New-Item -ItemType Directory -Path (Split-Path $template) -Force | Out-Null
            Set-Content $template -Value "## Summary`n<!-- Fill in REPLACE-ME. -->"
            try {
                & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot
                $LASTEXITCODE | Should -Be 0
                @{ workflowProfile = 'downstream'; requiredDocumentationPaths = @('README.md', $TemplatePath.Replace('/','\')) } |
                    ConvertTo-Json | Set-Content (Join-Path $script:downstreamTempRoot 'governance.config.json')
                $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $script:downstreamTempRoot 2>&1)
                $LASTEXITCODE | Should -Not -Be 0
                $output -join "`n" | Should -Match 'empty heading'
                $output -join "`n" | Should -Match 'Unresolved placeholder'
            }
            finally { Remove-Item -LiteralPath $template }
        }

        It 'ignores untracked dependencies but retains tracked and unignored hidden documents' {
            $fixture = Join-Path $TestDrive 'ignored-dependencies'
            New-Item -ItemType Directory -Path $fixture | Out-Null
            Copy-Item (Join-Path $script:downstreamTempRoot 'README.md') $fixture
            Copy-Item (Join-Path $script:downstreamTempRoot 'governance.config.json') $fixture
            & git init -q $fixture
            $LASTEXITCODE | Should -Be 0
            Set-Content (Join-Path $fixture '.gitignore') -Value ".venv/`n.smoke-venv/`n.agents/"
            foreach ($directory in @('.venv','.smoke-venv')) {
                New-Item -ItemType Directory -Path (Join-Path $fixture $directory) | Out-Null
                Set-Content (Join-Path $fixture "$directory/README.md") -Value 'REPLACE-ME'
            }
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $fixture
            $LASTEXITCODE | Should -Be 0
            foreach ($directory in @('.github','.agents')) {
                New-Item -ItemType Directory -Path (Join-Path $fixture $directory) -Force | Out-Null
                $document = Join-Path $fixture "$directory/GUIDE.md"
                Set-Content $document -Value 'REPLACE-ME'
                if ($directory -eq '.agents') { & git -C $fixture add -f -- '.agents/GUIDE.md' }
                $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $fixture 2>&1)
                $LASTEXITCODE | Should -Not -Be 0
                $output -join "`n" | Should -Match 'GUIDE\.md.*Unresolved placeholder'
                Set-Content $document -Value "# Guide`nMaintained content."
            }
        }

        It 'checks both Git documents whose names differ only by case' {
            $fixture = Join-Path $TestDrive 'case-distinct-docs'
            New-Item -ItemType Directory -Path $fixture | Out-Null
            Set-Content (Join-Path $fixture 'Guide.md') -Value "# Guide`nMaintained content."
            if (Test-Path (Join-Path $fixture 'guide.md')) {
                Set-ItResult -Skipped -Because 'The fixture filesystem is case-insensitive.'
                return
            }
            Copy-Item (Join-Path $script:downstreamTempRoot 'README.md') $fixture
            Copy-Item (Join-Path $script:downstreamTempRoot 'governance.config.json') $fixture
            Set-Content (Join-Path $fixture 'guide.md') -Value 'REPLACE-ME'
            & git init -q $fixture
            & git -C $fixture add -- Guide.md guide.md
            $output = @(& pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-DocumentationCompleteness.ps1" -Path $fixture 2>&1)
            $LASTEXITCODE | Should -Not -Be 0
            $output -join "`n" | Should -Match 'guide\.md.*Unresolved placeholder'
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
            Set-Content (Join-Path $github 'pull_request_template.md') -Value "## Summary`n<!-- Fill in REPLACE-ME. -->"
            $issueTemplates = Join-Path $github 'ISSUE_TEMPLATE'
            New-Item -ItemType Directory -Path $issueTemplates -Force | Out-Null
            Set-Content (Join-Path $issueTemplates 'bug_report.md') -Value "## Steps to reproduce`n<!-- Fill in REPLACE-ME. -->"
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
