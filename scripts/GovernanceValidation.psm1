Set-StrictMode -Version Latest
function New-ValidationResult {
<#
.SYNOPSIS
Creates a standardized validation result.
.DESCRIPTION
Returns ordered validation data for console and JSON reports.
.PARAMETER Status
Validation status.
.PARAMETER Message
Human-readable message.
.PARAMETER Path
Related path.
.PARAMETER Severity
Severity label.
.PARAMETER Data
Optional data.
.EXAMPLE
New-ValidationResult -Status Failed -Message 'Missing file'
.OUTPUTS
Hashtable
.NOTES
Used by repository actions and scripts.
#>
[CmdletBinding()]param([string]$Status,[string]$Message,[string]$Path='',[string]$Severity='error',[object]$Data=$null)[ordered]@{status=$Status;severity=$Severity;message=$Message;path=$Path;data=$Data}}
function Resolve-SafePath {
<#
.SYNOPSIS
Resolves a path beneath a root.
.DESCRIPTION
Rejects path traversal outside the workspace.
.PARAMETER Root
Root path.
.PARAMETER ChildPath
Child path.
.EXAMPLE
Resolve-SafePath -Root . -ChildPath README.md
.OUTPUTS
String
.NOTES
No paths are created.
#>
[CmdletBinding()]param([string]$Root,[string]$ChildPath)$rf=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path);$c=if([IO.Path]::IsPathRooted($ChildPath)){$ChildPath}else{Join-Path $rf $ChildPath};$cf=[IO.Path]::GetFullPath($c);$pre=$rf.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar;if(-not($cf.Equals($rf,[StringComparison]::OrdinalIgnoreCase)-or $cf.StartsWith($pre,[StringComparison]::OrdinalIgnoreCase))){throw "Path '$ChildPath' resolves outside '$Root'."};$cf}
function Read-JsonFile {
<#
.SYNOPSIS
Reads JSON.
.DESCRIPTION
Parses JSON from disk.
.PARAMETER Path
JSON path.
.EXAMPLE
Read-JsonFile -Path project-manifest.json
.OUTPUTS
Object
.NOTES
Parse errors are thrown.
#>
[CmdletBinding()]param([string]$Path)Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json -Depth 100}
function Test-GovernanceJsonDocument {
<#
.SYNOPSIS
Validates known JSON documents.
.DESCRIPTION
Performs structural checks without executing untrusted content.
.PARAMETER Path
JSON file.
.PARAMETER Kind
Document kind.
.EXAMPLE
Test-GovernanceJsonDocument -Path project-manifest.json -Kind project-manifest
.OUTPUTS
Object[]
.NOTES
Offline validator, not a full JSON Schema engine.
#>
[CmdletBinding()]param([string]$Path,[ValidateSet('completion-result','test-evidence','artifact-record','project-manifest','governance-config')][string]$Kind)
$r=[Collections.Generic.List[object]]::new();try{$j=Read-JsonFile $Path}catch{return @(New-ValidationResult Failed "Invalid JSON: $($_.Exception.Message)" $Path)};$statuses=@('Passed','Failed','NotRun','NotApplicable','Blocked');$risks=@('Low','Moderate','High','Critical')
$req=switch($Kind){'completion-result'{@('schemaVersion','repository','commitSha','branch','governanceVersion','riskClassification','status','startedAtUtc','completedAtUtc','summary','changedFiles','commandsExecuted','commandsNotExecuted','tests','artifacts','warnings','knownLimitations','remainingRisks','exceptions','approvals')}'test-evidence'{@('name','category','status','command','workingDirectory','startedAtUtc','completedAtUtc','durationSeconds','runtime','toolVersion')}'artifact-record'{@('path','sha256','artifactType','description')}'project-manifest'{@('schemaVersion','projectName','repository','description','governanceVersion','riskClassification','applicableStandards','owners','evidence','exceptions')}'governance-config'{@('schemaVersion','manifestPath','evidencePath','requiredDocumentationPaths','applicableAgentStandards','controls','exceptions')}}
foreach($n in $req){if(-not($j.PSObject.Properties.Name -contains $n)){$r.Add((New-ValidationResult Failed "Missing required property '$n'." $Path))}}
if(($j.PSObject.Properties.Name -contains 'status') -and $statuses -notcontains $j.status){$r.Add((New-ValidationResult Failed "Unknown status '$($j.status)'." $Path))}
if(($j.PSObject.Properties.Name -contains 'riskClassification') -and $risks -notcontains $j.riskClassification){$r.Add((New-ValidationResult Failed "Unknown risk '$($j.riskClassification)'." $Path))}
if($Kind -eq 'completion-result' -and $j.status -eq 'Passed'){foreach($t in @($j.tests)){if($t.status -in @('Failed','NotRun','Blocked')){$r.Add((New-ValidationResult Failed "Overall Passed conflicts with test '$($t.name)' status '$($t.status)'." $Path))}}}
if($Kind -eq 'artifact-record' -and $j.sha256 -notmatch '^[A-Fa-f0-9]{64}$'){$r.Add((New-ValidationResult Failed 'Artifact SHA-256 is invalid.' $Path))}
if($Kind -eq 'governance-config'){foreach($d in @($j.controls.mandatoryControlsDisabled)){if(-not $d.exceptionReference -or $d.exceptionReference -notmatch '^GOV-[A-Z0-9-]+$'){$r.Add((New-ValidationResult Failed "Mandatory control '$($d.control)' lacks valid exception." $Path))}}}
if($r.Count -eq 0){$r.Add((New-ValidationResult Passed "$Kind validation passed." $Path info))};@($r)}
function ConvertTo-OrderedJson {
<#
.SYNOPSIS
Serializes to JSON.
.DESCRIPTION
Uses depth suitable for evidence reports.
.PARAMETER InputObject
Input object.
.EXAMPLE
$report | ConvertTo-OrderedJson
.OUTPUTS
String
.NOTES
Use ordered hashtables for stable property order.
#>
[CmdletBinding()]param([Parameter(ValueFromPipeline)]$InputObject)process{$InputObject|ConvertTo-Json -Depth 100}}
