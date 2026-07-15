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

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()

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
    'docs/ADOPTION_GUIDE.md',
    'docs/DOWNSTREAM_CANARY.md',
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

function Get-WordCount {
    param([Parameter(Mandatory)][string]$Text)
    @($Text -split '\s+' | Where-Object { $_ }).Count
}

function Get-MarkdownHeadingCount {
    param([Parameter(Mandatory)][string]$Text)
    ([regex]::Matches($Text, '(?m)^#{1,3}\s+\S')).Count
}

function Test-EmptyMarkdownHeading {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $localResults = [System.Collections.Generic.List[object]]::new()
    $lines = $Text -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(#{1,3})\s+\S') {
            $level = $Matches[1].Length
            $hasBody = $false
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^(#{1,3})\s+\S') {
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
        [Parameter(Mandatory)][string]$FullPath
    )

    $localResults = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
        $localResults.Add((New-ValidationResult -Status Failed -Message 'Required authoritative document is missing.' -Path $RelativePath))
        return @($localResults)
    }

    $text = Get-Content -LiteralPath $FullPath -Raw
    $words = Get-WordCount -Text $text
    $headings = Get-MarkdownHeadingCount -Text $text
    $requiredTerms = @('MUST','Validation','Evidence','Exception','Related')

    if ($words -lt 300) {
        $localResults.Add((New-ValidationResult -Status Failed -Message "Document is too shallow for an authoritative file ($words words)." -Path $RelativePath))
    }
    if ($headings -lt 5 -and $RelativePath -ne 'README.md') {
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
    foreach ($item in @(Test-AuthoritativeDocument -RelativePath $rel -FullPath (Join-Path $root $rel))) { $results.Add($item) }
}

$allMarkdown = Get-ChildItem -LiteralPath $root -Filter '*.md' -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' }
foreach ($file in $allMarkdown) {
    $rel = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($rel -notlike 'templates/*' -and $text -match '(?i)template only|echo tests configured|echo lint configured|REPLACE-ME|placeholder-only') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Unresolved placeholder or fake command found.' -Path $rel))
    }
    if ($rel -notlike 'templates/*') {
        foreach ($item in @(Test-EmptyMarkdownHeading -Text $text -RelativePath $rel)) { $results.Add($item) }
    }
}

$skillPlanRelativePath = 'docs/CODEX_SKILLS.md'
$skillPlanPath = Join-Path $root $skillPlanRelativePath
if (Test-Path -LiteralPath $skillPlanPath -PathType Leaf) {
    $skillPlanText = Get-Content -LiteralPath $skillPlanPath -Raw
    $plannedSkills = @(
        'powershell-review',
        'build-pester-tests',
        'safe-automation',
        'governance-validation',
        'completion-evidence',
        'vendor-documentation-analysis',
        'infrastructure-automation-design'
    )

    foreach ($skill in $plannedSkills) {
        $escapedSkill = [regex]::Escape($skill)
        $issueLinkedRow = "(?m)^\|[^\r\n]*$escapedSkill[^\r\n]*\[#(?<issue>\d+)\]\(https://github\.com/AIAllTheThingz/Engineering-Standards/issues/\k<issue>\)[^\r\n]*\|\s*$"
        if ([regex]::Matches($skillPlanText, $issueLinkedRow).Count -ne 1) {
            $results.Add((New-ValidationResult -Status Failed -Message "Planned skill '$skill' must appear exactly once in an authoritative GitHub issue-linked table row." -Path $skillPlanRelativePath))
        }

        $proseOnlyPattern = "(?m)^\s*(?:\d+\.|[-*]\s+\[[ xX]\])\s+``?$escapedSkill``?\s*$"
        if ($skillPlanText -match $proseOnlyPattern) {
            $results.Add((New-ValidationResult -Status Failed -Message "Planned skill '$skill' is represented by a prose-only numbered or unchecked list item." -Path $skillPlanRelativePath))
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
