<#
.SYNOPSIS
Runs local governance validation.
.DESCRIPTION
Orchestrates contract, schema, Markdown, scanner, health, evidence, and example validation.
.PARAMETER Path
Repository path.
.PARAMETER Category
Categories to run.
.PARAMETER OutputFormat
Human or Json.
.PARAMETER OutputJson
Optional report.
.EXAMPLE
pwsh -File scripts/Invoke-GovernanceValidation.ps1 -Path .
.OUTPUTS
Console and JSON.
.NOTES
Does not execute downstream code.
#>
[CmdletBinding()]param([string]$Path='.',[ValidateSet('Contract','JsonSchemas','MarkdownLinks','ForbiddenPatterns','RepositoryHealth','Evidence','Examples')][string[]]$Category=@('Contract','JsonSchemas','MarkdownLinks','ForbiddenPatterns','RepositoryHealth','Examples'),[ValidateSet('Human','Json')][string]$OutputFormat='Human',[string]$OutputJson)Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot GovernanceValidation.psm1) -Force;$root=(Resolve-Path $Path).Path;$items=[Collections.Generic.List[object]]::new();function Run($n,$f,$a){Write-Output "Running $n...";& pwsh -NoProfile -File $f @a;$c=$LASTEXITCODE;$items.Add((New-ValidationResult $(if($c){'Failed'}else{'Passed'}) "$n exited with code $c." $f $(if($c){'error'}else{'info'}) @{exitCode=$c}))};if($Category -contains 'Contract'){Run Contract (Join-Path $root actions/validate-contract/Invoke-ContractValidation.ps1) @('-Path',$root)};if($Category -contains 'JsonSchemas'){Run JsonSchemas (Join-Path $root scripts/Test-JsonSchemas.ps1) @('-Path',$root)};if($Category -contains 'MarkdownLinks'){Run MarkdownLinks (Join-Path $root scripts/Test-MarkdownLinks.ps1) @('-Path',$root)};if($Category -contains 'ForbiddenPatterns'){Run ForbiddenPatterns (Join-Path $root actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1) @('-Path',$root,'-PatternFile',(Join-Path $root actions/forbidden-pattern-scan/forbidden-patterns.json))};if($Category -contains 'RepositoryHealth'){Run RepositoryHealth (Join-Path $root actions/repository-health/Invoke-RepositoryHealth.ps1) @('-Path',$root)};if($Category -contains 'Examples'){foreach($e in Get-ChildItem (Join-Path $root examples) -Directory){Run "Example $($e.Name)" (Join-Path $root actions/validate-contract/Invoke-ContractValidation.ps1) @('-Path',$e.FullName)}};$failed=@($items|? status -eq Failed).Count;$rep=[ordered]@{generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o');results=@($items);failed=$failed};if($OutputJson){$rep|ConvertTo-OrderedJson|Set-Content $OutputJson -Encoding utf8};if($OutputFormat -eq 'Json'){$rep|ConvertTo-OrderedJson}else{$items|%{"[$($_.status)] $($_.path) $($_.message)"}};if($failed){exit 1};exit 0
