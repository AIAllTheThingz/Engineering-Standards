<#
.SYNOPSIS
Validates internal Markdown links.
.DESCRIPTION
Checks relative links and skips external links.
.PARAMETER Path
Repository root.
.PARAMETER OutputJson
Optional report path.
.EXAMPLE
pwsh -File scripts/Test-MarkdownLinks.ps1 -Path .
.OUTPUTS
Console and optional JSON.
.NOTES
External links are not fetched.
#>
[CmdletBinding()]param([string]$Path='.',[string]$OutputJson)Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force;$root=(Resolve-Path $Path).Path;$res=[Collections.Generic.List[object]]::new();foreach($f in Get-ChildItem $root -Filter *.md -Recurse|?{$_.FullName -notmatch '\\.git\\'}){$c=Get-Content $f.FullName -Raw;foreach($m in [regex]::Matches($c,'(?<!!)\[[^\]]+\]\((?<t>[^)]+)\)')){$t=$m.Groups['t'].Value.Trim();if($t -match '^(https?:|mailto:|#)' -or $t -eq ''){continue};$t=$t.Split('#')[0].Trim('<','>');if($t){try{$r=Resolve-SafePath $f.DirectoryName $t;if(-not(Test-Path $r)){$res.Add((New-ValidationResult Failed "Missing Markdown target '$t'." $f.FullName))}}catch{$res.Add((New-ValidationResult Failed $_.Exception.Message $f.FullName))}}}};if($res.Count -eq 0){$res.Add((New-ValidationResult Passed 'Internal Markdown links validated.' $root info))};$rep=[ordered]@{generatedAtUtc=(Get-Date).ToUniversalTime().ToString('o');results=@($res);failed=@($res|? status -eq Failed).Count};if($OutputJson){$rep|ConvertTo-OrderedJson|Set-Content $OutputJson -Encoding utf8};$rep.results|%{"[$($_.status)] $($_.path) $($_.message)"};if($rep.failed){exit 1};exit 0
