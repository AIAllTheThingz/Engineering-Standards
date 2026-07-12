<#
.SYNOPSIS
Checks repository governance health.
.DESCRIPTION
Checks required governance files, JSON parsing, schemas and fixtures, documentation completeness, tests, CODEOWNERS, Dependabot, workflows, action metadata, and evidence presence.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$OutputJson,
    [switch]$Advisory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../scripts/OwnershipProtection.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()

function Add-RequiredFileResult {
    param([Parameter(Mandatory)][string]$RelativePath)
    try {
        $full = Resolve-SafePath -Root $root -ChildPath $RelativePath -AllowMissingLeaf
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $results.Add((New-ValidationResult -Status Passed -Message 'Required health file exists.' -Path $RelativePath -Severity info))
        }
        else {
            $results.Add((New-ValidationResult -Status Failed -Message 'Required health file missing.' -Path $RelativePath))
        }
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $RelativePath))
    }
}

$required = @(
    'README.md',
    'LICENSE',
    'SECURITY.md',
    'CONTRIBUTING.md',
    'CODEOWNERS',
    'project-manifest.json',
    'governance.config.json',
    'AGENTS.md',
    '.github/dependabot.yml',
    '.github/workflows/governance-ci.yml',
    '.github/pull_request_template.md',
    'docs/BRANCH_PROTECTION.md',
    'docs/ACTION_SECURITY.md',
    'scripts/GovernanceValidation.psm1',
    'scripts/Test-DocumentationCompleteness.ps1',
    'scripts/Test-YamlSyntax.ps1',
    'scripts/Test-GitHubWorkflowArchitecture.ps1'
)
$required | ForEach-Object { Add-RequiredFileResult -RelativePath $_ }

$trackedGenerated = @(& git -C $root ls-files 2>$null | Where-Object {
    $_ -match '(^|/)(bin|obj|dist)(/|$)' -or $_ -match '^(coverage|TestResults)(/|$)'
})
foreach ($generated in $trackedGenerated) {
    $results.Add((New-ValidationResult -Status Failed -Message 'Generated build output must not be tracked.' -Path $generated))
}

foreach ($json in Get-ChildItem -LiteralPath $root -Filter '*.json' -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\|node_modules|bin\\|obj\\|dist\\' }) {
    try {
        Read-JsonFile -Path $json.FullName | Out-Null
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message "Invalid JSON: $($_.Exception.Message)" -Path ([System.IO.Path]::GetRelativePath($root, $json.FullName).Replace('\','/'))))
    }
}

if (Test-Path -LiteralPath (Join-Path $root 'project-manifest.json')) {
    foreach ($item in @(Test-GovernanceJsonDocument -Path (Join-Path $root 'project-manifest.json') -Kind 'project-manifest')) { $results.Add($item) }
}
if (Test-Path -LiteralPath (Join-Path $root 'governance.config.json')) {
    foreach ($item in @(Test-GovernanceJsonDocument -Path (Join-Path $root 'governance.config.json') -Kind 'governance-config')) { $results.Add($item) }
}

$documentationValidator = Join-Path $root 'scripts/Test-DocumentationCompleteness.ps1'
if (Test-Path -LiteralPath $documentationValidator -PathType Leaf) {
    & pwsh -NoProfile -File $documentationValidator -Path $root | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Documentation completeness failed.' -Path $root))
    }
}
else {
    $results.Add((New-ValidationResult -Status Failed -Message 'Documentation completeness validator missing.' -Path 'scripts/Test-DocumentationCompleteness.ps1'))
}

$schemaValidator = Join-Path $root 'scripts/Test-JsonSchemas.ps1'
if (Test-Path -LiteralPath $schemaValidator -PathType Leaf) {
    & pwsh -NoProfile -File $schemaValidator -Path $root | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $results.Add((New-ValidationResult -Status Failed -Message 'JSON schema and fixture validation failed.' -Path 'schemas'))
    }
}
else {
    $results.Add((New-ValidationResult -Status Failed -Message 'JSON schema validator missing.' -Path 'scripts/Test-JsonSchemas.ps1'))
}

$testFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Recurse -Filter '*.Tests.ps1' -File -ErrorAction SilentlyContinue)
if ($testFiles.Count -lt 1) {
    $results.Add((New-ValidationResult -Status Failed -Message 'No Pester tests found.' -Path 'tests'))
}
else {
    $results.Add((New-ValidationResult -Status Passed -Message "Pester test files found: $($testFiles.Count)." -Path 'tests' -Severity info))
}

$codeowners = Join-Path $root 'CODEOWNERS'
if (Test-Path -LiteralPath $codeowners) {
    $text = Get-Content -LiteralPath $codeowners -Raw
    $ownerType = if ((Read-JsonFile -Path (Join-Path $root 'project-manifest.json')).repository -match '^AIAllTheThingz/') { 'User' } else { 'Unknown' }
    foreach ($finding in @(Test-CodeownersContent -Content $text -RepositoryOwnerType $ownerType)) {
        $severity = if ($finding.Status -eq 'Passed') { 'info' } else { 'error' }
        $results.Add((New-ValidationResult -Status $finding.Status -Message $finding.Message -Path 'CODEOWNERS' -Severity $severity))
    }
}

foreach ($actionDir in Get-ChildItem -LiteralPath (Join-Path $root 'actions') -Directory -ErrorAction SilentlyContinue) {
    foreach ($requiredActionFile in @('action.yml','README.md')) {
        $candidate = Join-Path $actionDir.FullName $requiredActionFile
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Action is missing $requiredActionFile." -Path ([System.IO.Path]::GetRelativePath($root, $candidate).Replace('\','/'))))
        }
    }
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    $results.Add((New-ValidationResult -Status Passed -Message 'Repository health validation completed.' -Path $root -Severity info))
}

$report = New-ValidationReport -Results @($results)
if ($OutputJson) {
    $outPath = Resolve-SafePath -Root $root -ChildPath $OutputJson -AllowMissingLeaf
    New-Item -ItemType Directory -Path (Split-Path -Parent $outPath) -Force | Out-Null
    $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $outPath -Encoding utf8
}
$report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0 -and -not $Advisory) { exit 1 }
exit 0
