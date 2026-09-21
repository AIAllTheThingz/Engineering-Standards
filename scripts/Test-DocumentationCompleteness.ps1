<#
.SYNOPSIS
Validates substantive documentation completeness.
.DESCRIPTION
Checks required authoritative documents for depth, required concepts, meaningful section bodies, unresolved placeholders, and fake validation commands.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

# Load PowerShell's bundled Markdown parser; precise spans distinguish comments from code literals.
$null = ConvertFrom-Markdown -InputObject 'Markdown parser initialization.'
$markdownPipelineBuilder = [Markdig.MarkdownPipelineBuilder]::new()
$markdownPipelineBuilder.PreciseSourceLocation = $true
$null = [Markdig.MarkdownExtensions]::UseYamlFrontMatter($markdownPipelineBuilder)
$markdownPipeline = $markdownPipelineBuilder.Build()

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()
$placeholderPattern = '(?i)template only|echo tests configured|echo lint configured|REPLACE-ME|placeholder-only'

$authoritative = @(
    'README.md',
    'SECURITY.md',
    'CONTRIBUTING.md',
    'governance/ORGANIZATION_CONTRACT.md',
    'governance/COMPLETION_EVIDENCE.md',
    'governance/RISK_CLASSIFICATION.md',
    'governance/EXCEPTION_PROCESS.md',
    'governance/AI_GENERATED_CODE_POLICY.md',
    'agents/AGENTS_Base.md',
    'agents/AGENTS_PowerShell.md',
    'agents/AGENTS_DotNet.md',
    'agents/AGENTS_WebFrontend.md',
    'agents/AGENTS_Database.md',
    'agents/AGENTS_WorkerService.md',
    'agents/AGENTS_Integration.md',
    'agents/AGENTS_Infrastructure.md',
    'agents/AGENTS_Python.md',
    'agents/AGENTS_Bash.md',
    'docs/ADOPTION_GUIDE.md',
    'docs/DOWNSTREAM_CANARY.md',
    'docs/DOWNSTREAM_COMPATIBILITY.md',
    'docs/DOWNSTREAM_CONFIGURATION.md',
    'docs/GOVERNANCE_ARCHITECTURE.md',
    'docs/ACTION_SECURITY.md',
    'docs/VALIDATOR_DEPENDENCIES.md',
    'docs/BACKLOG_MANAGEMENT.md',
    'docs/MAINTAINER_GUIDE.md',
    'docs/VERSIONING.md',
    'docs/RELEASE_PROCESS.md',
    'docs/BRANCH_PROTECTION.md',
    'docs/TROUBLESHOOTING.md'
)
$isDownstream = $false

$configPath = Join-Path $root 'governance.config.json'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $config = Read-JsonFile -Path $configPath
        $profile = [string]$config['workflowProfile']
        if ($config['schemaVersion'] -in @('1.0.0','1.1.0')) {
            # Match the aggregate's canonical manifest and identity rule for legacy configs.
            $manifestPath = Resolve-SafePath -Root $root -ChildPath 'project-manifest.json'
            $manifest = Read-JsonFile -Path $manifestPath
            $profile = if ($manifest.projectType -eq 'governance' -and $manifest.repository -eq 'AIAllTheThingz/Engineering-Standards') { 'standards-maintainer' } else { 'downstream' }
        }
        if ($profile -ceq 'downstream') {
            $isDownstream = $true
            $configuredDocumentation = @($config.requiredDocumentationPaths)
            if ($configuredDocumentation.Count -gt 0) {
                $authoritative = $configuredDocumentation
            }
        }
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message "Unable to read governance configuration: $($_.Exception.Message)" -Path 'governance.config.json'))
    }
}

function Get-WordCount {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    @($Text -split '\s+' | Where-Object { $_ }).Count
}

function Hide-FencedMarkdownHeadings {
    param([AllowEmptyString()][string]$Text)
    $Text = $Text -replace '\r\n?', "`n"
    $document = [Markdig.Markdown]::Parse($Text, $markdownPipeline, $null)
    $markupNodes = [Markdig.Syntax.MarkdownObjectExtensions]::Descendants($document) | Where-Object {
        ($_ -is [Markdig.Syntax.Inlines.HtmlInline] -and $_.Tag.StartsWith('<!--')) -or
        ($_ -is [Markdig.Syntax.HtmlBlock]) -or ($_ -is [Markdig.Extensions.Yaml.YamlFrontMatterBlock])
    } | Sort-Object { $_.Span.Start } -Descending
    foreach ($node in $markupNodes) {
        $source = $Text.Substring($node.Span.Start, $node.Span.Length)
        $visible = if ($node -is [Markdig.Extensions.Yaml.YamlFrontMatterBlock]) {
            $source -replace '[^\r\n]', ' '
        }
        elseif ($node -is [Markdig.Syntax.HtmlBlock] -and $node.Type -ne [Markdig.Syntax.HtmlBlockType]::Comment) {
            # Raw HTML remains section content, but cannot open Markdown headings or fences.
            $source -replace '(?m)^( {0,3})(?=[#`~])', '$1\'
        }
        else { [regex]::Replace($source, '(?s)<!--.*?(?:-->|\z)', {
            param($match)
            $match.Value -replace '[^\r\n]', ' '
        }) }
        $Text = $Text.Remove($node.Span.Start, $node.Span.Length).Insert($node.Span.Start, $visible)
    }
    # Normalize titles from parsed text so both section counting and empty-title checks agree.
    $document = [Markdig.Markdown]::Parse($Text, $markdownPipeline, $null)
    $headings = [Markdig.Syntax.MarkdownObjectExtensions]::Descendants($document) | Where-Object {
        $_ -is [Markdig.Syntax.HeadingBlock] -and $_.Level -le 3
    } | Sort-Object { $_.Span.Start } -Descending
    foreach ($heading in $headings) {
        $title = foreach ($inline in [Markdig.Syntax.MarkdownObjectExtensions]::Descendants($heading.Inline)) {
            if ($inline -is [Markdig.Syntax.Inlines.LiteralInline] -or $inline -is [Markdig.Syntax.Inlines.CodeInline]) { $inline.Content.ToString() }
            elseif ($inline -is [Markdig.Syntax.Inlines.HtmlEntityInline]) { $inline.Transcoded.ToString() }
            elseif ($inline -is [Markdig.Syntax.Inlines.AutolinkInline]) { $inline.Url }
        }
        if ([string]::IsNullOrWhiteSpace($title -join '')) {
            $Text = $Text.Remove($heading.Span.Start, $heading.Span.Length).Insert($heading.Span.Start, ('#' * $heading.Level))
        }
        elseif ($heading.IsSetext) {
            # Give underline-style headings the same checks; keep literal hashes from becoming closing markers.
            $visibleTitle = ($title -join '') -replace '\r?\n', ' ' -replace '#', '\#'
            $Text = $Text.Remove($heading.Span.Start, $heading.Span.Length).Insert($heading.Span.Start, ('#' * $heading.Level) + ' ' + $visibleTitle)
        }
    }
    $fence = $null
    $lines = foreach ($line in ($Text -split "`r?`n")) {
        if ($null -eq $fence) {
            if ($line -match '^ {0,3}(`{3,}|~{3,})') { $fence = $Matches[1] }
            $line
        }
        else {
            # Code remains section content, but its headings are not document sections.
            if ($line -match ('^ {0,3}' + [regex]::Escape($fence[0]) + '{' + $fence.Length + ',}\s*$')) {
                $fence = $null
            }
            $line -replace '^ {0,3}#', 'code #'
        }
    }
    $lines -join "`n"
}

function Get-MarkdownHeadingCount {
    param([Parameter(Mandatory)][string]$Text)
    ([regex]::Matches((Hide-FencedMarkdownHeadings -Text $Text), '(?m)^ {0,3}#{1,3}[ \t]+\S')).Count
}

function Test-EmptyMarkdownHeading {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $localResults = [System.Collections.Generic.List[object]]::new()
    $lines = (Hide-FencedMarkdownHeadings -Text $Text) -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^ {0,3}(#{1,3})(?:[ \t]+(.*))?$') {
            $level = $Matches[1].Length
            $title = if ($Matches.ContainsKey(2)) { $Matches[2] -replace '(?:^|[ \t]+)#+[ \t]*$', '' } else { '' }
            if ([string]::IsNullOrWhiteSpace($title)) {
                $localResults.Add((New-ValidationResult -Status Failed -Message 'Document contains an empty heading title.' -Path $RelativePath))
                break
            }
            $hasBody = $false
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^ {0,3}(#{1,3})(?:[ \t]+.*)?$') {
                    $nextLevel = $Matches[1].Length
                    if ($nextLevel -le $level) { break }
                    $hasBody = $true
                    break
                }
                if (-not [string]::IsNullOrWhiteSpace($lines[$j])) {
                    $hasBody = $true
                    break
                }
            }
            if (-not $hasBody) {
                $localResults.Add((New-ValidationResult -Status Failed -Message 'Document contains an empty heading.' -Path $RelativePath))
                break
            }
        }
    }
    @($localResults)
}

function Test-AuthoritativeDocument {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$FullPath,
        [switch]$Downstream
    )

    $localResults = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
        $localResults.Add((New-ValidationResult -Status Failed -Message 'Required authoritative document is missing.' -Path $RelativePath))
        return @($localResults)
    }

    $text = Get-Content -LiteralPath $FullPath -Raw
    if ([string]::IsNullOrWhiteSpace($text)) {
        $localResults.Add((New-ValidationResult -Status Failed -Message 'Required document is empty.' -Path $RelativePath))
        return @($localResults)
    }
    $words = Get-WordCount -Text (Hide-FencedMarkdownHeadings -Text $text)
    if ($text -match $placeholderPattern) {
        $localResults.Add((New-ValidationResult -Status Failed -Message 'Unresolved placeholder or fake command found.' -Path $RelativePath))
    }
    $headings = Get-MarkdownHeadingCount -Text $text
    $requiredTerms = @('MUST','Validation','Evidence','Exception','Related')
    $minimumWords = if ($Downstream) { 100 } else { 300 }
    $minimumHeadings = if ($Downstream) { 3 } elseif ($RelativePath -eq 'README.md') { 0 } else { 5 }
    if ($Downstream) { $requiredTerms = @() }

    if ($words -lt $minimumWords) {
        $localResults.Add((New-ValidationResult -Status Failed -Message "Document is too shallow for an authoritative file ($words words)." -Path $RelativePath))
    }
    if ($headings -lt $minimumHeadings) {
        $localResults.Add((New-ValidationResult -Status Failed -Message "Document has too few meaningful sections ($headings headings)." -Path $RelativePath))
    }
    foreach ($term in $requiredTerms) {
        if ($text -notmatch [regex]::Escape($term)) {
            $localResults.Add((New-ValidationResult -Status Failed -Message "Document is missing required concept '$term'." -Path $RelativePath))
        }
    }
    foreach ($item in @(Test-EmptyMarkdownHeading -Text $text -RelativePath $RelativePath)) { $localResults.Add($item) }
    @($localResults)
}

foreach ($rel in $authoritative) {
    try {
        $fullPath = Resolve-SafePath -Root $root -ChildPath $rel -AllowMissingLeaf
        foreach ($item in @(Test-AuthoritativeDocument -RelativePath $rel -FullPath $fullPath -Downstream:$isDownstream)) { $results.Add($item) }
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $rel))
    }
}

$inGit = $false
if (Get-Command git -ErrorAction SilentlyContinue) {
    $null = & git -C $root rev-parse --is-inside-work-tree 2>$null
    $inGit = $LASTEXITCODE -eq 0
}
if ($inGit) {
    $paths = @(& git -C $root ls-files --cached --others --exclude-standard -z) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate repository documentation with Git.' }
    $allMarkdown = foreach ($relativePath in ($paths -split "`0")) {
        if ($relativePath -match '\.md$') {
            $fullPath = Join-Path $root $relativePath
            if (Test-Path -LiteralPath $fullPath -PathType Leaf) { Get-Item -LiteralPath $fullPath -Force }
        }
    }
}
else {
    $allMarkdown = Get-ChildItem -LiteralPath $root -Filter '*.md' -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
}
foreach ($file in $allMarkdown) {
    $rel = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
    $text = Get-Content -LiteralPath $file.FullName -Raw
    $isTemplate = -not ($rel -notlike 'templates/*' -and $rel -notmatch '^(?:(?:\.github|docs)/)?pull_request_template(?:\.md$|/[^/]+\.md$)' -and $rel -notlike '.github/ISSUE_TEMPLATE/*')
    if (-not $isTemplate -and $text -match $placeholderPattern) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Unresolved placeholder or fake command found.' -Path $rel))
    }
    # GitHub forms intentionally have unfilled sections; required authoritative documents are checked above.
    if (-not $isTemplate) {
        foreach ($item in @(Test-EmptyMarkdownHeading -Text $text -RelativePath $rel)) { $results.Add($item) }
    }
}

$skillPlanRelativePath = 'docs/CODEX_SKILLS.md'
$skillPlanPath = Join-Path $root $skillPlanRelativePath
if (Test-Path -LiteralPath $skillPlanPath -PathType Leaf) {
    $skillPlanText = Get-Content -LiteralPath $skillPlanPath -Raw
    $demoResolvedSkills = @(
        'powershell-review',
        'build-pester-tests',
        'safe-automation',
        'governance-validation',
        'completion-evidence',
        'vendor-documentation-analysis',
        'infrastructure-automation-design'
    )

    foreach ($skill in $demoResolvedSkills) {
        $escapedSkill = [regex]::Escape($skill)
        $issueLinkedRow = "(?m)^\|[^\r\n]*$escapedSkill[^\r\n]*\[#(?<issue>\d+)\]\(https://github\.com/AIAllTheThingz/Engineering-Standards/issues/\k<issue>\)[^\r\n]*\|\s*$"
        if ([regex]::Matches($skillPlanText, $issueLinkedRow).Count -ne 1) {
            $results.Add((New-ValidationResult -Status Failed -Message "Demo-resolved skill '$skill' must appear exactly once in an authoritative GitHub issue-linked resolution table row." -Path $skillPlanRelativePath))
        }

        $proseOnlyPattern = "(?m)^\s*(?:\d+\.|[-*]\s+\[[ xX]\])\s+``?$escapedSkill``?\s*$"
        if ($skillPlanText -match $proseOnlyPattern) {
            $results.Add((New-ValidationResult -Status Failed -Message "Demo-resolved skill '$skill' is represented by a prose-only numbered or unchecked list item." -Path $skillPlanRelativePath))
        }
    }
}

$examplesRoot = Join-Path $root 'examples'
if (Test-Path -LiteralPath $examplesRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $examplesRoot -Recurse -File -Include package.json,*.md,*.ps1,*.yml) {
        $rel = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ($text -match 'echo (lint|tests|build) configured') {
            $results.Add((New-ValidationResult -Status Failed -Message 'Example contains fake validation command.' -Path $rel))
        }
    }
}

if ($results.Count -eq 0) {
    $results.Add((New-ValidationResult -Status Passed -Message 'Documentation completeness validation passed.' -Path $root -Severity info))
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0) { exit 1 }
exit 0
