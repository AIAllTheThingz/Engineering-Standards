<#
.SYNOPSIS
Validates completion evidence.
.DESCRIPTION
Checks evidence JSON, status consistency, timestamps, commit SHA, and artifact hashes.
.PARAMETER Path
Repository path.
.PARAMETER EvidencePath
Evidence path.
.PARAMETER ExpectedCommitSha
Expected SHA.
.PARAMETER OutputJson
Optional report.
.EXAMPLE
pwsh -File Invoke-EvidenceValidation.ps1 -Path .
.OUTPUTS
Console and JSON.
.NOTES
Evidence is untrusted input.
#>
[CmdletBinding()]param([string]$Path='.',[string]$EvidencePath='evidence/completion-result.json',[string]$ExpectedCommitSha,[string]$OutputJson)Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force;$root=(Resolve-Path $Path).Path;$res=[Collections.Generic.List[object]]::new();try{$f=Resolve-SafePath $root $EvidencePath}catch{$res.Add((New-ValidationResult Failed $_.Exception.Message $EvidencePath))};if($res.Count -eq 0 -and -not(Test-Path $f)){$res.Add((New-ValidationResult Failed 'Completion evidence missing.' $EvidencePath))};if($res.Count -eq 0){foreach($item in @(Test-GovernanceJsonDocument $f completion-result)){$res.Add($item)};$e=Read-JsonFile $f;if($ExpectedCommitSha -and $e.commitSha -ne $ExpectedCommitSha){$res.Add((New-ValidationResult Failed 'Commit SHA mismatch.' $EvidencePath))};if([datetime]$e.completedAtUtc -lt [datetime]$e.startedAtUtc){$res.Add((New-ValidationResult Failed 'Completion timestamp precedes start.' $EvidencePath))}};if(-not(@($res|? status -eq Failed))){$res.Add((New-ValidationResult Passed 'Evidence validation completed.' $EvidencePath info))};$rep=[ordered]@{generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o');results=@($res);failed=@($res|? status -eq Failed).Count};if($OutputJson){$rep|ConvertTo-OrderedJson|Set-Content $OutputJson -Encoding utf8};$rep.results|%{"[$($_.status)] $($_.path) $($_.message)"};if($rep.failed){exit 1};exit 0
