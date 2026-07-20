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
Optional explicit category selection. The selection applies only to optional
profile categories; mandatory categories remain selected unless an active,
contract-validated exception disables the exact category.
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
.PARAMETER ExpectedReusableWorkflowSha
Optional immutable SHA that workflow architecture validation must require.
Candidate validation uses the immutable harness SHA while executing the
candidate validator implementation from a different candidate commit.
.PARAMETER RepositoryOwnerType
Trusted repository owner type used by ownership-aware validation. Accepted
values are exactly Unknown, User, or Organization. The default is Unknown;
callers must not infer this value from the repository name. Schema version
1.2.0 requires a trusted User or Organization value and fails closed otherwise.
.PARAMETER ControlledFailure
Adds an intentional final failed check after normal validation so evidence can
be generated and uploaded before enforcement fails.
.PARAMETER CandidateMaintainerValidation
Allows the Engineering Standards candidate harness to validate the candidate
checkout with its own candidate validators. This mode requires the exact
maintainer repository identity, immutable candidate SHA, external evidence
root, and expected immutable harness SHA; it is not available downstream.
.EXAMPLE
pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType User
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
    [ValidateSet('Contract','AgentStandards','CodexSkills','JsonSchemas','YamlSyntax','WorkflowArchitecture','MarkdownLinks','DocumentationCompleteness','ForbiddenPatterns','RepositoryHealth','Evidence','PowerShellParser','PythonStaticAnalysis','BashStaticAnalysis','Pester','PSScriptAnalyzer','Examples')]
    [string[]]$Category,
    [string]$ExpectedGovernanceVersion,
    [string]$CallerRepository,
    [string]$CallerCommitSha,
    [string]$StandardsRepository = 'AIAllTheThingz/Engineering-Standards',
    [string]$StandardsWorkflowSha,
    [string]$ExpectedReusableWorkflowSha,
    [ValidateScript({ @('Unknown', 'User', 'Organization') -ccontains $_ }, ErrorMessage = 'RepositoryOwnerType must be exactly Unknown, User, or Organization.')]
    [string]$RepositoryOwnerType = 'Unknown',
    [switch]$ControlledFailure,
    [switch]$CandidateMaintainerValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$standardsRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$workflowWorkspaceRoot = Split-Path -Parent $standardsRoot
$temporaryRoot = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
Import-Module (Join-Path $standardsRoot 'scripts/GovernanceValidation.psm1') -Force
Import-Module (Join-Path $standardsRoot 'scripts/StaticAnalysisTools.psm1') -Force

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

function Add-AggregateResult {
    <#
    .SYNOPSIS
    Adds a canonical child result to the aggregate validation report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Passed','Failed','NotRun','Blocked','NotApplicable')][string]$Status,
        [Parameter(Mandatory)][string]$Summary,
        [AllowNull()][Nullable[int]]$ExitCode,
        [string]$Command,
        [string]$ToolPath,
        [string]$FailureReason,
        [string]$NotApplicableRationale,
        [string]$ExceptionReference
    )

    $now = (Get-Date).ToUniversalTime()
    $record = [ordered]@{
        name = $Name
        category = $Name
        status = $Status
        requiredValidation = $true
        command = $Command
        toolPath = $ToolPath
        target = 'caller'
        startedAtUtc = $now.ToString('o')
        completedAtUtc = $now.ToString('o')
        durationSeconds = 0
        exitCode = $ExitCode
        summary = $Summary
        failureReason = $FailureReason
        notApplicableRationale = $NotApplicableRationale
        exceptionReference = $ExceptionReference
    }
    $script:results.Add($record)
}

function Get-CategoryNonApplicabilityReason {
    <#
    .SYNOPSIS
    Returns a reason when a conditional category does not apply to the project.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$PlanEntry,
        [Parameter(Mandatory)][string]$ProjectRoot
    )

    switch -CaseSensitive ([string]$PlanEntry.applicability) {
        'Always' { return $null }
        'WhenSkillsPresent' {
            $activeSkills = Test-Path -LiteralPath (Join-Path $ProjectRoot '.agents/skills') -PathType Container
            $suspendedSkills = Test-Path -LiteralPath (Join-Path $ProjectRoot '.agents/suspended-skills') -PathType Container
            if (-not $activeSkills -and -not $suspendedSkills) {
                return 'No governed active or suspended Codex skills directory is present.'
            }
            return $null
        }
        'WhenPowerShellPresent' {
            $powerShellFile = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -Include *.ps1,*.psm1,*.psd1 -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $powerShellFile) { return 'No PowerShell files are present.' }
            return $null
        }
        'WhenPythonPresent' {
            $file = Get-TrustedSourceFiles -Root $ProjectRoot -Language Python | Where-Object { -not $_.excluded } | Select-Object -First 1
            if(-not $file){return 'No maintained Python source files are present.'}; return $null
        }
        'WhenBashPresent' {
            $file = Get-TrustedSourceFiles -Root $ProjectRoot -Language Bash | Where-Object { -not $_.excluded } | Select-Object -First 1
            if(-not $file){return 'No maintained Bash source files are present.'}; return $null
        }
        default { throw "Unsupported validation applicability '$($PlanEntry.applicability)'." }
    }
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

    if ($env:GITHUB_ACTIONS -eq 'true' -and -not $CandidateMaintainerValidation -and (Test-RootsOverlap -First $callerRoot -Second $standardsRoot)) {
        throw 'Caller and standards workspaces must be separate and must not overlap.'
    }

if ($CallerCommitSha -and $CallerCommitSha -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Caller commit SHA must be a full 40-character hexadecimal commit SHA.'
}
if ($StandardsWorkflowSha -and $StandardsWorkflowSha -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Standards workflow SHA must be a full 40-character hexadecimal commit SHA.'
}
if ($ExpectedReusableWorkflowSha -and $ExpectedReusableWorkflowSha -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Expected reusable workflow SHA must be a full 40-character hexadecimal commit SHA.'
}
if ($StandardsRepository -cne 'AIAllTheThingz/Engineering-Standards') {
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
if ($manifest.Contains('schemaVersion') -and $manifest.schemaVersion -eq '1.2.0' -and $RepositoryOwnerType -eq 'Unknown') {
    throw 'Trusted repository owner type is required for schema version 1.2.0.'
}
if ($ExpectedGovernanceVersion -and $manifest.governanceVersion -ne $ExpectedGovernanceVersion) {
    throw "Governance version mismatch: workflow expects '$ExpectedGovernanceVersion' but manifest declares '$($manifest.governanceVersion)'."
}
if ($CallerRepository -and $manifest.repository -ne $CallerRepository) {
    throw "Manifest repository '$($manifest.repository)' does not match caller repository '$CallerRepository'."
}
$disabledMandatoryControls = @($config.controls.mandatoryControlsDisabled)
$usesStructuredExceptionFlow = $config['schemaVersion'] -eq '1.2.0' -and $disabledMandatoryControls.Count -gt 0
if ($disabledMandatoryControls.Count -gt 0 -and -not $usesStructuredExceptionFlow) {
    throw 'governance.config.json attempts to disable one or more mandatory controls. Reusable workflow validation requires an independently validated approved exception.'
}

$isMaintainerProfile = $manifest.projectType -eq 'governance' -and $manifest.repository -eq $StandardsRepository
$validationProfile = if ($isMaintainerProfile) { 'standards-maintainer' } else { 'downstream' }
if ($CandidateMaintainerValidation) {
    if ($env:GITHUB_ACTIONS -ne 'true') {
        throw 'Candidate maintainer validation is restricted to the GitHub Actions candidate harness.'
    }
    if ($env:GITHUB_REPOSITORY -cne 'AIAllTheThingz/Engineering-Standards' -or $env:GITHUB_SHA -cne $CallerCommitSha) {
        throw 'Candidate maintainer validation requires trusted GitHub repository and candidate SHA context.'
    }
    if (-not $isMaintainerProfile -or $CallerRepository -cne 'AIAllTheThingz/Engineering-Standards') {
        throw 'Candidate maintainer validation is restricted to the Engineering Standards repository.'
    }
    if (-not $CallerCommitSha -or -not $ExpectedReusableWorkflowSha) {
        throw 'Candidate maintainer validation requires immutable candidate and reusable harness SHAs.'
    }
    if ($StandardsWorkflowSha) {
        throw 'Candidate maintainer validation must not label the candidate checkout as the trusted baseline standards workflow SHA.'
    }
}
if (-not $isMaintainerProfile) {
    foreach ($unsupportedField in @('additionalForbiddenPatterns','reviewedAllowlist')) {
        if (@($config[$unsupportedField]).Count -gt 0) {
            throw "governance.config.json field '$unsupportedField' is not yet supported by the central downstream workflow and must be empty. Support is deferred to Issue #21."
        }
    }
}
$configuredCategories = @($config.validationCategories)
$requestedCategories = if ($Category) { @($Category) } else { @() }
$profileDefinition = Get-GovernanceValidationProfile -Name $validationProfile
$planArguments = @{
    Profile = $validationProfile
    ConfiguredCategory = $configuredCategories
}
if ($Category) { $planArguments.RequestedCategory = @($Category) }
$validationPlan = @(Resolve-GovernanceValidationPlan @planArguments)

$candidateDisabledCategories = [ordered]@{}
foreach ($disabledControl in @($disabledMandatoryControls)) {
    if ($disabledControl -isnot [System.Collections.IDictionary]) { continue }
    $controlName = [string]$disabledControl.control
    if (@($profileDefinition.mandatoryCategories) -ccontains $controlName) {
        if ($controlName -ceq 'Contract') {
            throw 'Contract validation cannot be disabled because it validates the exception authority.'
        }
        if (-not $isMaintainerProfile) {
            throw "Downstream caller configuration cannot disable mandatory category '$controlName'; exceptions require trusted standards-side authority."
        }
        $candidateDisabledCategories[$controlName] = [string]$disabledControl.exceptionReference
    }
}

$workflowArchitectureSha = if ($ExpectedReusableWorkflowSha) { $ExpectedReusableWorkflowSha } else { $StandardsWorkflowSha }
$toolArguments = @{
    Contract = @('-Path',$projectRoot,'-ExpectedRepository',$CallerRepository,'-ExpectedStandardsRepository',$StandardsRepository,'-RepositoryOwnerType',$RepositoryOwnerType,'-ExpectedWorkflowInterfaceVersion','1.0.0','-ExpectedWorkflowProfile',$validationProfile) + $(if ($StandardsWorkflowSha) { @('-ExpectedGovernanceCommitSha',$StandardsWorkflowSha) } else { @() }) + $(if ($isMaintainerProfile) { @('-ExpectedRequiredCheckName','Governance / Governance validation') } else { @() })
    AgentStandards = @('-Path',$projectRoot)
    CodexSkills = @('-Path',$projectRoot,'-OutputJson',(Join-Path $evidenceFull 'codex-skills.json'),'-AllowedOutputRoot',$evidenceFull)
    JsonSchemas = @('-Path',$projectRoot)
    YamlSyntax = @('-Path',$projectRoot)
    WorkflowArchitecture = @('-Path',$projectRoot,'-DefaultBranch','master') + $(if ($workflowArchitectureSha) { @('-ExpectedReusableWorkflowSha',$workflowArchitectureSha) } else { @() }) + $(if ($isMaintainerProfile) { @('-RequireCandidateValidation') } else { @() })
    MarkdownLinks = @('-Path',$projectRoot)
    DocumentationCompleteness = @('-Path',$projectRoot)
    ForbiddenPatterns = @('-Path',$projectRoot)
    RepositoryHealth = @('-Path',$projectRoot,'-RepositoryOwnerType',$RepositoryOwnerType)
    Evidence = @('-Path',$projectRoot,'-EvidencePath','evidence/local-completion-result.json')
    PythonStaticAnalysis = @('-Path',$projectRoot,'-Profile',$validationProfile,'-OutputJson',(Join-Path $evidenceFull 'python-static-analysis.json'),'-AllowedOutputRoot',$evidenceFull)
    BashStaticAnalysis = @('-Path',$projectRoot,'-Profile',$validationProfile,'-OutputJson',(Join-Path $evidenceFull 'bash-static-analysis.json'),'-AllowedOutputRoot',$evidenceFull)
    Pester = @('-EvidenceRoot',$evidenceFull)
    Examples = @()
}

$script:results = [System.Collections.Generic.List[object]]::new()
$structuredExceptionsApproved = $candidateDisabledCategories.Count -eq 0
foreach ($planEntry in @($validationPlan)) {
    $name = [string]$planEntry.name

    if ($candidateDisabledCategories.Contains($name) -and $structuredExceptionsApproved) {
        $exceptionReference = [string]$candidateDisabledCategories[$name]
        Add-AggregateResult -Name $name -Status NotApplicable -ExitCode $null -Command 'Approved governance exception' -ToolPath 'governance.config.json' -Summary "$name is disabled by active exception '$exceptionReference'." -NotApplicableRationale 'An active contract-validated exception disables this mandatory category.' -ExceptionReference $exceptionReference
        continue
    }

    $nonApplicabilityReason = Get-CategoryNonApplicabilityReason -PlanEntry $planEntry -ProjectRoot $projectRoot
    if ($nonApplicabilityReason) {
        Add-AggregateResult -Name $name -Status NotApplicable -ExitCode $null -Command 'Applicability evaluation' -ToolPath 'scripts/governance-validation.registry.psd1' -Summary "$name is not applicable: $nonApplicabilityReason" -NotApplicableRationale $nonApplicabilityReason
        continue
    }

    $missingPrerequisites = @(Get-GovernanceMissingValidationPrerequisite -PlanEntry $planEntry)
    if ($missingPrerequisites.Count -gt 0) {
        $reason = "Required validation tooling is unavailable: $($missingPrerequisites -join ', ')."
        Add-AggregateResult -Name $name -Status NotRun -ExitCode 3 -Command 'Tool prerequisite discovery' -ToolPath 'scripts/governance-validation.registry.psd1' -Summary $reason -FailureReason $reason
        continue
    }

    switch -CaseSensitive ([string]$planEntry.runner) {
        'Script' {
            $scriptPath = Resolve-SafePath -Root $standardsRoot -ChildPath ([string]$planEntry.path)
            $arguments = if ($toolArguments.ContainsKey($name)) { @($toolArguments[$name]) } else { @() }
            Invoke-TrustedValidation -Name $name -ScriptPath $scriptPath -Arguments $arguments
        }
        'PowerShellParser' {
            $started = (Get-Date).ToUniversalTime()
            $parseErrors = [System.Collections.Generic.List[string]]::new()
            foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Include *.ps1,*.psm1,*.psd1) {
                $tokens = $null
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
                foreach ($errorRecord in @($errors)) {
                    $relativeFile = [System.IO.Path]::GetRelativePath($projectRoot, $file.FullName).Replace('\','/')
                    $parseErrors.Add("${relativeFile}: $($errorRecord.Message)")
                }
            }
            $completed = (Get-Date).ToUniversalTime()
            $script:results.Add([ordered]@{ name=$name; category=$name; status=if($parseErrors.Count){'Failed'}else{'Passed'}; requiredValidation=$true; command='PowerShell parser (caller data only)'; toolPath='pwsh'; target='caller'; startedAtUtc=$started.ToString('o'); completedAtUtc=$completed.ToString('o'); durationSeconds=[math]::Round(($completed-$started).TotalSeconds,3); exitCode=if($parseErrors.Count){1}else{0}; summary="Parsed caller PowerShell files; errors: $($parseErrors.Count)."; failureReason=if($parseErrors.Count){($parseErrors -join [Environment]::NewLine)}else{$null} })
        }
        'PSScriptAnalyzer' {
            $started = (Get-Date).ToUniversalTime()
            $findings = @(Invoke-ScriptAnalyzer -Path $projectRoot -Recurse -Severity Error)
            $completed = (Get-Date).ToUniversalTime()
            $script:results.Add([ordered]@{ name=$name; category=$name; status=if($findings.Count){'Failed'}else{'Passed'}; requiredValidation=$true; command='Invoke-ScriptAnalyzer -Path caller -Recurse -Severity Error'; toolPath='PSScriptAnalyzer'; target='caller'; startedAtUtc=$started.ToString('o'); completedAtUtc=$completed.ToString('o'); durationSeconds=[math]::Round(($completed-$started).TotalSeconds,3); exitCode=if($findings.Count){1}else{0}; summary="PSScriptAnalyzer error findings: $($findings.Count)."; failureReason=if($findings.Count){($findings | Out-String)}else{$null} })
        }
        default { throw "Unsupported validation runner '$($planEntry.runner)' for category '$name'." }
    }

    if ($name -ceq 'Contract' -and $candidateDisabledCategories.Count -gt 0) {
        $contractResult = $script:results[$script:results.Count - 1]
        $structuredExceptionsApproved = $contractResult.status -ceq 'Passed'
    }
}

if ($ControlledFailure) {
    $now = (Get-Date).ToUniversalTime()
    $script:results.Add([ordered]@{ name='ControlledFailure'; category='workflow'; status='Failed'; requiredValidation=$true; command='controlled-failure-test'; toolPath='standards reusable workflow'; target='caller'; startedAtUtc=$now.ToString('o'); completedAtUtc=$now.ToString('o'); durationSeconds=0; exitCode=1; summary='Controlled failure was requested after normal validation.'; failureReason='Controlled failure test intentionally fails after validation evidence is created.' })
}

$overallStatus = Get-GovernanceAggregateStatus -Results @($script:results)
$approvedDisabledCategories = @()
if ($structuredExceptionsApproved) { $approvedDisabledCategories = @($candidateDisabledCategories.Keys) }
$report = [ordered]@{
    schemaVersion = '1.0.0'
    validationRegistryVersion = '1.0.0'
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    caller = [ordered]@{ repository=$CallerRepository; commitSha=$CallerCommitSha; workspace='caller'; projectPath=$ProjectPath }
    standards = [ordered]@{ repository=$StandardsRepository; workflowSha=$StandardsWorkflowSha; expectedReusableWorkflowSha=$workflowArchitectureSha; workspace='standards' }
    evidenceWorkspace = 'evidence'
    governanceVersion = $manifest.governanceVersion
    riskClassification = $manifest.riskClassification
    validationProfile = $validationProfile
    trustModel = $profileDefinition.trustModel
    executesRepositoryCode = $profileDefinition.executesRepositoryCode
    configuredCategories = @($configuredCategories)
    requestedCategories = @($requestedCategories)
    mandatoryCategories = @($profileDefinition.mandatoryCategories)
    selectedCategories = @($validationPlan | ForEach-Object { $_.name })
    approvedDisabledCategories = @($approvedDisabledCategories)
    checksExecuted = @($script:results | ForEach-Object { $_.name })
    status = $overallStatus
    results = @($script:results)
    failed = @($script:results | Where-Object status -eq 'Failed').Count
    blocked = @($script:results | Where-Object status -eq 'Blocked').Count
    notRun = @($script:results | Where-Object status -eq 'NotRun').Count
    notApplicable = @($script:results | Where-Object status -eq 'NotApplicable').Count
    passed = @($script:results | Where-Object status -eq 'Passed').Count
    total = $script:results.Count
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
    if ($report.status -ne 'Passed') { exit 1 }
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
