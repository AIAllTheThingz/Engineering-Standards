<#
.SYNOPSIS
Installs the hash-verified PowerShell runtime used by governance validation.
.DESCRIPTION
Loads the reviewed validator dependency lock, obtains the exact PowerShell
Linux x64 archive from either a pre-populated package cache or its declared
GitHub release URL, verifies SHA-256 before extraction, rejects unsafe archive
paths, verifies the installed runtime version, and exposes the runtime to later
GitHub Actions steps. Missing offline content or an unavailable remote source is
Blocked; malformed or hash-mismatched content is Failed.
.PARAMETER RepositoryPath
Trusted Engineering Standards checkout containing the dependency lock.
.PARAMETER PackageCachePath
Cache directory containing the exact PowerShell archive for offline execution.
.PARAMETER InstallRoot
New directory in which the pinned PowerShell runtime will be extracted.
.PARAMETER EvidencePath
JSON evidence output path.
.PARAMETER Offline
Disables network retrieval and requires the archive in PackageCachePath.
.EXAMPLE
pwsh -NoProfile -File scripts/Install-ValidatorRuntime.ps1 -RepositoryPath . -PackageCachePath .cache -InstallRoot .tmp/pwsh -EvidencePath evidence/runtime-bootstrap.json -Offline
.NOTES
The script supports Ubuntu Linux x64 only because that is the locked hosted
runner strategy. Exit code 0 is Passed, 1 is Failed, and 3 is Blocked.
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
    [string]$PackageCachePath,
    [string]$InstallRoot,
    [string]$EvidencePath,
    [switch]$Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ValidatorDependencyTools.psm1') -Force

$repositoryRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
if ([string]::IsNullOrWhiteSpace($PackageCachePath)) { $PackageCachePath = Join-Path ([System.IO.Path]::GetTempPath()) 'validator-runtime-cache' }
if ([string]::IsNullOrWhiteSpace($InstallRoot)) { $InstallRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'validator-pwsh' }
if ([string]::IsNullOrWhiteSpace($EvidencePath)) { $EvidencePath = Join-Path ([System.IO.Path]::GetTempPath()) 'runtime-bootstrap.json' }

$status = 'Failed'
$failureReason = $null
$blockedReason = $null
$actualHash = $null
$actualVersion = $null
$exitCode = 1
$sourceMode = if ($Offline) { 'OfflineCache' } else { 'ReviewedRemoteOrCache' }
$lockPath = Join-Path $repositoryRoot '.github/dependencies/validator-dependencies.psd1'
$requirementsPath = Join-Path $repositoryRoot '.github/dependencies/workflow-validation-requirements.txt'
$lock = $null

try {
    $lock = Import-ValidatorDependencyLock -Path $lockPath
    $lockResults = @(Test-ValidatorDependencyLock -Lock $lock -LockPath '.github/dependencies/validator-dependencies.psd1' -RequirementsPath $requirementsPath)
    $lockFailures = @($lockResults | Where-Object status -in @('Failed','Blocked'))
    if ($lockFailures.Count -gt 0) { throw "Dependency lock validation failed: $($lockFailures[0].message)" }
    if (-not $IsLinux -or [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne [string]$lock.Runner.Architecture) {
        throw "Pinned validator runtime requires Linux $($lock.Runner.Architecture)."
    }

    $runtime = $lock.Runtimes.PowerShell
    New-Item -ItemType Directory -Path $PackageCachePath -Force | Out-Null
    $packagePath = Join-Path $PackageCachePath ([string]$runtime.PackageFile)
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        if ($Offline) {
            $blockedReason = "Pinned PowerShell archive '$($runtime.PackageFile)' is unavailable in offline mode."
            throw "BLOCKED: $blockedReason"
        }
        $downloadPath = "$packagePath.download"
        try {
            Invoke-WebRequest -Uri ([string]$runtime.SourceUri) -OutFile $downloadPath -UseBasicParsing
        }
        catch {
            $blockedReason = 'The reviewed PowerShell release source was unavailable.'
            throw "BLOCKED: $blockedReason"
        }
        $downloadHash = Get-ValidatorFileSha256 -Path $downloadPath
        if ($downloadHash -ne [string]$runtime.Sha256) {
            Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
            throw 'Downloaded PowerShell archive failed SHA-256 verification.'
        }
        Move-Item -LiteralPath $downloadPath -Destination $packagePath
    }

    $actualHash = Get-ValidatorFileSha256 -Path $packagePath
    if ($actualHash -ne [string]$runtime.Sha256) {
        throw 'Cached PowerShell archive failed SHA-256 verification.'
    }
    if (Test-Path -LiteralPath $InstallRoot) {
        throw 'Pinned PowerShell install destination already exists; use a new isolated directory.'
    }
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    $entries = @(& tar -tzf $packagePath 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Pinned PowerShell archive could not be enumerated.' }
    foreach ($entry in $entries) {
        $normalized = ([string]$entry).Replace('\','/')
        if ($normalized.StartsWith('/') -or $normalized -match '(^|/)\.\.(/|$)') {
            throw 'Pinned PowerShell archive contains an unsafe path.'
        }
    }
    & tar -xzf $packagePath -C $InstallRoot
    if ($LASTEXITCODE -ne 0) { throw 'Pinned PowerShell archive extraction failed.' }

    $pinnedPowerShell = Join-Path $InstallRoot 'pwsh'
    if (-not (Test-Path -LiteralPath $pinnedPowerShell -PathType Leaf)) { throw 'Pinned PowerShell executable is missing after extraction.' }
    if (-not (Get-Item -LiteralPath $pinnedPowerShell).UnixFileMode.HasFlag([System.IO.UnixFileMode]::UserExecute)) {
        & chmod u+x $pinnedPowerShell
        if ($LASTEXITCODE -ne 0) { throw 'Pinned PowerShell executable permission could not be set.' }
    }
    $actualVersion = (& $pinnedPowerShell -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $actualVersion -ne [string]$runtime.Version) {
        throw "Pinned PowerShell version verification failed; expected '$($runtime.Version)'."
    }

    if ($env:GITHUB_PATH) { $InstallRoot | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append }
    if ($env:GITHUB_ENV) {
        "VALIDATOR_PWSH=$pinnedPowerShell" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "VALIDATOR_RUNTIME_EVIDENCE=$EvidencePath" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    }
    $status = 'Passed'
    $exitCode = 0
}
catch {
    $message = $_.Exception.Message
    if ($message.StartsWith('BLOCKED: ')) {
        $status = 'Blocked'
        $blockedReason = $message.Substring(9)
        $exitCode = 3
    }
    else {
        $status = 'Failed'
        $failureReason = $message
        $exitCode = 1
    }
}
finally {
    $runtimeRecord = if ($lock -and $lock.Runtimes -and $lock.Runtimes.PowerShell) { $lock.Runtimes.PowerShell } else { @{} }
    $evidence = [ordered]@{
        schemaVersion = '1.0.0'
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        status = $status
        sourceMode = $sourceMode
        runner = [ordered]@{ declaredLabel=if($lock){[string]$lock.Runner.Label}else{$null}; observedOs=$env:ImageOS; observedImageVersion=$env:ImageVersion; architecture=[System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() }
        runtime = [ordered]@{
            name = 'PowerShell'
            declaredVersion = if($runtimeRecord.Version){[string]$runtimeRecord.Version}else{$null}
            actualVersion = $actualVersion
            source = if($runtimeRecord.SourceUri){[string]$runtimeRecord.SourceUri}else{$null}
            packageFile = if($runtimeRecord.PackageFile){[string]$runtimeRecord.PackageFile}else{$null}
            expectedSha256 = if($runtimeRecord.Sha256){[string]$runtimeRecord.Sha256}else{$null}
            actualSha256 = $actualHash
        }
        lockSha256 = if (Test-Path -LiteralPath $lockPath -PathType Leaf) { Get-ValidatorFileSha256 -Path $lockPath } else { $null }
        failureReason = $failureReason
        blockedReason = $blockedReason
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent ([System.IO.Path]::GetFullPath($EvidencePath))) -Force | Out-Null
    $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $EvidencePath -Encoding utf8
}

if ($status -eq 'Passed') { Write-Output "Pinned PowerShell $actualVersion installed from hash-verified content." }
elseif ($status -eq 'Blocked') { Write-Error $blockedReason -ErrorAction Continue }
else { Write-Error $failureReason -ErrorAction Continue }
exit $exitCode
