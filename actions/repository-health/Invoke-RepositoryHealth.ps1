<#
.SYNOPSIS
Checks repository health.
.DESCRIPTION
Inspects required docs, ownership, manifest, config, CI, templates, and JSON parsing.
.PARAMETER Path
Repository path.
.PARAMETER OutputJson
Optional report.
.PARAMETER Advisory
Do not fail process.
.EXAMPLE
pwsh -File Invoke-RepositoryHealth.ps1 -Path .
.OUTPUTS
Console and JSON.
.NOTES
Does not execute repository content.
#>
[CmdletBinding()]param([string]$Path='.',[string]$OutputJson,[switch]$Advisory)Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force;$root=(Resolve-Path $Path).Path;$res=[Collections.Generic.List[object]]::new();foreach($i in @('README.md','LICENSE','SECURITY.md','CONTRIBUTING.md','CODEOWNERS','project-manifest.json','governance.config.json','AGENTS.md','.github/dependabot.yml','.github/workflows/governance-ci.yml','.github/pull_request_template.md')){$f=Resolve-SafePath $root $i;if(Test-Path $f){$res.Add((New-ValidationResult Passed 'Required health file exists.' $i info))}else{$res.Add((New-ValidationResult Failed 'Required health file missing.' $i))}};if((Test-Path (Join-Path $root CODEOWNERS)) -and (Get-Content (Join-Path $root CODEOWNERS) -Raw) -match 'REPLACE-ME'){$res.Add((New-ValidationResult Warning 'CODEOWNERS placeholders remain.' CODEOWNERS warning))};foreach($jf in Get-ChildItem $root -Filter *.json -Recurse|?{$_.FullName -notmatch '\\.git\\'}){try{Read-JsonFile $jf.FullName|Out-Null}catch{$res.Add((New-ValidationResult Failed "Invalid JSON: $($_.Exception.Message)" ([IO.Path]::GetRelativePath($root,$jf.FullName))))}};$failed=@($res|? status -eq Failed).Count;$rep=[ordered]@{generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o');results=@($res);failed=$failed;warnings=@($res|? status -eq Warning).Count};if($OutputJson){$rep|ConvertTo-OrderedJson|Set-Content $OutputJson -Encoding utf8};$rep.results|%{"[$($_.status)] $($_.path) $($_.message)"};if($failed -and -not $Advisory){exit 1};exit 0
