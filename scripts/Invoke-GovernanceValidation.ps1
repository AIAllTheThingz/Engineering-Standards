<#
.SYNOPSIS
Runs local governance validation.
.DESCRIPTION
Orchestrates schema, YAML, workflow architecture, link, documentation, contract, scanner, repository-health, evidence, and example validation.
.PARAMETER Path
Repository path.
.PARAMETER Category
Validation categories.
.PARAMETER OutputJson
Optional report path.
.EXAMPLE
pwsh -File scripts/Invoke-GovernanceValidation.ps1 -Path .
.OUTPUTS
Console and optional JSON.
.NOTES
Does not execute untrusted downstream code.
#>
[CmdletBinding()]
param(
    [string]$Path='.',
    [ValidateSet('Contract','JsonSchemas','YamlSyntax','WorkflowArchitecture','MarkdownLinks','DocumentationCompleteness','ForbiddenPatterns','RepositoryHealth','Evidence','Examples')][string[]]$Category=@('JsonSchemas','YamlSyntax','WorkflowArchitecture','MarkdownLinks','DocumentationCompleteness','Contract','ForbiddenPatterns','RepositoryHealth','Examples'),
    [string]$OutputJson
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force
$root = (Resolve-Path -LiteralPath $Path).Path
$items = [System.Collections.Generic.List[object]]::new()
function Invoke-ValidationCommand {
    param([string]$Name, [string]$File, [string[]]$Arguments)
    Write-Output "Running $Name..."
    & pwsh -NoProfile -File $File @Arguments
    $code = $LASTEXITCODE
    $items.Add((New-ValidationResult -Status $(if ($code -eq 0) { 'Passed' } else { 'Failed' }) -Message "$Name exited with code $code." -Path $File -Severity $(if ($code -eq 0) { 'info' } else { 'error' }) -Data @{ exitCode=$code }))
}
if ($Category -contains 'JsonSchemas') { Invoke-ValidationCommand JsonSchemas (Join-Path $root 'scripts/Test-JsonSchemas.ps1') @('-Path',$root) }
if ($Category -contains 'YamlSyntax') { Invoke-ValidationCommand YamlSyntax (Join-Path $root 'scripts/Test-YamlSyntax.ps1') @('-Path',$root) }
if ($Category -contains 'WorkflowArchitecture') { Invoke-ValidationCommand WorkflowArchitecture (Join-Path $root 'scripts/Test-GitHubWorkflowArchitecture.ps1') @('-Path',$root,'-DefaultBranch','master') }
if ($Category -contains 'MarkdownLinks') { Invoke-ValidationCommand MarkdownLinks (Join-Path $root 'scripts/Test-MarkdownLinks.ps1') @('-Path',$root) }
if ($Category -contains 'DocumentationCompleteness') { Invoke-ValidationCommand DocumentationCompleteness (Join-Path $root 'scripts/Test-DocumentationCompleteness.ps1') @('-Path',$root) }
if ($Category -contains 'Contract') { Invoke-ValidationCommand Contract (Join-Path $root 'actions/validate-contract/Invoke-ContractValidation.ps1') @('-Path',$root) }
if ($Category -contains 'ForbiddenPatterns') { Invoke-ValidationCommand ForbiddenPatterns (Join-Path $root 'actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1') @('-Path',$root,'-PatternFile',(Join-Path $root 'actions/forbidden-pattern-scan/forbidden-patterns.json')) }
if ($Category -contains 'RepositoryHealth') { Invoke-ValidationCommand RepositoryHealth (Join-Path $root 'actions/repository-health/Invoke-RepositoryHealth.ps1') @('-Path',$root) }
if ($Category -contains 'Examples') {
    foreach ($example in Get-ChildItem -LiteralPath (Join-Path $root 'examples') -Directory) {
        Invoke-ValidationCommand "Example $($example.Name)" (Join-Path $root 'actions/validate-contract/Invoke-ContractValidation.ps1') @('-Path',$example.FullName)
    }
}
if ($Category -contains 'Evidence' -and (Test-Path (Join-Path $root 'evidence/completion-result.json'))) { Invoke-ValidationCommand Evidence (Join-Path $root 'actions/validate-evidence/Invoke-EvidenceValidation.ps1') @('-Path',$root,'-EvidencePath','evidence/completion-result.json') }
$failed = @($items | Where-Object status -eq 'Failed').Count
$report = [ordered]@{ generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o'); results=@($items); failed=$failed }
if ($OutputJson) { $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $OutputJson -Encoding utf8 }
$items | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($failed -gt 0) { exit 1 }
exit 0
