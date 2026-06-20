<#
.SYNOPSIS
Runs a command and writes a test-evidence record with real timing.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][ValidateSet('unit','integration','security','build','lint','schema','workflow','documentation','manual','other')][string]$Category,
    [Parameter(Mandatory)][string]$Command,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$WorkingDirectory = '.',
    [string]$Runtime = 'Local PowerShell validation',
    [string]$ToolVersion = $PSVersionTable.PSVersion.ToString(),
    [switch]$Append
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$root = (Get-Location).Path
$started = (Get-Date).ToUniversalTime()
$failure = $null
$exitCode = 0
Push-Location $WorkingDirectory
try {
    $global:LASTEXITCODE = 0
    Invoke-Expression $Command
    $succeeded = $?
    if ($null -ne $global:LASTEXITCODE -and [int]$global:LASTEXITCODE -ne 0) {
        $exitCode = [int]$global:LASTEXITCODE
    }
    elseif (-not $succeeded) {
        $exitCode = 1
    }
}
catch {
    $failure = $_.Exception.Message
    $exitCode = 1
}
finally {
    Pop-Location
}
$completed = (Get-Date).ToUniversalTime()
$status = if ($exitCode -eq 0 -and -not $failure) { 'Passed' } else { 'Failed' }
$record = [ordered]@{
    schemaVersion = '1.0.0'
    name = $Name
    category = $Category
    status = $status
    command = $Command
    workingDirectory = if ($WorkingDirectory -eq '.') { '.' } else { [System.IO.Path]::GetRelativePath($root, (Resolve-Path $WorkingDirectory).Path).Replace('\','/') }
    startedAtUtc = $started.ToString('o')
    completedAtUtc = $completed.ToString('o')
    durationSeconds = [math]::Round(($completed - $started).TotalSeconds, 3)
    runtime = $Runtime
    toolVersion = $ToolVersion
    exitCode = $exitCode
    summary = if ($status -eq 'Passed') { "$Name completed successfully." } else { "$Name failed." }
    warnings = @()
    failureReason = if ($status -eq 'Passed') { $null } elseif ($failure) { $failure } else { "$Name exited with code $exitCode." }
}

$records = @()
if ($Append -and (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
    $records = @(Get-Content -LiteralPath $OutputPath -Raw | ConvertFrom-Json)
}
$records += $record
$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$records | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $OutputPath -Encoding utf8
if ($exitCode -ne 0) { exit $exitCode }
