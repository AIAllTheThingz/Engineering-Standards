<#
.SYNOPSIS
Runs the governed Bash example with the standards-owned functional toolchain.
.DESCRIPTION
Installs exact hash-verified tools into an isolated root, runs the trusted Bash
driver, normalizes evidence, creates honest local completion evidence, and
copies only sanitized JSON records into the example evidence directory.
.PARAMETER ProjectPath
Governed Bash example root.
.PARAMETER ToolCache
Optional isolated artifact cache. Existing artifacts are always hash verified.
.PARAMETER Offline
Requires every locked artifact to already exist in ToolCache.
.EXAMPLE
pwsh -NoProfile -File tools/Test-Example.ps1
.INPUTS
None.
.OUTPUTS
Validation messages and JSON evidence files.
.NOTES
Requires Linux, GNU Bash 5.2, PowerShell 7, and Python 3.12.
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = (Join-Path $PSScriptRoot '..'),
    [string]$ToolCache,
    [switch]$Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsLinux) { throw 'The functional Bash example requires Linux with Ubuntu 24.04 semantics.' }
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$standardsRoot = (Resolve-Path -LiteralPath (Join-Path $project '../..')).Path
Import-Module (Join-Path $standardsRoot 'scripts/GovernanceValidation.psm1') -Force
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
$temporaryRoot = Join-Path $temporaryBase ("governed-bash-" + [guid]::NewGuid().ToString('N'))
$toolRoot = Join-Path $temporaryRoot 'tools'
$workRoot = Join-Path $temporaryRoot 'work'
$evidenceRoot = Join-Path $temporaryRoot 'hosted-evidence'
$completionRoot = Join-Path $temporaryRoot 'completion'
$cacheRoot = if ($ToolCache) { [IO.Path]::GetFullPath($ToolCache) } else { Join-Path $temporaryRoot 'cache' }
$pathsOutput = Join-Path $temporaryRoot 'tool-paths.json'
$bootstrapEvidence = Join-Path $temporaryRoot 'bash-toolchain-bootstrap.json'
$lockPath = Join-Path $project 'bash-toolchain.lock.json'

try {
    New-Item -ItemType Directory -Path $temporaryRoot,$cacheRoot -Force | Out-Null
    $installArguments = @(
        '-I', (Join-Path $standardsRoot 'scripts/Install-BashProjectToolchain.py'),
        '--lock', $lockPath,
        '--cache', $cacheRoot,
        '--tool-root', $toolRoot,
        '--evidence', $bootstrapEvidence,
        '--paths-output', $pathsOutput
    )
    if ($Offline) { $installArguments += '--offline' }
    & python3 @installArguments
    $installerExit = $LASTEXITCODE
    if ($installerExit -ne 0) {
        $destination = Join-Path $project 'evidence'
        foreach ($evidenceName in @(
            'bash-formatting.json',
            'bash-project-sbom.cdx.json',
            'bash-shellcheck.json',
            'bash-syntax.json',
            'bash-tests.json',
            'bash-toolchain-bootstrap.json',
            'bash-toolchain.json',
            'local-completion-result.json',
            'local-test-results.json'
        )) {
            $staleEvidence = Join-Path $destination $evidenceName
            if (Test-Path -LiteralPath $staleEvidence -PathType Leaf) {
                Remove-Item -LiteralPath $staleEvidence -Force
            }
        }
        if (-not (Test-Path -LiteralPath $bootstrapEvidence -PathType Leaf)) {
            throw "Bash toolchain installation failed with exit code $installerExit without producing bootstrap evidence."
        }
        $bootstrapValidation = @(Test-GovernanceJsonDocument -Path $bootstrapEvidence -Kind test-evidence)
        $bootstrapFailures = @($bootstrapValidation | Where-Object status -eq 'Failed')
        if ($bootstrapFailures.Count -gt 0) {
            throw "Bash toolchain installation failed with exit code $installerExit and produced invalid bootstrap evidence: $($bootstrapFailures[0].message)"
        }
        $bootstrapRecord = Get-Content -LiteralPath $bootstrapEvidence -Raw | ConvertFrom-Json -AsHashtable
        $expectedIdentity = [ordered]@{
            schemaVersion = '1.1.0'
            name = 'Bash functional toolchain bootstrap'
            category = 'dependency'
            requiredValidation = $true
            evidenceSource = 'Automated'
            toolName = 'bash-toolchain-bootstrap'
            toolVersion = '1.0.0'
        }
        foreach ($identityField in $expectedIdentity.Keys) {
            if (-not $bootstrapRecord.ContainsKey($identityField) -or $bootstrapRecord[$identityField] -cne $expectedIdentity[$identityField]) {
                throw "Bash toolchain installation failed with exit code $installerExit and produced bootstrap evidence with invalid $identityField."
            }
        }
        $bootstrapStatus = [string]$bootstrapRecord.status
        if ($bootstrapStatus -cnotin @('Blocked','Failed')) {
            throw "Bash toolchain installation failed with exit code $installerExit but bootstrap evidence reported '$bootstrapStatus'."
        }
        $reasonField = if ($bootstrapStatus -ceq 'Blocked') { 'blockedReason' } else { 'failureReason' }
        $reason = if ($bootstrapRecord.ContainsKey($reasonField)) { [string]$bootstrapRecord[$reasonField] } else { '' }
        if ([string]::IsNullOrWhiteSpace($reason) -or $reason.Length -lt 10) {
            throw "Bash toolchain installation failed with exit code $installerExit but bootstrap evidence omitted a meaningful $reasonField."
        }
        if (($bootstrapStatus -ceq 'Blocked' -and ($null -ne $bootstrapRecord.exitCode -or $null -ne $bootstrapRecord.failureReason)) -or
            ($bootstrapStatus -ceq 'Failed' -and ([int]$bootstrapRecord.exitCode -ne 1 -or $null -ne $bootstrapRecord.blockedReason))) {
            throw "Bash toolchain installation failed with exit code $installerExit but bootstrap evidence contradicted its $bootstrapStatus status."
        }
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        $publishedBootstrapEvidence = Join-Path $destination 'bash-toolchain-bootstrap.json'
        Copy-Item -LiteralPath $bootstrapEvidence -Destination $publishedBootstrapEvidence -Force
        throw "Bash toolchain installation failed with exit code $installerExit. $bootstrapStatus evidence was preserved: $reason"
    }
    $paths = Get-Content -LiteralPath $pathsOutput -Raw | ConvertFrom-Json

    & python3 -I (Join-Path $standardsRoot 'scripts/bash-project-validation.py') `
        --bash /usr/bin/bash `
        --shellcheck $paths.shellcheck `
        --shfmt $paths.shfmt `
        --bats $paths.bats `
        --caller-root $project `
        --project $project `
        --project-path-input . `
        --work-root $workRoot `
        --evidence-root $evidenceRoot `
        --tool-lock $lockPath
    $driverExit = $LASTEXITCODE
    Copy-Item -LiteralPath $bootstrapEvidence -Destination (Join-Path $evidenceRoot 'bash-toolchain-bootstrap.json')
    & python3 -I (Join-Path $standardsRoot 'scripts/Normalize-BashFunctionalEvidence.py') --evidence $evidenceRoot
    if ($LASTEXITCODE -ne 0) { throw 'Bash evidence normalization failed.' }

    New-Item -ItemType Directory -Path (Join-Path $completionRoot 'caller'),(Join-Path $completionRoot 'evidence') -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $workRoot 'caller') -Force | Copy-Item -Destination (Join-Path $completionRoot 'caller') -Recurse -Force
    Get-ChildItem -LiteralPath $evidenceRoot -File | Copy-Item -Destination (Join-Path $completionRoot 'evidence') -Force
    $artifacts = @(
        'evidence/bash-syntax.json',
        'evidence/bash-shellcheck.json',
        'evidence/bash-formatting.json',
        'evidence/bash-tests.json',
        'evidence/bash-toolchain.json',
        'evidence/bash-project-sbom.cdx.json'
    )
    & (Join-Path $standardsRoot 'scripts/New-CompletionEvidence.ps1') `
        -RepositoryPath $completionRoot `
        -SourceRepositoryPath (Join-Path $completionRoot 'caller') `
        -OutputPath 'evidence/local-completion-result.json' `
        -TestResultPath 'evidence/local-test-results.json' `
        -GovernanceVersion '1.1.0' `
        -RiskClassification Moderate `
        -Summary 'Local governed Bash syntax, ShellCheck, formatting, Bats, toolchain, and SBOM validation completed; hosted execution was not run.' `
        -CommandsExecuted @('Install-BashProjectToolchain.py','bash-project-validation.py','Normalize-BashFunctionalEvidence.py') `
        -ArtifactPath $artifacts `
        -Repository 'example-org/bash-project' `
        -Branch 'local' `
        -ValidatedCommitSha 'unknown'

    $destination = Join-Path $project 'evidence'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $completionRoot 'evidence') -File -Filter '*.json' | Copy-Item -Destination $destination -Force
    if ($driverExit -ne 0) { throw "Governed Bash validation failed with exit code $driverExit." }
}
finally {
    $resolvedTemporary = [IO.Path]::GetFullPath($temporaryRoot)
    if ($resolvedTemporary.StartsWith($temporaryBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal) -and (Test-Path -LiteralPath $resolvedTemporary)) {
        Remove-Item -LiteralPath $resolvedTemporary -Recurse -Force
    }
}
