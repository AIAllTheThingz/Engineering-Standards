<#
.SYNOPSIS
Validates substantive documentation completeness.
.DESCRIPTION
Checks required headings, shallow sections, boilerplate, placeholders, fake commands, examples, validation sections, evidence sections, exception sections, and related-document sections.
.PARAMETER Path
Repository root.
.PARAMETER OutputJson
Optional JSON report path.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .
.OUTPUTS
Console report and optional JSON.
.NOTES
This script validates document substance signals; it is intentionally stricter for authoritative docs than for templates.
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
    'docs/DOWNSTREAM_CONFIGURATION.md',
    'docs/GOVERNANCE_ARCHITECTURE.md',
    'docs/ACTION_SECURITY.md',
    'docs/MAINTAINER_GUIDE.md',
    'docs/VERSIONING.md',
    'docs/RELEASE_PROCESS.md',
    'docs/BRANCH_PROTECTION.md',
    'docs/TROUBLESHOOTING.md'
)
$requiredTerms = @('MUST','Validation','Evidence','Exception','Related')
foreach ($rel in $authoritative) {
    $full = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $full)) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Required authoritative document is missing.' -Path $rel))
        continue
    }
    $text = Get-Content -LiteralPath $full -Raw
    $words = ($text -split '\s+' | Where-Object { $_ }).Count
    $headings = ([regex]::Matches($text, '(?m)^#{1,3}\s+')).Count
    if ($words -lt 300 -and $rel -notin @('AGENTS.md','CHANGELOG.md')) {
        $results.Add((New-ValidationResult -Status Failed -Message "Document is too shallow for an authoritative file ($words words)." -Path $rel))
    }
    if ($headings -lt 5 -and $rel -notin @('README.md')) {
        $results.Add((New-ValidationResult -Status Failed -Message "Document has too few meaningful sections ($headings headings)." -Path $rel))
    }
    foreach ($term in $requiredTerms) {
        if ($text -notmatch [regex]::Escape($term)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Document is missing required concept '$term'." -Path $rel))
        }
    }
}

$allMarkdown = Get-ChildItem -LiteralPath $root -Filter '*.md' -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' }
foreach ($file in $allMarkdown) {
    $rel = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($rel -notlike 'templates/*' -and $text -match '(?i)template only|echo tests configured|echo lint configured|REPLACE-ME|placeholder-only') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Unresolved placeholder or fake command found.' -Path $rel))
    }
    if ($rel -notlike 'templates/*') {
        $lines = $text -split "`r?`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^(#{1,3})\s+') {
                $level = $Matches[1].Length
                $hasBody = $false
                for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                    if ($lines[$j] -match '^(#{1,3})\s+') {
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
                    $results.Add((New-ValidationResult -Status Failed -Message 'Document contains an empty heading.' -Path $rel))
                    break
                }
            }
        }
    }
}

foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root 'examples') -Recurse -File -Include package.json,*.md,*.ps1,*.yml) {
    $rel = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($text -match 'echo (lint|tests|build) configured') {
        $results.Add((New-ValidationResult -Status Failed -Message 'Example contains fake validation command.' -Path $rel))
    }
}

if ($results.Count -eq 0) {
    $results.Add((New-ValidationResult -Status Passed -Message 'Documentation completeness validation passed.' -Path $root -Severity info))
}
$report = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    results = @($results)
    failed = @($results | Where-Object status -eq 'Failed').Count
}
if ($OutputJson) {
    $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8
}
$report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0) { exit 1 }
exit 0
