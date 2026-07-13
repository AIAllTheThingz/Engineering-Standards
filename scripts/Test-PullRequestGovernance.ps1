<#.SYNOPSIS Validates a pull-request governance body from trusted file inputs. #>
[CmdletBinding(DefaultParameterSetName='Fixture')]
param(
 [Parameter(Mandatory,ParameterSetName='Fixture')][string]$BodyPath,
 [Parameter(Mandatory,ParameterSetName='Event')][string]$EventPath,
 [Parameter(Mandatory)][string]$ChangedFilesPath,
 [Parameter(Mandatory,ParameterSetName='Fixture')][string]$Actor,
 [Parameter(Mandatory,ParameterSetName='Fixture')][string]$Repository,
 [Parameter(Mandatory,ParameterSetName='Fixture')][int]$PullRequestNumber,
 [string]$GovernanceConfigPath='governance.config.json',[Parameter(Mandatory)][string]$OutputJson
)
Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'PullRequestGovernance.psm1') -Force
if($PSCmdlet.ParameterSetName -eq 'Event'){$event=Get-Content -LiteralPath $EventPath -Raw|ConvertFrom-Json;$Body=$event.pull_request.body;$Actor=$event.pull_request.user.login;$Repository=$event.repository.full_name;$PullRequestNumber=[int]$event.pull_request.number}else{$Body=Get-Content -LiteralPath $BodyPath -Raw}
$filePayload=Get-Content -LiteralPath $ChangedFilesPath -Raw|ConvertFrom-Json
$complete=$true; if($filePayload -isnot [array] -and $filePayload.PSObject.Properties.Name -contains 'files'){$files=@($filePayload.files);if($filePayload.PSObject.Properties.Name -contains 'complete'){$complete=[bool]$filePayload.complete}}else{$files=@($filePayload)}
$config=if(Test-Path -LiteralPath $GovernanceConfigPath){Get-Content -LiteralPath $GovernanceConfigPath -Raw|ConvertFrom-Json}else{$null}
$result=Test-PullRequestGovernanceRecord -Body $Body -ChangedFiles $files -Actor $Actor -Repository $Repository -PullRequestNumber $PullRequestNumber -GovernanceConfig $config -ChangedFilesComplete $complete
$parent=Split-Path -Parent $OutputJson;if($parent){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputJson -Encoding utf8
$result.findings|ForEach-Object{"[$($_.status)] $($_.message)"}; if($result.status -eq 'Passed'){exit 0}elseif($result.status -eq 'Blocked'){exit 2}else{exit 1}
