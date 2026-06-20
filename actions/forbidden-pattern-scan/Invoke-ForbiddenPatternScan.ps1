<#
.SYNOPSIS
Runs defensive forbidden-pattern scanning.
.DESCRIPTION
Applies configured regex patterns to repository text files, supports reviewed expiring allowlists, redacts matches, skips binary or large files, and emits structured JSON reports.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$PatternFile,
    [string]$AllowlistFile,
    [string]$OutputJson,
    [switch]$Advisory,
    [switch]$IncludeGeneratedEvidence,
    [switch]$ExcludeTestFixtures
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$defaultPatternFile = Join-Path $PSScriptRoot 'forbidden-patterns.json'
$patternPath = if ($PatternFile) { Resolve-SafePath -Root $root -ChildPath $PatternFile } elseif (Test-Path -LiteralPath $defaultPatternFile) { $defaultPatternFile } else { throw 'Pattern file missing.' }
$allowlistPath = $null
if ($AllowlistFile) { $allowlistPath = Resolve-SafePath -Root $root -ChildPath $AllowlistFile }

$patternDocument = Read-JsonFile -Path $patternPath
$patterns = @($patternDocument.patterns)
$allowlist = @()
if ($allowlistPath -and (Test-Path -LiteralPath $allowlistPath -PathType Leaf)) {
    $allowlist = @((Read-JsonFile -Path $allowlistPath).entries)
}

$findings = [System.Collections.Generic.List[object]]::new()
$skipped = [System.Collections.Generic.List[object]]::new()
$scanned = 0
$maxBytes = 1048576
$excludedPathPattern = '(^|/)(\.git|\.tmp|node_modules|packages|bin|obj|dist|TestResults|coverage)(/|$)'
if (-not $IncludeGeneratedEvidence) {
    $excludedPathPattern = $excludedPathPattern + '|^evidence/'
}

function Test-AllowlistedFinding {
    param(
        [Parameter(Mandatory)][object]$Pattern,
        [Parameter(Mandatory)][string]$RelativePath
    )
    foreach ($entry in $allowlist) {
        if ($entry.patternId -ne $Pattern.id) { continue }
        if (-not $entry.reason -or $entry.reason.Length -lt 10) { continue }
        if ($entry.expiresOn) {
            try {
                if ([datetime]$entry.expiresOn -lt (Get-Date).Date) { continue }
            }
            catch {
                continue
            }
        }
        if ($RelativePath -like $entry.path) { return $true }
    }
    $false
}

function Get-RedactedSnippet {
    param([Parameter(Mandatory)][string]$Value)
    if ($Value.Length -le 12) { return '[redacted]' }
    $Value.Substring(0, 4) + '...[redacted]...' + $Value.Substring($Value.Length - 4)
}

foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File) {
    $relative = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
    if ($relative -eq 'actions/forbidden-pattern-scan/forbidden-patterns.json') { continue }
    if ($OutputJson -and $relative -eq $OutputJson.Replace('\','/')) {
        $skipped.Add([ordered]@{ path = $relative; reason = 'scanner-output' })
        continue
    }
    if ($ExcludeTestFixtures -and $relative -match '(^|/)(tests|test|fixtures)(/|$)') {
        $skipped.Add([ordered]@{ path = $relative; reason = 'test-fixture-excluded' })
        continue
    }
    if ($relative -match $excludedPathPattern) {
        $skipped.Add([ordered]@{ path = $relative; reason = 'excluded-path' })
        continue
    }
    if ($file.Length -gt $maxBytes) {
        $skipped.Add([ordered]@{ path = $relative; reason = 'too-large'; sizeBytes = $file.Length })
        continue
    }

    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
    }
    catch {
        $skipped.Add([ordered]@{ path = $relative; reason = 'unreadable' })
        continue
    }
    if ($content -match "`0") {
        $skipped.Add([ordered]@{ path = $relative; reason = 'binary' })
        continue
    }

    $scanned++
    foreach ($pattern in $patterns) {
        try {
            $matches = [regex]::Matches($content, [string]$pattern.regex)
        }
        catch {
            $findings.Add([ordered]@{
                patternId = $pattern.id
                severity = 'error'
                path = $relative
                line = 0
                description = "Invalid scanner regex for pattern '$($pattern.id)'."
                redactedMatch = '[invalid-regex]'
                allowlisted = $false
            })
            continue
        }
        foreach ($match in $matches) {
            $allowlisted = Test-AllowlistedFinding -Pattern $pattern -RelativePath $relative
            if ($allowlisted) { continue }
            $prefix = $content.Substring(0, $match.Index)
            $line = ([regex]::Matches($prefix, "`n")).Count + 1
            $findings.Add([ordered]@{
                patternId = $pattern.id
                severity = $pattern.severity
                path = $relative
                line = $line
                description = $pattern.description
                redactedMatch = Get-RedactedSnippet -Value $match.Value
                allowlisted = $false
            })
        }
    }
}

$errorCount = @($findings | Where-Object severity -eq 'error').Count
$warningCount = @($findings | Where-Object severity -eq 'warning').Count
$report = [ordered]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    scanner = 'forbidden-pattern-scan'
    schemaVersion = '1.0.0'
    completeSecretScanner = $false
    root = '.'
    patternFile = [System.IO.Path]::GetRelativePath($root, $patternPath).Replace('\','/')
    allowlistFile = $(if ($allowlistPath) { [System.IO.Path]::GetRelativePath($root, $allowlistPath).Replace('\','/') } else { $null })
    advisory = [bool]$Advisory
    scannedFiles = $scanned
    skippedFiles = @($skipped)
    findings = @($findings)
    failed = $errorCount
    warnings = $warningCount
}

if ($OutputJson) {
    $outPath = Resolve-SafePath -Root $root -ChildPath $OutputJson -AllowMissingLeaf
    New-Item -ItemType Directory -Path (Split-Path -Parent $outPath) -Force | Out-Null
    $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $outPath -Encoding utf8
}

if ($findings.Count) {
    $findings | ForEach-Object { "[$($_.severity)] $($_.path):$($_.line) $($_.patternId): $($_.redactedMatch)" }
}
else {
    Write-Output '[Passed] No forbidden-pattern findings.'
}

if ($errorCount -gt 0 -and -not $Advisory) { exit 1 }
exit 0
