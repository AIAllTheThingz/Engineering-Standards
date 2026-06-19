<#
.SYNOPSIS
Runs defensive forbidden-pattern scanning.
.DESCRIPTION
Uses configurable regexes, redacts matches, and supports advisory execution. This is not a complete secret scanner.
.PARAMETER Path
Repository path.
.PARAMETER PatternFile
Pattern file.
.PARAMETER OutputJson
Optional report.
.PARAMETER Advisory
Do not fail process.
.EXAMPLE
pwsh -File Invoke-ForbiddenPatternScan.ps1 -Path .
.OUTPUTS
Console and JSON.
.NOTES
Does not print full suspected secrets.
#>
[CmdletBinding()]param([string]$Path='.',[string]$PatternFile,[string]$OutputJson,[switch]$Advisory)Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force;$root=(Resolve-Path $Path).Path;if(-not $PatternFile){$PatternFile=Join-Path $PSScriptRoot forbidden-patterns.json};$pats=(Read-JsonFile $PatternFile).patterns;$find=[Collections.Generic.List[object]]::new();foreach($f in Get-ChildItem $root -Recurse -File|?{$_.FullName -notmatch '\\.git\\|node_modules|TestResults' -and $_.Name -ne 'forbidden-patterns.json'}){if($f.Length -gt 1048576){continue};try{$c=Get-Content $f.FullName -Raw -ErrorAction Stop}catch{continue};$rel=[IO.Path]::GetRelativePath($root,$f.FullName).Replace('\','/');foreach($p in $pats){foreach($m in [regex]::Matches($c,$p.regex)){ $s=$m.Value;if($s.Length -gt 12){$s=$s.Substring(0,4)+'...[redacted]...'+$s.Substring($s.Length-4)}else{$s='[redacted]'};$find.Add([ordered]@{patternId=$p.id;severity=$p.severity;path=$rel;description=$p.description;redactedMatch=$s})}}};$failed=@($find|? severity -eq error).Count;$rep=[ordered]@{generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o');completeSecretScanner=$false;findings=@($find);failed=$failed};if($OutputJson){$rep|ConvertTo-OrderedJson|Set-Content $OutputJson -Encoding utf8};if($find.Count){$find|%{"[$($_.severity)] $($_.path) $($_.patternId): $($_.redactedMatch)"}}else{Write-Output '[Passed] No forbidden-pattern findings.'};if($failed -and -not $Advisory){exit 1};exit 0
