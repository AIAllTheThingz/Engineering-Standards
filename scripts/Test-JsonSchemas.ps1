<#
.SYNOPSIS
Validates JSON schemas and fixtures.
.DESCRIPTION
Parses schema files and checks valid and invalid fixtures.
.PARAMETER Path
Repository root.
.PARAMETER OutputJson
Optional report path.
.EXAMPLE
pwsh -File scripts/Test-JsonSchemas.ps1 -Path .
.OUTPUTS
Console and optional JSON.
.NOTES
No global installs.
#>
[CmdletBinding()]param([string]$Path='.',[string]$OutputJson)Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force;$root=(Resolve-Path $Path).Path;$res=[Collections.Generic.List[object]]::new();foreach($s in Get-ChildItem (Join-Path $root schemas) -Filter *.schema.json){try{$d=Read-JsonFile $s.FullName;foreach($p in @('$schema','$id','type','properties')){if(-not($d.PSObject.Properties.Name -contains $p)){$res.Add((New-ValidationResult Failed "Schema missing $p." $s.FullName))}};$res.Add((New-ValidationResult Passed 'Schema parsed.' $s.FullName info))}catch{$res.Add((New-ValidationResult Failed "Schema parse failed: $($_.Exception.Message)" $s.FullName))}};$map=@{'completion-result'='completion-result';'test-evidence'='test-evidence';'artifact-record'='artifact-record';'project-manifest'='project-manifest';'governance-config'='governance-config'};foreach($m in @('valid','invalid')){$dir=Join-Path $root "tests/fixtures/$m";if(Test-Path $dir){foreach($f in Get-ChildItem $dir -Filter *.json){$kind=$null;foreach($k in $map.Keys){if($f.BaseName -like "$k*"){$kind=$map[$k]}};if($kind){$rr=@(Test-GovernanceJsonDocument $f.FullName $kind);$failed=@($rr|? status -eq Failed).Count -gt 0;if($m -eq 'valid' -and -not $failed){$res.Add((New-ValidationResult Passed 'Valid fixture accepted.' $f.FullName info))}elseif($m -eq 'invalid' -and $failed){$res.Add((New-ValidationResult Passed 'Invalid fixture rejected.' $f.FullName info))}else{$res.Add((New-ValidationResult Failed 'Fixture expectation failed.' $f.FullName $null $rr))}}}}};$rep=[ordered]@{generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o');results=@($res);failed=@($res|? status -eq Failed).Count};if($OutputJson){$rep|ConvertTo-OrderedJson|Set-Content $OutputJson -Encoding utf8};$rep.results|%{"[$($_.status)] $($_.path) $($_.message)"};if($rep.failed){exit 1};exit 0
