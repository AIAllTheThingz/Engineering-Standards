<#.SYNOPSIS Retrieves all changed filenames through the GitHub API as JSON data. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$EventPath,[Parameter(Mandatory)][string]$OutputJson)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$event=Get-Content -LiteralPath $EventPath -Raw|ConvertFrom-Json;$repository=[string]$event.repository.full_name;$number=[int]$event.pull_request.number;$expected=[int]$event.pull_request.changed_files
if($repository -notmatch '^[^/\s]+/[^/\s]+$' -or $number -lt 1 -or $expected -lt 0){throw 'Required pull-request metadata is missing or invalid.'}
$files=[Collections.Generic.List[string]]::new();$page=1
do{$response=@(& gh api -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' "repos/$repository/pulls/$number/files?per_page=100&page=$page" 2>&1);if($LASTEXITCODE -ne 0){throw "Changed-file retrieval failed on page $page."};$items=@(($response -join "`n")|ConvertFrom-Json);foreach($item in $items){$files.Add([string]$item.filename)};$page++;if($page -gt 31){throw 'Changed-file pagination exceeded the safe API bound.'}}while($items.Count -eq 100)
$complete=$files.Count -eq $expected;$payload=[ordered]@{complete=$complete;expectedCount=$expected;retrievedCount=$files.Count;files=@($files)};$parent=Split-Path -Parent $OutputJson;if($parent){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$payload|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $OutputJson -Encoding utf8;if(-not $complete){throw 'Changed-file retrieval was incomplete.'}
