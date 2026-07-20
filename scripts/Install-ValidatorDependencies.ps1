<#
.SYNOPSIS
Installs hash-verified governance validator dependencies.
.DESCRIPTION
Installs PyYAML, Ruff, ShellCheck, Pester, and PSScriptAnalyzer from the reviewed dependency lock.
Online mode downloads exact package files into an isolated cache and verifies
their SHA-256 values before installation. Offline mode requires those files in
the cache. The script verifies declared runtime and module versions, writes
dependency provenance evidence, and generates a CycloneDX 1.5 SBOM. Missing
offline content or unavailable package sources are Blocked; hash mismatches and
invalid content are Failed.
.PARAMETER RepositoryPath
Trusted Engineering Standards checkout containing scripts and dependency locks.
.PARAMETER PackageCachePath
Isolated cache for the exact Python wheel and PowerShell NuGet packages.
.PARAMETER ModuleRoot
Isolated PowerShell module root for Pester and PSScriptAnalyzer.
.PARAMETER PythonPackageRoot
Isolated Python target directory for PyYAML and Ruff.
.PARAMETER ToolRoot
Isolated executable-tool directory for ShellCheck.
.PARAMETER EvidencePath
Dependency provenance JSON output path.
.PARAMETER SbomPath
CycloneDX JSON output path.
.PARAMETER RuntimeEvidencePath
Optional runtime-bootstrap evidence produced by Install-ValidatorRuntime.ps1.
.PARAMETER Offline
Disables network retrieval and requires every package in PackageCachePath.
.EXAMPLE
pwsh -NoProfile -File scripts/Install-ValidatorDependencies.ps1 -RepositoryPath . -PackageCachePath .cache -ModuleRoot .tmp/modules -PythonPackageRoot .tmp/python -EvidencePath evidence/dependencies.json -SbomPath evidence/validator-sbom.cdx.json -Offline
.NOTES
Run this script with the pinned PowerShell executable installed by
Install-ValidatorRuntime.ps1. Exit code 0 is Passed, 1 is Failed, and 3 is
Blocked.
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot),
    [string]$PackageCachePath,
    [string]$ModuleRoot,
    [string]$PythonPackageRoot,
    [string]$ToolRoot,
    [string]$EvidencePath,
    [string]$SbomPath,
    [string]$RuntimeEvidencePath,
    [switch]$Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ValidatorDependencyTools.psm1') -Force

$repositoryRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
$temporaryRoot = [System.IO.Path]::GetTempPath()
if ([string]::IsNullOrWhiteSpace($PackageCachePath)) { $PackageCachePath = Join-Path $temporaryRoot 'validator-package-cache' }
if ([string]::IsNullOrWhiteSpace($ModuleRoot)) { $ModuleRoot = Join-Path $temporaryRoot 'validator-psmodules' }
if ([string]::IsNullOrWhiteSpace($PythonPackageRoot)) { $PythonPackageRoot = Join-Path $temporaryRoot 'validator-python' }
if ([string]::IsNullOrWhiteSpace($ToolRoot)) { $ToolRoot = Join-Path $temporaryRoot 'validator-tools' }
if ([string]::IsNullOrWhiteSpace($EvidencePath)) { $EvidencePath = Join-Path $temporaryRoot 'dependencies.json' }
if ([string]::IsNullOrWhiteSpace($SbomPath)) { $SbomPath = Join-Path $temporaryRoot 'validator-sbom.cdx.json' }

$lockPath = Join-Path $repositoryRoot '.github/dependencies/validator-dependencies.psd1'
$requirementsPath = Join-Path $repositoryRoot '.github/dependencies/workflow-validation-requirements.txt'
$status = 'Failed'
$failureReason = $null
$blockedReason = $null
$exitCode = 1
$lock = $null
$packageEvidence = [System.Collections.Generic.List[object]]::new()
$runtimeInventory = @()

try {
    $lock = Import-ValidatorDependencyLock -Path $lockPath
    $lockResults = @(Test-ValidatorDependencyLock -Lock $lock -LockPath '.github/dependencies/validator-dependencies.psd1' -RequirementsPath $requirementsPath)
    $lockFailures = @($lockResults | Where-Object status -in @('Failed','Blocked'))
    if ($lockFailures.Count -gt 0) { throw "Dependency lock validation failed: $($lockFailures[0].message)" }

    $actualPowerShell = $PSVersionTable.PSVersion.ToString()
    Push-Location $repositoryRoot
    try {
        $actualPython = (& python --version 2>&1 | Out-String).Trim() -replace '^Python\s+',''
        if ($LASTEXITCODE -ne 0) { throw 'Pinned Python runtime is unavailable.' }
        $actualNode = (& node --version 2>&1 | Out-String).Trim() -replace '^v',''
        if ($LASTEXITCODE -ne 0) { throw 'Pinned Node runtime is unavailable.' }
        $actualDotNet = (& dotnet --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Pinned .NET runtime is unavailable.' }
    }
    finally { Pop-Location }
    $actualVersions = @{
        PowerShell=$actualPowerShell; Python=$actualPython; Node=$actualNode; DotNet=$actualDotNet
    }
    foreach ($runtimeName in @('PowerShell','Python','Node','DotNet')) {
        $expectedVersion = [string]$lock.Runtimes[$runtimeName].Version
        if ([string]$actualVersions[$runtimeName] -ne $expectedVersion) {
            throw "Runtime '$runtimeName' version mismatch; expected '$expectedVersion' but received '$($actualVersions[$runtimeName])'."
        }
    }

    New-Item -ItemType Directory -Path $PackageCachePath -Force | Out-Null
    foreach ($package in @($lock.Packages)) {
        $packagePath = Join-Path $PackageCachePath ([string]$package.PackageFile)
        if (Test-Path -LiteralPath $packagePath -PathType Leaf) { continue }
        if ($Offline) {
            $blockedReason = "Required cached package '$($package.PackageFile)' is unavailable in offline mode."
            throw "BLOCKED: $blockedReason"
        }
        if ([string]$package.Ecosystem -eq 'Python') {
            & python -m pip download --disable-pip-version-check --no-input --no-deps --only-binary=:all: --require-hashes --index-url ([string]$package.PackageIndexUri) --dest $PackageCachePath -r $requirementsPath
            if ($LASTEXITCODE -ne 0) {
                $blockedReason = 'The reviewed Python package source was unavailable or did not provide the locked artifact.'
                throw "BLOCKED: $blockedReason"
            }
        }
        else {
            $downloadPath = "$packagePath.download"
            try {
                Invoke-WebRequest -Uri ([string]$package.SourceUri) -OutFile $downloadPath -UseBasicParsing
            }
            catch {
                $blockedReason = "The reviewed source for '$($package.Name)' was unavailable."
                throw "BLOCKED: $blockedReason"
            }
            $downloadHash = Get-ValidatorFileSha256 -Path $downloadPath
            if ($downloadHash -ne [string]$package.Sha256) {
                Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
                throw "Downloaded package '$($package.PackageFile)' failed SHA-256 verification."
            }
            Move-Item -LiteralPath $downloadPath -Destination $packagePath
        }
    }

    $cacheResults = @(Test-ValidatorPackageCache -Lock $lock -PackageCachePath $PackageCachePath -Offline:$Offline)
    $cacheFailures = @($cacheResults | Where-Object status -in @('Failed','Blocked'))
    if ($cacheFailures.Count -gt 0) {
        if ($cacheFailures[0].status -eq 'Blocked') { throw "BLOCKED: $($cacheFailures[0].message)" }
        throw $cacheFailures[0].message
    }

    if (Test-Path -LiteralPath $PythonPackageRoot) { throw 'Python dependency target already exists; use a new isolated directory.' }
    New-Item -ItemType Directory -Path $PythonPackageRoot -Force | Out-Null
    & python -m pip install --disable-pip-version-check --no-input --no-deps --no-index --find-links $PackageCachePath --require-hashes --target $PythonPackageRoot -r $requirementsPath
    if ($LASTEXITCODE -ne 0) { throw 'Hash-verified Python validator package installation failed.' }
    $env:PYTHONPATH = $PythonPackageRoot
    $installedPyYaml = (& python -c 'import yaml; print(yaml.__version__)' 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $installedPyYaml -ne [string]$lock.Packages[0].Version) {
        throw 'Installed PyYAML version does not match the dependency lock.'
    }
    $ruffPackage=@($lock.Packages|Where-Object Name -eq 'Ruff')[0]
    $ruffPath=Join-Path $PythonPackageRoot 'bin/ruff'
    if(-not(Test-Path -LiteralPath $ruffPath -PathType Leaf)){throw 'Installed Ruff executable is missing.'}
    $ruffVersion=(& $ruffPath --version 2>&1|Out-String).Trim()
    if($LASTEXITCODE -ne 0 -or $ruffVersion -ne "ruff $($ruffPackage.Version)"){throw 'Installed Ruff version does not match the dependency lock.'}

    if(Test-Path -LiteralPath $ToolRoot){throw 'Executable tool target already exists; use a new isolated directory.'}
    $shellPackage=@($lock.Packages|Where-Object Name -eq 'ShellCheck')[0]
    $shellCheckPath=Expand-ValidatorExecutableArchive -PackagePath (Join-Path $PackageCachePath $shellPackage.PackageFile) -DestinationPath $ToolRoot -Version $shellPackage.Version
    $shellVersion=(& $shellCheckPath --version 2>&1|Out-String)
    if($LASTEXITCODE -ne 0 -or $shellVersion -notmatch "(?m)^version:\s+$([regex]::Escape($shellPackage.Version))$"){throw 'Installed ShellCheck version does not match the dependency lock.'}

    if (Test-Path -LiteralPath $ModuleRoot) { throw 'PowerShell dependency target already exists; use a new isolated directory.' }
    New-Item -ItemType Directory -Path $ModuleRoot -Force | Out-Null
    foreach ($package in @($lock.Packages | Where-Object Ecosystem -eq 'PowerShell')) {
        $modulePath = Join-Path $ModuleRoot (Join-Path ([string]$package.Name) ([string]$package.Version))
        Expand-ValidatorModulePackage -PackagePath (Join-Path $PackageCachePath ([string]$package.PackageFile)) -DestinationPath $modulePath
        $manifestPath = Join-Path $modulePath ([string]$package.ManifestPath)
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Package '$($package.Name)' did not contain its declared module manifest." }
        $manifest = Test-ModuleManifest -Path $manifestPath
        if ($manifest.Version.ToString() -ne [string]$package.Version) { throw "Package '$($package.Name)' manifest version does not match the dependency lock." }
        $module = Import-Module $manifestPath -Force -PassThru
        if (-not $module -or $module.Version.ToString() -ne [string]$package.Version) { throw "Package '$($package.Name)' could not be imported at the locked version." }
    }

    $env:PSModulePath = $ModuleRoot + [System.IO.Path]::PathSeparator + $env:PSModulePath
    if ($env:GITHUB_ENV) {
        "PSModulePath=$($env:PSModulePath)" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "PYTHONPATH=$PythonPackageRoot" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "VALIDATOR_PYTHON_PACKAGE_ROOT=$PythonPackageRoot" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "VALIDATOR_PYTHON_PATH=$((Get-Command python -CommandType Application).Source)" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "VALIDATOR_RUFF_PATH=$ruffPath" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "VALIDATOR_BASH_PATH=$((Get-Command bash -CommandType Application).Source)" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "VALIDATOR_SHELLCHECK_PATH=$shellCheckPath" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    }
    foreach ($package in @($lock.Packages)) {
        $packagePath = Join-Path $PackageCachePath ([string]$package.PackageFile)
        $packageEvidence.Add([ordered]@{
            name=[string]$package.Name; ecosystem=[string]$package.Ecosystem; installationKind=[string]$package.InstallationKind; version=[string]$package.Version
            source=[string]$package.SourceUri; packageFile=[string]$package.PackageFile
            expectedSha256=[string]$package.Sha256; actualSha256=Get-ValidatorFileSha256 -Path $packagePath
            verification='SHA-256 before installation'; installedVersion=if($package.Name -eq 'Ruff'){$ruffPackage.Version}elseif($package.Name -eq 'ShellCheck'){$shellPackage.Version}else{$package.Version}; status='Passed'; reason=$null
        })
    }
    $runtimeInventory = @(Get-ValidatorCommandInventory -Lock $lock -WorkingDirectory $repositoryRoot)
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
    if($lock){
        foreach($package in @($lock.Packages)){
            if(@($packageEvidence|Where-Object name -eq $package.Name).Count){continue}
            $candidate=Join-Path $PackageCachePath ([string]$package.PackageFile)
            $packageEvidence.Add([ordered]@{name=[string]$package.Name;ecosystem=[string]$package.Ecosystem;installationKind=[string]$package.InstallationKind;version=[string]$package.Version;source=[string]$package.SourceUri;packageFile=[string]$package.PackageFile;expectedSha256=[string]$package.Sha256;actualSha256=if(Test-Path -LiteralPath $candidate -PathType Leaf){Get-ValidatorFileSha256 $candidate}else{$null};verification='SHA-256 before installation';installedVersion=$null;status=$status;reason=if($blockedReason){$blockedReason}else{$failureReason}})
        }
    }
    if ($lock -and $runtimeInventory.Count -eq 0) {
        try { $runtimeInventory = @(Get-ValidatorCommandInventory -Lock $lock -WorkingDirectory $repositoryRoot) } catch { $runtimeInventory = @() }
    }
    $runtimeEvidence = $null
    if ($RuntimeEvidencePath -and (Test-Path -LiteralPath $RuntimeEvidencePath -PathType Leaf)) {
        try { $runtimeEvidence = Get-Content -LiteralPath $RuntimeEvidencePath -Raw | ConvertFrom-Json } catch { $runtimeEvidence = $null }
    }
    $evidence = [ordered]@{
        schemaVersion = '1.0.0'
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        status = $status
        mode = if($Offline){'Offline'}else{'OnlineWithVerifiedCache'}
        runner = [ordered]@{
            declaredLabel=if($lock){[string]$lock.Runner.Label}else{$null}
            observedOs=$env:ImageOS
            observedImageVersion=$env:ImageVersion
            architecture=[System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        }
        lock = [ordered]@{
            schemaVersion=if($lock){[string]$lock.SchemaVersion}else{$null}
            sha256=if(Test-Path -LiteralPath $lockPath -PathType Leaf){Get-ValidatorFileSha256 -Path $lockPath}else{$null}
            requirementsSha256=if(Test-Path -LiteralPath $requirementsPath -PathType Leaf){Get-ValidatorFileSha256 -Path $requirementsPath}else{$null}
        }
        runtimeBootstrap = $runtimeEvidence
        runtimes = @($runtimeInventory)
        packages = @($packageEvidence)
        sbom = 'validator-sbom.cdx.json'
        failureReason = $failureReason
        blockedReason = $blockedReason
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent ([System.IO.Path]::GetFullPath($EvidencePath))) -Force | Out-Null
    $evidence | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $EvidencePath -Encoding utf8
    if ($lock) {
        $sbom = New-ValidatorDependencySbom -Lock $lock -RuntimeInventory @($runtimeInventory) -SerialNumber ([guid]::NewGuid())
        New-Item -ItemType Directory -Path (Split-Path -Parent ([System.IO.Path]::GetFullPath($SbomPath))) -Force | Out-Null
        $sbom | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $SbomPath -Encoding utf8
    }
}

if ($status -eq 'Passed') { Write-Output 'Validator dependencies installed from hash-verified content and SBOM evidence generated.' }
elseif ($status -eq 'Blocked') { Write-Error $blockedReason -ErrorAction Continue }
else { Write-Error $failureReason -ErrorAction Continue }
exit $exitCode
