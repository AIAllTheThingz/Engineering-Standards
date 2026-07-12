<#
.SYNOPSIS
Runs trusted governance validation against an explicit repository workspace.
.DESCRIPTION
Executes validators from this Engineering Standards checkout while treating the
caller repository as untrusted data. The caller, standards, and evidence roots
are resolved independently and must not overlap. Downstream validation is
selected from a validated manifest and governance configuration; maintainer-only
tests and examples run only for the Engineering Standards repository itself.
.PARAMETER Path
Root of the checked-out caller repository.
.PARAMETER ProjectPath
Repository-relative project path beneath Path. Absolute paths, traversal, and
symbolic-link or junction escapes are rejected.
.PARAMETER EvidenceRoot
Dedicated directory for generated validation evidence. It must be outside both
the caller and standards workspaces.
.PARAMETER OutputJson
Optional backward-compatible local report path. Reusable workflows use the
dedicated EvidenceRoot report instead.
.PARAMETER Category
Optional local-only category override. Reusable-workflow callers use the
validated governance.config.json categories instead.
.PARAMETER ExpectedGovernanceVersion
Governance version required by the reusable-workflow interface.
.PARAMETER CallerRepository
GitHub owner/name of the caller repository.
.PARAMETER CallerCommitSha
Immutable caller commit being validated.
.PARAMETER StandardsRepository
GitHub owner/name that supplied the reusable workflow.
.PARAMETER StandardsWorkflowSha
Immutable commit containing the reusable workflow and validators.
.PARAMETER ControlledFailure
Adds an intentional final failed check after normal validation so evidence can
be generated and uploaded before enforcement fails.
.EXAMPLE
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path .
.OUTPUTS
Console results and governance-validation.json in EvidenceRoot.
.NOTES
No scripts, tests, examples, or modules are loaded from the caller repository.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$ProjectPath = '.',
    [string]$EvidenceRoot,
    [string]$OutputJson,
    [ValidateSet('Contract','JsonSchemas','YamlSyntax','WorkflowArchitecture','MarkdownLinks','DocumentationCompleteness','ForbiddenPatterns','RepositoryHealth','Evidence','Examples','Pester','PSScriptAnalyzer','PowerShellParser')]
    [string[]]$Category,
    [string]$ExpectedGovernanceVersion,
    [string]$CallerRepository,
    [string]$CallerCommitSha,
    [string]$StandardsRepository = 'AIAllTheThingz/Engineering-Standards',
    [string]$StandardsWorkflowSha,
    [switch]$ControlledFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$standardsRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$workflowWorkspaceRoot = Split-Path -Parent $standardsRoot
$temporaryRoot = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
Import-Module (Join-Path $standardsRoot 'scripts/GovernanceValidation.psm1') -Force

function Test-PathWithinRoot {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Candidate,
        [switch]$AllowRoot
    )

    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $candidateFull = [System.IO.Path]::GetFullPath($Candidate)
    $boundary = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    ($AllowRoot -and $candidateFull.Equals($rootFull, $comparison)) -or $candidateFull.StartsWith($boundary, $comparison)
}

function Assert-NoLinkTraversal {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Candidate
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $candidateFull = [System.IO.Path]::GetFullPath($Candidate)
    $relative = [System.IO.Path]::GetRelativePath($rootFull, $candidateFull)
    $current = $rootFull
    foreach ($segment in @($relative -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) { break }
        $item = Get-Item -LiteralPath $current -Force
        if ($item.LinkType -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            throw "Path '$ProjectPath' traverses symbolic link or junction '$current'."
        }
    }
}

function Assert-NoNestedLinks {
    param([Parameter(Mandatory)][string]$Root)

    foreach ($item in Get-ChildItem -LiteralPath $Root -Recurse -Force -ErrorAction Stop) {
        if ($item.LinkType -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            $relative = [System.IO.Path]::GetRelativePath($Root, $item.FullName).Replace('\','/')
            throw "Caller content contains unsupported symbolic link or junction '$relative'."
        }
    }
}

function Resolve-CallerProjectRoot {
    param(
        [Parameter(Mandatory)][string]$CallerRoot,
        [Parameter(Mandatory)][string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'project-path must not be empty.'
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Invalid project-path '$RelativePath'. Absolute paths are not allowed."
    }
    if ($RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Invalid project-path '$RelativePath'. Path traversal is not allowed."
    }

    $candidate = [System.IO.Path]::GetFullPath((Join-Path $CallerRoot $RelativePath))
    if (-not (Test-PathWithinRoot -Root $CallerRoot -Candidate $candidate -AllowRoot)) {
        throw "Invalid project-path '$RelativePath'. It resolves outside the caller workspace."
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        throw "Project path '$RelativePath' does not exist as a directory beneath the caller workspace."
    }
    Assert-NoLinkTraversal -Root $CallerRoot -Candidate $candidate
    (Resolve-Path -LiteralPath $candidate).Path
}

function Test-RootsOverlap {
    param([string]$First, [string]$Second)
    (Test-PathWithinRoot -Root $First -Candidate $Second -AllowRoot) -or
        (Test-PathWithinRoot -Root $Second -Candidate $First -AllowRoot)
}

function Invoke-TrustedValidation {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $started = (Get-Date).ToUniversalTime()
    $output = [System.Collections.Generic.List[string]]::new()
    $totalOutputLines = 0
    & pwsh -NoProfile -File $ScriptPath @Arguments 2>&1 | ForEach-Object {
        foreach ($line in @(ConvertTo-SanitizedWorkflowOutputLine -InputObject $_ -WorkspaceRoot $workflowWorkspaceRoot -TemporaryRoot $temporaryRoot)) {
            $totalOutputLines++
            if ($output.Count -eq 200) { $output.RemoveAt(0) }
            $output.Add($line)
        }
    }
    $exitCode = $LASTEXITCODE
    $completed = (Get-Date).ToUniversalTime()
    $relativeTool = [System.IO.Path]::GetRelativePath($standardsRoot, $ScriptPath).Replace('\','/')
    $record = [ordered]@{
        name = $Name
        category = $Name
        status = if ($exitCode -eq 0) { 'Passed' } else { 'Failed' }
        requiredValidation = $true
        command = "pwsh -NoProfile -File standards/$relativeTool"
        path = $relativeTool
        toolPath = "standards/$relativeTool"
        target = 'caller'
        startedAtUtc = $started.ToString('o')
        completedAtUtc = $completed.ToString('o')
        durationSeconds = [math]::Round(($completed - $started).TotalSeconds, 3)
        exitCode = $exitCode
        summary = if ($exitCode -eq 0) { "$Name completed successfully." } else { "$Name failed with exit code $exitCode." }
        failureReason = if ($exitCode -eq 0) { $null } else { (($output | Select-Object -Last 10) -join [Environment]::NewLine) }
        outputLinesCaptured = $output.Count
        outputLinesTotal = $totalOutputLines
    }
    $script:results.Add($record)
    $output | ForEach-Object { Write-Output $_ }
    if ($totalOutputLines -gt $output.Count) { Write-Output "[validator-output] $($totalOutputLines - $output.Count) earlier lines were omitted." }
}

$callerRoot = (Resolve-Path -LiteralPath $Path).Path
$evidenceFull = $null
$bootstrapEvidenceReady = $false
if (-not $EvidenceRoot -and $OutputJson) {
    $EvidenceRoot = Split-Path -Parent ([System.IO.Path]::GetFullPath($OutputJson))
}
if ($EvidenceRoot) {
    $evidenceFull = [System.IO.Path]::GetFullPath($EvidenceRoot)
    if ($env:GITHUB_ACTIONS -eq 'true' -and ((Test-RootsOverlap -First $evidenceFull -Second $callerRoot) -or (Test-RootsOverlap -First $evidenceFull -Second $standardsRoot))) {
        throw 'Evidence workspace must be separate from both caller and standards workspaces.'
    }
    if (Test-Path -LiteralPath $evidenceFull) {
        $evidenceItem = Get-Item -LiteralPath $evidenceFull -Force
        if ($evidenceItem.LinkType -or ($evidenceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            throw 'Evidence workspace must not be a symbolic link or junction.'
        }
    }
    New-Item -ItemType Directory -Path $evidenceFull -Force | Out-Null
    $bootstrapEvidenceReady = $true
}

try {
    $projectRoot = Resolve-CallerProjectRoot -CallerRoot $callerRoot -RelativePath $ProjectPath
    if (-not $evidenceFull) {
        $EvidenceRoot = Join-Path $projectRoot 'evidence'
        $evidenceFull = [System.IO.Path]::GetFullPath($EvidenceRoot)
        if (Test-Path -LiteralPath $evidenceFull) {
            $evidenceItem = Get-Item -LiteralPath $evidenceFull -Force
            if ($evidenceItem.LinkType -or ($evidenceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                throw 'Evidence workspace must not be a symbolic link or junction.'
            }
        }
        New-Item -ItemType Directory -Path $evidenceFull -Force | Out-Null
        $bootstrapEvidenceReady = $true
    }

    if ($env:GITHUB_ACTIONS -eq 'true' -and (Test-RootsOverlap -First $callerRoot -Second $standardsRoot)) {
        throw 'Caller and standards workspaces must be separate and must not overlap.'
    }

if ($CallerCommitSha -and $CallerCommitSha -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Caller commit SHA must be a full 40-character hexadecimal commit SHA.'
}
if ($StandardsWorkflowSha -and $StandardsWorkflowSha -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Standards workflow SHA must be a full 40-character hexadecimal commit SHA.'
}
if ($StandardsRepository -ne 'AIAllTheThingz/Engineering-Standards') {
    throw "Unexpected standards workflow repository '$StandardsRepository'."
}
if ($CallerCommitSha -and (Test-Path -LiteralPath (Join-Path $callerRoot '.git'))) {
    $callerHead = (& git -C $callerRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or $callerHead.Trim() -ne $CallerCommitSha) {
        throw 'Caller checkout HEAD does not match the immutable caller commit SHA.'
    }
}
if ($StandardsWorkflowSha -and (Test-Path -LiteralPath (Join-Path $standardsRoot '.git'))) {
    $standardsHead = (& git -C $standardsRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or $standardsHead.Trim() -ne $StandardsWorkflowSha) {
        throw 'Standards checkout HEAD does not match the immutable reusable workflow SHA.'
    }
}

$manifestPath = Join-Path $projectRoot 'project-manifest.json'
$configPath = Join-Path $projectRoot 'governance.config.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Required project-manifest.json is missing.' }
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'Required governance.config.json is missing.' }
Assert-NoLinkTraversal -Root $projectRoot -Candidate $manifestPath
Assert-NoLinkTraversal -Root $projectRoot -Candidate $configPath
Assert-NoNestedLinks -Root $callerRoot

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
if ($ExpectedGovernanceVersion -and $manifest.governanceVersion -ne $ExpectedGovernanceVersion) {
    throw "Governance version mismatch: workflow expects '$ExpectedGovernanceVersion' but manifest declares '$($manifest.governanceVersion)'."
}
if ($CallerRepository -and $manifest.repository -ne $CallerRepository) {
    throw "Manifest repository '$($manifest.repository)' does not match caller repository '$CallerRepository'."
}
if (@($config.controls.mandatoryControlsDisabled).Count -gt 0) {
    throw 'governance.config.json attempts to disable one or more mandatory controls. Reusable workflow validation requires an independently validated approved exception.'
}

$isMaintainerProfile = $manifest.projectType -eq 'governance' -and $manifest.repository -eq $StandardsRepository
$validationProfile = if ($isMaintainerProfile) { 'standards-maintainer' } else { 'downstream' }
if (-not $isMaintainerProfile) {
    foreach ($unsupportedField in @('additionalForbiddenPatterns','reviewedAllowlist')) {
        if (@($config[$unsupportedField]).Count -gt 0) {
            throw "governance.config.json field '$unsupportedField' is not yet supported by the central downstream workflow and must be empty. Support is deferred to Issue #21."
        }
    }
}
$requestedCategories = if ($Category) { @($Category) } else { @($config.validationCategories) }
$selected = [System.Collections.Generic.List[string]]::new()
if (-not $Category) { $selected.Add('Contract') }
foreach ($item in $requestedCategories) {
    if ($item -notin $selected) { $selected.Add([string]$item) }
}
if ($isMaintainerProfile) {
    if (-not $Category) {
        foreach ($item in @('JsonSchemas','YamlSyntax','WorkflowArchitecture','MarkdownLinks','DocumentationCompleteness','ForbiddenPatterns','RepositoryHealth','PowerShellParser','Pester','PSScriptAnalyzer','Examples')) {
            if ($item -notin $selected) { $selected.Add($item) }
        }
    }
}
else {
    $unsupported = @($selected | Where-Object { $_ -in @('JsonSchemas','YamlSyntax','WorkflowArchitecture','RepositoryHealth','Evidence','Examples','Pester','PSScriptAnalyzer','PowerShellParser') })
    if ($unsupported.Count -gt 0) {
        throw "Downstream validation categories require repository-owned execution or maintainer layout and are not safe in this workflow: $($unsupported -join ', ')."
    }
}

$script:results = [System.Collections.Generic.List[object]]::new()
$toolMap = @{
    Contract = @{ path='actions/validate-contract/Invoke-ContractValidation.ps1'; args=@('-Path',$projectRoot) }
    JsonSchemas = @{ path='scripts/Test-JsonSchemas.ps1'; args=@('-Path',$projectRoot) }
    YamlSyntax = @{ path='scripts/Test-YamlSyntax.ps1'; args=@('-Path',$projectRoot) }
    WorkflowArchitecture = @{ path='scripts/Test-GitHubWorkflowArchitecture.ps1'; args=@('-Path',$projectRoot,'-DefaultBranch','master') + $(if ($StandardsWorkflowSha) { @('-ExpectedReusableWorkflowSha',$StandardsWorkflowSha) } else { @() }) + $(if ($isMaintainerProfile) { @('-RequireCandidateValidation') } else { @() }) }
    MarkdownLinks = @{ path='scripts/Test-MarkdownLinks.ps1'; args=@('-Path',$projectRoot) }
    DocumentationCompleteness = @{ path='scripts/Test-DocumentationCompleteness.ps1'; args=@('-Path',$projectRoot) }
    ForbiddenPatterns = @{ path='actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1'; args=@('-Path',$projectRoot) }
    RepositoryHealth = @{ path='actions/repository-health/Invoke-RepositoryHealth.ps1'; args=@('-Path',$projectRoot) }
    Evidence = @{ path='actions/validate-evidence/Invoke-EvidenceValidation.ps1'; args=@('-Path',$projectRoot,'-EvidencePath','evidence/local-completion-result.json') }
}

foreach ($name in @($selected)) {
    if ($toolMap.ContainsKey($name)) {
        $definition = $toolMap[$name]
        Invoke-TrustedValidation -Name $name -ScriptPath (Join-Path $standardsRoot $definition.path) -Arguments $definition.args
        continue
    }
    switch ($name) {
        'PowerShellParser' {
            $started = (Get-Date).ToUniversalTime()
            $parseErrors = [System.Collections.Generic.List[object]]::new()
            Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Include *.ps1,*.psm1,*.psd1 | ForEach-Object {
                $tokens = $null
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
                foreach ($error in @($errors)) { $parseErrors.Add($error) }
            }
            $completed = (Get-Date).ToUniversalTime()
            $script:results.Add([ordered]@{ name='PowerShellParser'; category='PowerShellParser'; status=if($parseErrors.Count){'Failed'}else{'Passed'}; requiredValidation=$true; command='PowerShell parser (caller data only)'; toolPath='pwsh'; target='caller'; startedAtUtc=$started.ToString('o'); completedAtUtc=$completed.ToString('o'); durationSeconds=[math]::Round(($completed-$started).TotalSeconds,3); exitCode=if($parseErrors.Count){1}else{0}; summary="Parsed caller PowerShell files; errors: $($parseErrors.Count)."; failureReason=if($parseErrors.Count){($parseErrors -join [Environment]::NewLine)}else{$null} })
        }
        'Pester' {
            Invoke-TrustedValidation -Name Pester -ScriptPath (Join-Path $standardsRoot 'scripts/Invoke-PesterSuite.ps1') -Arguments @('-EvidenceRoot',$evidenceFull)
        }
        'PSScriptAnalyzer' {
            $started = (Get-Date).ToUniversalTime()
            $findings = @(Invoke-ScriptAnalyzer -Path $projectRoot -Recurse -Severity Error)
            $completed = (Get-Date).ToUniversalTime()
            $script:results.Add([ordered]@{ name='PSScriptAnalyzer'; category='PSScriptAnalyzer'; status=if($findings.Count){'Failed'}else{'Passed'}; requiredValidation=$true; command='Invoke-ScriptAnalyzer -Path caller -Recurse -Severity Error'; toolPath='PSScriptAnalyzer'; target='caller'; startedAtUtc=$started.ToString('o'); completedAtUtc=$completed.ToString('o'); durationSeconds=[math]::Round(($completed-$started).TotalSeconds,3); exitCode=if($findings.Count){1}else{0}; summary="PSScriptAnalyzer error findings: $($findings.Count)."; failureReason=if($findings.Count){($findings | Out-String)}else{$null} })
        }
        'Examples' {
            Invoke-TrustedValidation -Name Examples -ScriptPath (Join-Path $standardsRoot 'scripts/Test-Examples.ps1')
        }
        default { throw "Unsupported validation category '$name'." }
    }
}

if ($ControlledFailure) {
    $now = (Get-Date).ToUniversalTime()
    $script:results.Add([ordered]@{ name='ControlledFailure'; category='workflow'; status='Failed'; requiredValidation=$true; command='controlled-failure-test'; toolPath='standards reusable workflow'; target='caller'; startedAtUtc=$now.ToString('o'); completedAtUtc=$now.ToString('o'); durationSeconds=0; exitCode=1; summary='Controlled failure was requested after normal validation.'; failureReason='Controlled failure test intentionally fails after validation evidence is created.' })
}

$report = [ordered]@{
    schemaVersion = '1.0.0'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    caller = [ordered]@{ repository=$CallerRepository; commitSha=$CallerCommitSha; workspace='caller'; projectPath=$ProjectPath }
    standards = [ordered]@{ repository=$StandardsRepository; workflowSha=$StandardsWorkflowSha; workspace='standards' }
    evidenceWorkspace = 'evidence'
    governanceVersion = $manifest.governanceVersion
    riskClassification = $manifest.riskClassification
    validationProfile = $validationProfile
    checksExecuted = @($script:results | ForEach-Object { $_.name })
    results = @($script:results)
    failed = @($script:results | Where-Object status -eq 'Failed').Count
}
$reportPath = Join-Path $evidenceFull 'governance-validation.json'
$report | ConvertTo-OrderedJson | Set-Content -LiteralPath $reportPath -Encoding utf8
if ($OutputJson) {
    $legacyReportPath = [System.IO.Path]::GetFullPath($OutputJson)
    if ($env:GITHUB_ACTIONS -eq 'true' -and -not (Test-PathWithinRoot -Root $evidenceFull -Candidate $legacyReportPath -AllowRoot)) {
        throw 'OutputJson must remain beneath the dedicated evidence workspace in GitHub Actions.'
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $legacyReportPath) -Force | Out-Null
    $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $legacyReportPath -Encoding utf8
}
$script:results | ForEach-Object { "[$($_.status)] $($_.name): $($_.summary)" }
    if ($report.failed -gt 0) { exit 1 }
}
catch {
    $safeFailure = ConvertTo-SanitizedWorkflowFailureMessage -InputObject $_.Exception.Message -WorkspaceRoot $workflowWorkspaceRoot -TemporaryRoot $temporaryRoot
    if ($bootstrapEvidenceReady) {
        Write-GovernanceBootstrapFailureReport `
            -EvidenceRoot $evidenceFull `
            -FailureMessage $safeFailure `
            -CallerRepository $CallerRepository `
            -CallerCommitSha $CallerCommitSha `
            -ProjectPath $ProjectPath `
            -StandardsRepository $StandardsRepository `
            -StandardsWorkflowSha $StandardsWorkflowSha `
            -GovernanceVersion $ExpectedGovernanceVersion `
            -WorkspaceRoot $workflowWorkspaceRoot `
            -TemporaryRoot $temporaryRoot | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($safeFailure)) { $safeFailure = 'Trusted governance validation failed before the aggregate report could be finalized.' }
    Write-Error $safeFailure
    exit 1
}
exit 0
