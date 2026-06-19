<#
.SYNOPSIS
Validates governance contract files.
.DESCRIPTION
Checks manifest, config, required docs, and exception controls.
.PARAMETER Path
Repository path.
.PARAMETER ManifestPath
Manifest path.
.PARAMETER ConfigPath
Config path.
.PARAMETER OutputJson
Optional report.
.PARAMETER Advisory
Do not fail process.
.EXAMPLE
pwsh -File Invoke-ContractValidation.ps1 -Path .
.OUTPUTS
Console and JSON.
.NOTES
Rejects path traversal.
#>
[CmdletBinding()]param([string]$Path='.',[string]$ManifestPath='project-manifest.json',[string]$ConfigPath='governance.config.json',[string]$OutputJson,[switch]$Advisory)Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force;$root=(Resolve-Path $Path).Path;$res=[Collections.Generic.List[object]]::new();try{$mf=Resolve-SafePath $root $ManifestPath;$cf=Resolve-SafePath $root $ConfigPath}catch{$res.Add((New-ValidationResult Failed $_.Exception.Message))};if($res.Count -eq 0){if(Test-Path $mf){foreach($item in @(Test-GovernanceJsonDocument $mf project-manifest)){$res.Add($item)}}else{$res.Add((New-ValidationResult Failed 'Project manifest missing.' $ManifestPath))};if(Test-Path $cf){foreach($item in @(Test-GovernanceJsonDocument $cf governance-config)){$res.Add($item)};$cfg=Read-JsonFile $cf;foreach($d in @($cfg.requiredDocumentationPaths)){$rp=Resolve-SafePath $root $d;if(-not(Test-Path $rp)){$res.Add((New-ValidationResult Failed 'Required documentation missing.' $d))}}}else{$res.Add((New-ValidationResult Failed 'Governance config missing.' $ConfigPath))}};if(-not(@($res|? status -eq Failed))){$res.Add((New-ValidationResult Passed 'Governance contract validation completed.' $root info))};$rep=[ordered]@{generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o');results=@($res);failed=@($res|? status -eq Failed).Count};if($OutputJson){$rep|ConvertTo-OrderedJson|Set-Content $OutputJson -Encoding utf8};$rep.results|%{"[$($_.status)] $($_.path) $($_.message)"};if($rep.failed -and -not $Advisory){exit 1};exit 0
