<#
.SYNOPSIS
Converts Pester NUnit XML into sanitized JSON evidence.
.DESCRIPTION
Parses a Pester NUnit XML result file and writes deterministic JSON test details
without runner, user-profile, repository-root, or temporary absolute paths.
.PARAMETER InputPath
Path to the Pester NUnit XML result file.
.PARAMETER OutputPath
Path to write sanitized JSON details.
.PARAMETER RepositoryPath
Repository root used to relativize paths.
.PARAMETER EvidenceRoot
Dedicated root that must contain both input XML and output JSON. Defaults to
RepositoryPath for backward compatibility with repository-local conversion.
.EXAMPLE
pwsh -File scripts/Convert-PesterResultToSanitizedJson.ps1 -InputPath tmp/pester.xml -OutputPath evidence/pester-details.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputPath,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$RepositoryPath = '.',
    [string]$EvidenceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $RepositoryPath).Path
$evidenceRootFull = if ($EvidenceRoot) { (Resolve-Path -LiteralPath $EvidenceRoot).Path } else { $root }
$inputFull = Resolve-SafePath -Root $evidenceRootFull -ChildPath $InputPath
$outputFull = Resolve-SafePath -Root $evidenceRootFull -ChildPath $OutputPath -AllowMissingLeaf

function ConvertTo-SanitizedText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    $value = $Text
    $rootSlash = $root.Replace('\','/')
    $rootEscaped = [regex]::Escape($root)
    $value = [regex]::Replace($value, $rootEscaped, '.')
    $value = $value.Replace($rootSlash, '.')
    $evidenceRootSlash = $evidenceRootFull.Replace('\','/')
    $evidenceRootEscaped = [regex]::Escape($evidenceRootFull)
    $value = [regex]::Replace($value, $evidenceRootEscaped, '<evidence-root>')
    $value = $value.Replace($evidenceRootSlash, '<evidence-root>')
    $value = [regex]::Replace($value, '/home/runner/work/[^/\s]+/[^/\s]+', '.')
    $value = [regex]::Replace($value, 'C:\\Users\\[^\\\s]+', '<user-profile>')
    $value = [regex]::Replace($value, '/tmp/[^\s<>"'']+', '<temp-path>')
    $value = [regex]::Replace($value, '(?i)(password|passwd|pwd|secret|api[_-]?key|token)\s*[:=]\s*\S+', '$1=[redacted]')
    $value
}

if (-not (Test-Path -LiteralPath $inputFull -PathType Leaf)) {
    throw "Pester result file '$InputPath' was not found."
}

try {
    [xml]$xml = Get-Content -LiteralPath $inputFull -Raw
}
catch {
    throw "Pester result file '$InputPath' is malformed XML: $($_.Exception.Message)"
}

$cases = @($xml.SelectNodes('//test-case'))
$details = foreach ($case in $cases) {
    $fullName = [string]$case.name
    $segments = @($fullName -split '\.' | Where-Object { $_ })
    $failure = $case.SelectSingleNode('failure')
    [ordered]@{
        describe = if ($segments.Count -ge 1) { ConvertTo-SanitizedText $segments[0] } else { $null }
        context = if ($segments.Count -ge 3) { ConvertTo-SanitizedText $segments[1] } else { $null }
        name = if ($segments.Count -ge 1) { ConvertTo-SanitizedText $segments[-1] } else { ConvertTo-SanitizedText $fullName }
        result = [string]$case.result
        durationSeconds = if ($case.time) { [math]::Round([double]$case.time, 3) } else { 0 }
        failureMessage = if ($failure) { ConvertTo-SanitizedText ([string]$failure.message) } else { $null }
        stackTrace = if ($failure) { ConvertTo-SanitizedText ([string]$failure.'stack-trace') } else { $null }
    }
}

$report = [ordered]@{
    schemaVersion = '1.0.0'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    source = 'Pester NUnit XML'
    total = @($details).Count
    passed = @($details | Where-Object result -in @('Success','Passed')).Count
    failed = @($details | Where-Object result -in @('Failure','Failed','Error')).Count
    skipped = @($details | Where-Object result -in @('Skipped','Ignored')).Count
    tests = @($details)
}

New-Item -ItemType Directory -Path (Split-Path -Parent $outputFull) -Force | Out-Null
$report | ConvertTo-OrderedJson | Set-Content -LiteralPath $outputFull -Encoding utf8
Write-Output "Sanitized Pester details written to $OutputPath"
