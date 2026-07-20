Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ValidatorFileSha256 {
    <#
    .SYNOPSIS
    Calculates a lowercase SHA-256 digest for a file.
    .DESCRIPTION
    Returns the lowercase SHA-256 digest used by the validator dependency lock,
    package verification, runtime evidence, and SBOM generation.
    .PARAMETER Path
    Existing file to hash.
    .EXAMPLE
    Get-ValidatorFileSha256 -Path .github/dependencies/validator-dependencies.psd1
    .NOTES
    The function is read-only and throws when the file does not exist.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Cannot hash missing file '$Path'."
    }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Import-ValidatorDependencyLock {
    <#
    .SYNOPSIS
    Loads the validator dependency lock as inert PowerShell data.
    .DESCRIPTION
    Uses Import-PowerShellDataFile so the reviewed PSD1 lock is parsed as data
    instead of executed as a script. The returned hashtable is validated by
    Test-ValidatorDependencyLock before it is trusted for installation.
    .PARAMETER Path
    Path to validator-dependencies.psd1.
    .EXAMPLE
    Import-ValidatorDependencyLock -Path .github/dependencies/validator-dependencies.psd1
    .NOTES
    A missing or malformed lock is a blocking bootstrap error.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Validator dependency lock '$Path' is missing."
    }
    $lock = Import-PowerShellDataFile -LiteralPath $Path
    if ($lock -isnot [hashtable]) {
        throw 'Validator dependency lock root must be a hashtable.'
    }
    $lock
}

function New-ValidatorDependencyResult {
    <#
    .SYNOPSIS
    Creates one stable dependency-validation result.
    .DESCRIPTION
    Produces the common rule record used by lock and package-cache validation.
    .PARAMETER RuleId
    Stable validator dependency rule identifier.
    .PARAMETER Status
    Passed, Failed, or Blocked.
    .PARAMETER Message
    Sanitized operator-facing result message.
    .PARAMETER Path
    Repository-relative or package-file path associated with the result.
    .EXAMPLE
    New-ValidatorDependencyResult -RuleId DEP001 -Status Passed -Message 'Lock loaded.' -Path validator-dependencies.psd1
    .NOTES
    This helper does not write files or change process state.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RuleId,
        [Parameter(Mandatory)][ValidateSet('Passed','Failed','Blocked')][string]$Status,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$Path
    )

    [ordered]@{ ruleId=$RuleId; status=$Status; message=$Message; path=$Path }
}

function Test-ValidatorDependencyLock {
    <#
    .SYNOPSIS
    Validates the complete validator dependency lock and Python requirements.
    .DESCRIPTION
    Enforces the supported runner, exact runtime versions, immutable setup-action
    SHAs, HTTPS sources, unique packages, SHA-256 values, module manifest paths,
    and exact hash-locked PyYAML requirement used by workflow validation.
    .PARAMETER Lock
    Hashtable returned by Import-ValidatorDependencyLock.
    .PARAMETER LockPath
    Display path for lock-related findings.
    .PARAMETER RequirementsPath
    Path to workflow-validation-requirements.txt.
    .EXAMPLE
    Test-ValidatorDependencyLock -Lock $lock -LockPath $lockPath -RequirementsPath $requirementsPath
    .NOTES
    The function performs validation only and never downloads dependencies.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)][string]$LockPath,
        [Parameter(Mandatory)][string]$RequirementsPath
    )

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($name in @('SchemaVersion','Runner','Runtimes','Packages')) {
        if (-not $Lock.ContainsKey($name)) {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP001 -Status Failed -Message "Dependency lock is missing '$name'." -Path $LockPath))
        }
    }
    if ($results.Count -gt 0) { return @($results) }

    if ([string]$Lock.SchemaVersion -ne '1.0.0') {
        $results.Add((New-ValidatorDependencyResult -RuleId DEP002 -Status Failed -Message 'Dependency lock schemaVersion must be 1.0.0.' -Path $LockPath))
    }
    if ($Lock.Runner -isnot [hashtable] -or [string]$Lock.Runner.Label -ne 'ubuntu-24.04' -or [string]$Lock.Runner.Architecture -ne 'X64') {
        $results.Add((New-ValidatorDependencyResult -RuleId DEP003 -Status Failed -Message 'Runner must be pinned to ubuntu-24.04 on X64.' -Path $LockPath))
    }

    $expectedRuntimeKeys = @('PowerShell','Python','Node','DotNet')
    if ($Lock.Runtimes -isnot [hashtable]) {
        $results.Add((New-ValidatorDependencyResult -RuleId DEP004 -Status Failed -Message 'Runtimes must be a hashtable.' -Path $LockPath))
    }
    else {
        foreach ($runtimeName in $expectedRuntimeKeys) {
            if (-not $Lock.Runtimes.ContainsKey($runtimeName) -or $Lock.Runtimes[$runtimeName] -isnot [hashtable]) {
                $results.Add((New-ValidatorDependencyResult -RuleId DEP004 -Status Failed -Message "Runtime '$runtimeName' is missing or invalid." -Path $LockPath))
                continue
            }
            $runtime = $Lock.Runtimes[$runtimeName]
            if ([string]$runtime.Version -notmatch '^\d+\.\d+\.\d+$') {
                $results.Add((New-ValidatorDependencyResult -RuleId DEP004 -Status Failed -Message "Runtime '$runtimeName' must use an exact three-part version." -Path $LockPath))
            }
            if ($runtimeName -eq 'PowerShell') {
                if ([string]$runtime.SourceUri -notmatch '^https://github\.com/PowerShell/PowerShell/releases/download/' -or
                    [string]$runtime.Sha256 -notmatch '^[0-9a-f]{64}$' -or
                    [string]$runtime.PackageFile -notmatch '^powershell-[0-9.]+-linux-x64\.tar\.gz$') {
                    $results.Add((New-ValidatorDependencyResult -RuleId DEP005 -Status Failed -Message 'PowerShell runtime source, package name, or SHA-256 is invalid.' -Path $LockPath))
                }
            }
            elseif ([string]$runtime.SetupAction -notmatch '^actions/setup-(python|node|dotnet)$' -or [string]$runtime.ActionSha -notmatch '^[0-9a-f]{40}$') {
                $results.Add((New-ValidatorDependencyResult -RuleId DEP006 -Status Failed -Message "Runtime '$runtimeName' must use an official setup action pinned to a full SHA." -Path $LockPath))
            }
        }
    }

    $seen = @{}
    $packages = @($Lock.Packages)
    if ($packages.Count -lt 5) {
        $results.Add((New-ValidatorDependencyResult -RuleId DEP007 -Status Failed -Message 'PyYAML, Ruff, ShellCheck, Pester, and PSScriptAnalyzer must all be locked.' -Path $LockPath))
    }
    foreach ($package in $packages) {
        if ($package -isnot [hashtable]) {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP007 -Status Failed -Message 'Every package entry must be a hashtable.' -Path $LockPath))
            continue
        }
        $name = [string]$package.Name
        if ([string]::IsNullOrWhiteSpace($name) -or $seen.ContainsKey($name)) {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP007 -Status Failed -Message "Package name '$name' is empty or duplicated." -Path $LockPath))
        }
        else { $seen[$name] = $true }
        if ([string]$package.Version -notmatch '^\d+\.\d+\.\d+$' -or
            [string]$package.SourceUri -notmatch '^https://' -or
            [string]$package.Sha256 -notmatch '^[0-9a-f]{64}$' -or
            [string]$package.PackageFile -notmatch '^[A-Za-z0-9._-]+$' -or
            [string]$package.Purl -notmatch '^pkg:') {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP008 -Status Failed -Message "Package '$name' has invalid version, source, filename, SHA-256, or purl metadata." -Path $LockPath))
        }
        $allowedKind = @{ Python='PythonWheel'; PowerShell='PowerShellModule'; BinaryTool='TarXzExecutable' }
        if (-not $allowedKind.ContainsKey([string]$package.Ecosystem) -or [string]$package.InstallationKind -cne $allowedKind[[string]$package.Ecosystem]) {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP008 -Status Failed -Message "Package '$name' has invalid ecosystem or installation-kind metadata." -Path $LockPath))
        }
        if ([string]$package.Ecosystem -eq 'PowerShell' -and [string]$package.ManifestPath -notmatch '^[A-Za-z0-9._-]+\.psd1$') {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP009 -Status Failed -Message "PowerShell package '$name' must declare a root module manifest." -Path $LockPath))
        }
        if([string]$package.Ecosystem -eq 'Python' -and ([string]$package.SourceUri -notmatch '^https://files\.pythonhosted\.org/' -or [string]$package.PackageIndexUri -cne 'https://pypi.org/simple')){
            $results.Add((New-ValidatorDependencyResult -RuleId DEP009 -Status Failed -Message "Python package '$name' must declare its exact official artifact URL and approved package index." -Path $LockPath))
        }
    }
    foreach ($requiredName in @('PyYAML','Ruff','ShellCheck','Pester','PSScriptAnalyzer')) {
        if (-not $seen.ContainsKey($requiredName)) {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP007 -Status Failed -Message "Required package '$requiredName' is missing." -Path $LockPath))
        }
    }

    if (-not (Test-Path -LiteralPath $RequirementsPath -PathType Leaf)) {
        $results.Add((New-ValidatorDependencyResult -RuleId DEP010 -Status Failed -Message 'Hash-locked Python requirements file is missing.' -Path $RequirementsPath))
    }
    else {
        $lines = @(Get-Content -LiteralPath $RequirementsPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
        $pythonPackages = @($packages | Where-Object Ecosystem -eq 'Python')
        $expected = @('--only-binary=:all:') + @($pythonPackages | ForEach-Object { "$(if($_.Name -eq 'Ruff'){'ruff'}else{$_.Name})==$($_.Version) --hash=sha256:$($_.Sha256)" })
        if ($lines.Count -ne $expected.Count -or (Compare-Object -ReferenceObject $expected -DifferenceObject $lines -CaseSensitive)) {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP010 -Status Failed -Message 'Python requirements must allow only binary packages and exactly match the complete locked Python package set.' -Path $RequirementsPath))
        }
    }

    if (-not @($results | Where-Object status -in @('Failed','Blocked'))) {
        $results.Add((New-ValidatorDependencyResult -RuleId DEP000 -Status Passed -Message 'Validator dependency lock and hash-locked requirements are valid.' -Path $LockPath))
    }
    @($results)
}

function Test-ValidatorPackageCache {
    <#
    .SYNOPSIS
    Verifies cached validator packages against the dependency lock.
    .DESCRIPTION
    Reports missing packages as Blocked in offline mode and reports every hash
    mismatch as Failed. Online callers may use missing results to download the
    exact declared package before rerunning this check.
    .PARAMETER Lock
    Validated dependency lock.
    .PARAMETER PackageCachePath
    Directory containing package files named by the lock.
    .PARAMETER Offline
    Treat missing package files as a blocking unavailable-source condition.
    .EXAMPLE
    Test-ValidatorPackageCache -Lock $lock -PackageCachePath .cache -Offline
    .NOTES
    The function reads files only and never downloads or modifies packages.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)][string]$PackageCachePath,
        [switch]$Offline
    )

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($package in @($Lock.Packages)) {
        $fileName = [string]$package.PackageFile
        $packagePath = Join-Path $PackageCachePath $fileName
        if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
            $status = if ($Offline) { 'Blocked' } else { 'Failed' }
            $message = if ($Offline) { "Required cached package '$fileName' is unavailable in offline mode." } else { "Required package '$fileName' is missing from the cache." }
            $results.Add((New-ValidatorDependencyResult -RuleId DEP011 -Status $status -Message $message -Path $fileName))
            continue
        }
        $actualHash = Get-ValidatorFileSha256 -Path $packagePath
        if ($actualHash -ne [string]$package.Sha256) {
            $results.Add((New-ValidatorDependencyResult -RuleId DEP012 -Status Failed -Message "Package '$fileName' failed SHA-256 verification." -Path $fileName))
            continue
        }
        $results.Add((New-ValidatorDependencyResult -RuleId DEP013 -Status Passed -Message "Package '$fileName' matches its reviewed SHA-256." -Path $fileName))
    }
    @($results)
}

function Expand-ValidatorModulePackage {
    <#
    .SYNOPSIS
    Safely extracts a hash-verified PowerShell module package.
    .DESCRIPTION
    Rejects absolute paths and traversal before copying each ZIP entry into a
    new versioned module directory. The caller must verify the package hash
    before invoking this function.
    .PARAMETER PackagePath
    Verified NuGet package archive.
    .PARAMETER DestinationPath
    New directory that will contain extracted module files.
    .EXAMPLE
    Expand-ValidatorModulePackage -PackagePath Pester.5.7.1.nupkg -DestinationPath modules/Pester/5.7.1
    .NOTES
    Existing destination paths are rejected to prevent silent overwrite.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackagePath,
        [Parameter(Mandatory)][string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        throw "Module destination '$DestinationPath' already exists."
    }
    $destinationRoot = [System.IO.Path]::GetFullPath($DestinationPath)
    New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PackagePath).Path)
        try {
            foreach ($entry in $archive.Entries) {
                if ([string]::IsNullOrEmpty($entry.FullName)) { continue }
                $entryName = $entry.FullName.Replace('\','/')
                if ($entryName.StartsWith('/') -or $entryName -match '(^|/)\.\.(/|$)') {
                    throw "Package contains unsafe archive entry '$entryName'."
                }
                $target = [System.IO.Path]::GetFullPath((Join-Path $destinationRoot $entryName))
                $prefix = $destinationRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
                if (-not $target.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                    throw "Package archive entry '$entryName' escapes the module directory."
                }
                if ($entryName.EndsWith('/')) {
                    New-Item -ItemType Directory -Path $target -Force | Out-Null
                    continue
                }
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                $inputStream = $entry.Open()
                $outputStream = [System.IO.File]::Open($target, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try { $inputStream.CopyTo($outputStream) }
                finally { $outputStream.Dispose(); $inputStream.Dispose() }
            }
        }
        finally { $archive.Dispose() }
    }
    catch {
        Remove-Item -LiteralPath $destinationRoot -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Expand-ValidatorExecutableArchive {
    <#.SYNOPSIS Safely extracts the exact reviewed ShellCheck archive layout. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PackagePath,[Parameter(Mandatory)][string]$DestinationPath,[Parameter(Mandatory)][string]$Version)
    if(Test-Path -LiteralPath $DestinationPath){throw "Tool destination '$DestinationPath' already exists."}
    $tar=(Get-Command tar -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $names=@(& $tar -tf $PackagePath); if($LASTEXITCODE -ne 0){throw 'Executable archive inventory failed.'}
    $prefix="shellcheck-v$Version"; $expected=@("$prefix/LICENSE.txt","$prefix/README.txt","$prefix/shellcheck")
    if($names.Count -ne $expected.Count -or (Compare-Object $expected $names -CaseSensitive)){throw 'Executable archive has an unexpected layout or member set.'}
    foreach($name in $names){if([IO.Path]::IsPathRooted($name) -or $name -match '(^|/)\.\.(/|$)'){throw "Executable archive contains unsafe member '$name'."}}
    $listing=@(& $tar -tvf $PackagePath); if($LASTEXITCODE -ne 0 -or @($listing|Where-Object{$_ -notmatch '^[-d]'}).Count){throw 'Executable archive contains an unsafe link or member type.'}
    New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    try{& $tar -xf $PackagePath -C $DestinationPath --no-same-owner --no-same-permissions; if($LASTEXITCODE -ne 0){throw 'Executable archive extraction failed.'}}catch{Remove-Item -LiteralPath $DestinationPath -Recurse -Force -ErrorAction SilentlyContinue;throw}
    $executable=Join-Path $DestinationPath "$prefix/shellcheck"; if(-not(Test-Path -LiteralPath $executable -PathType Leaf)){throw 'ShellCheck executable is missing after extraction.'}; $executable
}

function Get-ValidatorCommandInventory {
    <#
    .SYNOPSIS
    Records actual validator runtime versions and executable hashes.
    .DESCRIPTION
    Queries PowerShell, Python, Node, npm, .NET, and Git without exposing
    absolute executable paths. Missing commands remain explicit in evidence.
    .PARAMETER Lock
    Validated dependency lock providing declared runtime versions.
    .PARAMETER WorkingDirectory
    Optional directory used for version selection files such as global.json.
    .EXAMPLE
    Get-ValidatorCommandInventory -Lock $lock -WorkingDirectory .
    .NOTES
    Command output is reduced to version strings and executable SHA-256 values.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [string]$WorkingDirectory
    )

    $definitions = @(
        @{ Name='PowerShell'; Command='pwsh'; Declared=[string]$Lock.Runtimes.PowerShell.Version; Args=@('-NoProfile','-Command','$PSVersionTable.PSVersion.ToString()') },
        @{ Name='Python'; Command='python'; Declared=[string]$Lock.Runtimes.Python.Version; Args=@('--version') },
        @{ Name='Node'; Command='node'; Declared=[string]$Lock.Runtimes.Node.Version; Args=@('--version') },
        @{ Name='npm'; Command='npm'; Declared=$null; Args=@('--version') },
        @{ Name='DotNet'; Command='dotnet'; Declared=[string]$Lock.Runtimes.DotNet.Version; Args=@('--version') },
        @{ Name='Git'; Command='git'; Declared=$null; Args=@('--version') },
        @{ Name='Bash'; Command=if($env:VALIDATOR_BASH_PATH){$env:VALIDATOR_BASH_PATH}else{'bash'}; Declared='>=4.0'; Args=@('--version') },
        @{ Name='Ruff'; Command=if($env:VALIDATOR_RUFF_PATH){$env:VALIDATOR_RUFF_PATH}else{'__trusted_ruff_unavailable__'}; Declared=[string](@($Lock.Packages|Where-Object Name -eq 'Ruff')[0].Version); Args=@('--version') },
        @{ Name='ShellCheck'; Command=if($env:VALIDATOR_SHELLCHECK_PATH){$env:VALIDATOR_SHELLCHECK_PATH}else{'__trusted_shellcheck_unavailable__'}; Declared=[string](@($Lock.Packages|Where-Object Name -eq 'ShellCheck')[0].Version); Args=@('--version') }
    )
    if ($WorkingDirectory) { Push-Location $WorkingDirectory }
    try {
        foreach ($definition in $definitions) {
            $command = Get-Command $definition.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $command) {
                [ordered]@{ name=$definition.Name; declaredVersion=$definition.Declared; actualVersion=$null; executableSha256=$null; status='NotRun' }
                continue
            }
            $versionOutput = (& $command.Source @($definition.Args) 2>&1 | Out-String).Trim()
            $versionExitCode = $LASTEXITCODE
            $normalizedVersion = switch($definition.Name){
                'Ruff' { $versionOutput -replace '^ruff\s+',''; break }
                'ShellCheck' { if($versionOutput -match '(?m)^version:\s+(\S+)'){ $Matches[1] }else{$versionOutput}; break }
                'Bash' { if($versionOutput -match 'version\s+(\d+\.\d+\.\d+)'){ $Matches[1] }else{$versionOutput}; break }
                default { $versionOutput -replace '^(Python|v|git version)\s*','' }
            }
            $versionMatches = if($definition.Name -eq 'Bash'){ $normalizedVersion -match '^\d+\.' -and [int]($normalizedVersion.Split('.')[0]) -ge 4 }elseif($definition.Declared){$normalizedVersion -eq $definition.Declared}else{$true}
            [ordered]@{
                name = $definition.Name
                declaredVersion = $definition.Declared
                actualVersion = $normalizedVersion
                executableSha256 = Get-ValidatorFileSha256 -Path $command.Source
                status = if ($versionExitCode -eq 0 -and $versionMatches) { 'Passed' } else { 'Failed' }
            }
        }
    }
    finally { if ($WorkingDirectory) { Pop-Location } }
}

function New-ValidatorDependencySbom {
    <#
    .SYNOPSIS
    Generates a CycloneDX dependency inventory for validator tooling.
    .DESCRIPTION
    Creates a deterministic CycloneDX 1.5 JSON object from declared packages,
    actual runtime inventory, verified hashes, and explicit source references.
    .PARAMETER Lock
    Validated dependency lock.
    .PARAMETER RuntimeInventory
    Actual runtime records from Get-ValidatorCommandInventory.
    .PARAMETER SerialNumber
    UUID used for the SBOM serial number.
    .EXAMPLE
    New-ValidatorDependencySbom -Lock $lock -RuntimeInventory $inventory -SerialNumber ([guid]::NewGuid())
    .NOTES
    The caller writes the returned object to its evidence directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Lock,
        [Parameter(Mandatory)][object[]]$RuntimeInventory,
        [Parameter(Mandatory)][guid]$SerialNumber
    )

    $components = [System.Collections.Generic.List[object]]::new()
    foreach ($runtime in @($RuntimeInventory | Where-Object declaredVersion)) {
        $components.Add([ordered]@{
            type='application'; name=[string]$runtime.name; version=[string]$runtime.actualVersion
            hashes=if ($runtime.executableSha256) { @([ordered]@{ alg='SHA-256'; content=[string]$runtime.executableSha256 }) } else { @() }
            properties=@([ordered]@{ name='engineering-standards:declared-version'; value=[string]$runtime.declaredVersion })
        })
    }
    foreach ($package in @($Lock.Packages)) {
        $components.Add([ordered]@{
            type=if($package.Ecosystem -eq 'BinaryTool'){'application'}else{'library'}; name=[string]$package.Name; version=[string]$package.Version; purl=[string]$package.Purl
            hashes=@([ordered]@{ alg='SHA-256'; content=[string]$package.Sha256 })
            externalReferences=@([ordered]@{ type='distribution'; url=[string]$package.SourceUri })
        })
    }
    [ordered]@{
        bomFormat='CycloneDX'; specVersion='1.5'; serialNumber="urn:uuid:$SerialNumber"; version=1
        metadata=[ordered]@{ timestamp=(Get-Date).ToUniversalTime().ToString('o'); tools=@([ordered]@{ vendor='AIAllTheThingz'; name='Engineering Standards validator dependency installer'; version='1.0.0' }) }
        components=@($components)
    }
}

Export-ModuleMember -Function @(
    'Get-ValidatorFileSha256',
    'Import-ValidatorDependencyLock',
    'Test-ValidatorDependencyLock',
    'Test-ValidatorPackageCache',
    'Expand-ValidatorModulePackage',
    'Expand-ValidatorExecutableArchive',
    'Get-ValidatorCommandInventory',
    'New-ValidatorDependencySbom'
)
