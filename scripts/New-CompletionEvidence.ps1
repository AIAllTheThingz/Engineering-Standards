<#
.SYNOPSIS
Generates completion evidence.
.DESCRIPTION
Creates completion-result JSON and refuses Passed when tests are failed, blocked, or not run.
.PARAMETER RepositoryPath
Repository root.
.PARAMETER OutputPath
Output path.
.PARAMETER GovernanceVersion
Governance version.
.PARAMETER RiskClassification
Risk classification.
.PARAMETER Status
Overall status.
.PARAMETER Summary
Summary.
.PARAMETER CommandsExecuted
Commands executed.
.PARAMETER CommandsNotExecuted
Commands not executed.
.PARAMETER TestResultPath
Optional test evidence array.
.PARAMETER ArtifactPath
Artifacts to hash.
.EXAMPLE
pwsh -File scripts/New-CompletionEvidence.ps1 -OutputPath evidence/completion-result.json -Summary done
.OUTPUTS
JSON file.
.NOTES
Unknown metadata is recorded as unknown.
#>
[CmdletBinding()]param([string]$RepositoryPath='.',[Parameter(Mandatory)][string]$OutputPath,[string]$GovernanceVersion='1.0.0',[ValidateSet('Low','Moderate','High','Critical')][string]$RiskClassification='Moderate',[ValidateSet('Passed','Failed','NotRun','NotApplicable','Blocked')][string]$Status='NotRun',[Parameter(Mandatory)][string]$Summary,[string[]]$CommandsExecuted=@(),[string[]]$CommandsNotExecuted=@(),[string]$TestResultPath,[string[]]$ArtifactPath=@(),[string[]]$Warnings=@(),[string[]]$KnownLimitations=@(),[string[]]$RemainingRisks=@(),[string[]]$Exceptions=@(),[string[]]$Approvals=@())Set-StrictMode -Version Latest;$ErrorActionPreference='Stop';Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force;$root=(Resolve-Path $RepositoryPath).Path;$tests=@();if($TestResultPath){$tests=@(Read-JsonFile (Resolve-SafePath $root $TestResultPath))};if($Status -eq 'Passed'){foreach($t in $tests){if($t.status -in @('Failed','NotRun','Blocked')){throw "Cannot emit Passed because test '$($t.name)' is '$($t.status)'"}}};$arts=@();foreach($a in $ArtifactPath){$r=Resolve-SafePath $root $a;if(Test-Path $r){$arts+=[ordered]@{path=$a;sha256=(Get-FileHash $r -Algorithm SHA256).Hash.ToLowerInvariant();artifactType='report';description="Generated artifact $a"}}};$commit=(& git -C $root rev-parse HEAD 2>$null);if($LASTEXITCODE -ne 0 -or -not $commit){$commit='unknown'};$branch=(& git -C $root rev-parse --abbrev-ref HEAD 2>$null);if($LASTEXITCODE -ne 0 -or -not $branch){$branch='unknown'};$e=[ordered]@{schemaVersion='1.0.0';repository='AIAllTheThingz/Engineering-Standards';commitSha=$commit.Trim();branch=$branch.Trim();pullRequest=$null;governanceVersion=$GovernanceVersion;riskClassification=$RiskClassification;status=$Status;startedAtUtc=(Get-Date).ToUniversalTime().ToString('o');completedAtUtc=(Get-Date).ToUniversalTime().ToString('o');summary=$Summary;changedFiles=@(& git -C $root status --short 2>$null|%{$_.Substring(3)});commandsExecuted=@($CommandsExecuted);commandsNotExecuted=@($CommandsNotExecuted);tests=@($tests);artifacts=@($arts);warnings=@($Warnings);knownLimitations=@($KnownLimitations);remainingRisks=@($RemainingRisks);exceptions=@($Exceptions);approvals=@($Approvals)};$out=Resolve-SafePath $root $OutputPath;New-Item -ItemType Directory -Path (Split-Path $out) -Force|Out-Null;$e|ConvertTo-OrderedJson|Set-Content $out -Encoding utf8;Write-Output "Completion evidence written to $out"
