<#
.SYNOPSIS
Checks repository governance health.
.DESCRIPTION
Checks required governance files, JSON parsing, schemas and fixtures, documentation completeness, tests, CODEOWNERS, Dependabot, workflows, action metadata, and evidence presence.
.PARAMETER Path
Repository root to validate. Defaults to the current directory.
.PARAMETER OutputJson
Optional repository-relative path for the structured validation report.
.PARAMETER Advisory
Records findings but exits successfully when blocking findings exist.
.PARAMETER RepositoryOwnerType
Exact trusted owner type: Unknown, User, or Organization. Unknown performs structural validation only. User or Organization must come from trusted repository metadata or verified GitHub API evidence and does not prove identity existence or review eligibility.
.EXAMPLE
pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path . -RepositoryOwnerType User
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$OutputJson,
    [switch]$Advisory,
    [ValidateScript({ @('Unknown', 'User', 'Organization') -ccontains $_ }, ErrorMessage = 'RepositoryOwnerType must be exactly Unknown, User, or Organization.')][string]$RepositoryOwnerType = 'Unknown'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../scripts/OwnershipProtection.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()

function Add-RequiredFileResult {
    param([Parameter(Mandatory)][string]$RelativePath)
    try {
        $full = Resolve-SafePath -Root $root -ChildPath $RelativePath -AllowMissingLeaf
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $results.Add((New-ValidationResult -Status Passed -Message 'Required health file exists.' -Path $RelativePath -Severity info))
        }
        else {
            $results.Add((New-ValidationResult -Status Failed -Message 'Required health file missing.' -Path $RelativePath))
        }
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $RelativePath))
    }
}

function Resolve-CodeownersCandidate {
    param([Parameter(Mandatory)][string]$RelativePath)

    $current = $root
    $segments = $RelativePath.Split('/')
    for ($segmentIndex = 0; $segmentIndex -lt $segments.Count; $segmentIndex++) {
        $segment = $segments[$segmentIndex]
        $entries = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue)
        $exactEntry = @($entries | Where-Object { [string]::Equals($_.Name, $segment, [System.StringComparison]::Ordinal) }) | Select-Object -First 1
        if (-not $exactEntry) {
            $caseVariant = @($entries | Where-Object { [string]::Equals($_.Name, $segment, [System.StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
            if ($caseVariant) {
                return [pscustomobject]@{
                    State = 'Invalid'
                    Message = "CODEOWNERS candidate '$RelativePath' does not match repository path casing; found '$($caseVariant.Name)' where '$segment' is required."
                }
            }
            return [pscustomobject]@{ State = 'Missing' }
        }
        if ($segmentIndex -lt ($segments.Count - 1)) {
            if (-not $exactEntry.PSIsContainer) {
                return [pscustomobject]@{ State = 'Invalid'; Message = "CODEOWNERS candidate '$RelativePath' has a non-directory path segment '$segment'." }
            }
            if ($exactEntry.LinkType -or ($exactEntry.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                return [pscustomobject]@{ State = 'Invalid'; Message = "CODEOWNERS candidate '$RelativePath' must not traverse a symbolic link, junction, or reparse point at '$segment'." }
            }
        }
        $current = $exactEntry.FullName
    }

    $item = Get-Item -LiteralPath $current -Force
    if ($item.PSIsContainer) {
        return [pscustomobject]@{ State = 'Invalid'; Message = "CODEOWNERS candidate '$RelativePath' is not a regular file." }
    }
    if ($item.LinkType -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        return [pscustomobject]@{ State = 'Invalid'; Message = "CODEOWNERS candidate '$RelativePath' must not be a symbolic link, junction, or reparse point." }
    }
    return [pscustomobject]@{ State = 'Valid'; FullName = $item.FullName }
}

$required = @(
    'README.md',
    'LICENSE',
    'SECURITY.md',
    'CONTRIBUTING.md',
    'project-manifest.json',
    'governance.config.json',
    'AGENTS.md',
    '.github/dependabot.yml',
    '.github/workflows/governance-ci.yml',
    '.github/pull_request_template.md',
    'docs/BRANCH_PROTECTION.md',
    'docs/ACTION_SECURITY.md',
    'scripts/GovernanceValidation.psm1',
    'scripts/Test-DocumentationCompleteness.ps1',
    'scripts/Test-YamlSyntax.ps1',
    'scripts/Test-GitHubWorkflowArchitecture.ps1'
)
$required | ForEach-Object { Add-RequiredFileResult -RelativePath $_ }

$trackedGenerated = @(& git -C $root ls-files 2>$null | Where-Object {
    $_ -match '(^|/)(bin|obj|dist)(/|$)' -or $_ -match '^(coverage|TestResults)(/|$)'
})
foreach ($generated in $trackedGenerated) {
    $results.Add((New-ValidationResult -Status Failed -Message 'Generated build output must not be tracked.' -Path $generated))
}

foreach ($json in Get-ChildItem -LiteralPath $root -Filter '*.json' -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\|node_modules|bin\\|obj\\|dist\\' }) {
    try {
        Read-JsonFile -Path $json.FullName | Out-Null
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message "Invalid JSON: $($_.Exception.Message)" -Path ([System.IO.Path]::GetRelativePath($root, $json.FullName).Replace('\','/'))))
    }
}

if (Test-Path -LiteralPath (Join-Path $root 'project-manifest.json')) {
    foreach ($item in @(Test-GovernanceJsonDocument -Path (Join-Path $root 'project-manifest.json') -Kind 'project-manifest')) { $results.Add($item) }
}
if (Test-Path -LiteralPath (Join-Path $root 'governance.config.json')) {
    foreach ($item in @(Test-GovernanceJsonDocument -Path (Join-Path $root 'governance.config.json') -Kind 'governance-config')) { $results.Add($item) }
}

$documentationValidator = Join-Path $root 'scripts/Test-DocumentationCompleteness.ps1'
if (Test-Path -LiteralPath $documentationValidator -PathType Leaf) {
    & pwsh -NoProfile -File $documentationValidator -Path $root | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $results.Add((New-ValidationResult -Status Failed -Message 'Documentation completeness failed.' -Path $root))
    }
}
else {
    $results.Add((New-ValidationResult -Status Failed -Message 'Documentation completeness validator missing.' -Path 'scripts/Test-DocumentationCompleteness.ps1'))
}

$schemaValidator = Join-Path $root 'scripts/Test-JsonSchemas.ps1'
if (Test-Path -LiteralPath $schemaValidator -PathType Leaf) {
    & pwsh -NoProfile -File $schemaValidator -Path $root | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $results.Add((New-ValidationResult -Status Failed -Message 'JSON schema and fixture validation failed.' -Path 'schemas'))
    }
}
else {
    $results.Add((New-ValidationResult -Status Failed -Message 'JSON schema validator missing.' -Path 'scripts/Test-JsonSchemas.ps1'))
}

$testFiles = @(Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Recurse -Filter '*.Tests.ps1' -File -ErrorAction SilentlyContinue)
if ($testFiles.Count -lt 1) {
    $results.Add((New-ValidationResult -Status Failed -Message 'No Pester tests found.' -Path 'tests'))
}
else {
    $results.Add((New-ValidationResult -Status Passed -Message "Pester test files found: $($testFiles.Count)." -Path 'tests' -Severity info))
}

$codeownersRelativePath = $null
$codeowners = $null
foreach ($candidatePath in @('.github/CODEOWNERS', 'CODEOWNERS', 'docs/CODEOWNERS')) {
    $candidate = Resolve-CodeownersCandidate -RelativePath $candidatePath
    if ($candidate.State -eq 'Invalid') {
        $results.Add((New-ValidationResult -Status Failed -Message $candidate.Message -Path $candidatePath))
        break
    }
    if ($candidate.State -eq 'Valid') {
        $codeownersRelativePath = $candidatePath
        $codeowners = $candidate.FullName
        break
    }
}
if ($codeownersRelativePath) {
    $results.Add((New-ValidationResult -Status Passed -Message 'GitHub-selected CODEOWNERS file exists.' -Path $codeownersRelativePath -Severity info))
    $text = Get-Content -LiteralPath $codeowners -Raw
    $requiredCodeownerPaths = @()
    $governanceConfigPath = Join-Path $root 'governance.config.json'
    if (Test-Path -LiteralPath $governanceConfigPath -PathType Leaf) {
        try {
            $governanceConfig = Read-JsonFile -Path $governanceConfigPath
            if ($governanceConfig.ContainsKey('ownership') -and
                $governanceConfig.ownership -is [System.Collections.IDictionary] -and
                $governanceConfig.ownership.Contains('requiredCodeownerPaths')) {
                $requiredCodeownerPaths = @($governanceConfig.ownership.requiredCodeownerPaths)
            }
        }
        catch {
            # JSON parsing is reported above; do not invent required paths from an invalid config.
        }
    }
    $requiredCodeownerEvaluationPaths = [System.Collections.Generic.List[string]]::new()
    $seenCodeownerEvaluationPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($requiredPath in $requiredCodeownerPaths) {
        if ($requiredPath -isnot [string] -or $requiredPath -notmatch '^/(?!/)(?:\.[A-Za-z0-9_-]|[A-Za-z0-9_-])(?:[A-Za-z0-9._-]*[A-Za-z0-9_-])?(?:/(?:\.[A-Za-z0-9_-]|[A-Za-z0-9_-])(?:[A-Za-z0-9._-]*[A-Za-z0-9_-])?)*/?$') { continue }
        $repositoryRelativePath = $requiredPath.TrimStart('/').TrimEnd('/')
        try {
            $requiredFullPath = Resolve-SafePath -Root $root -ChildPath $repositoryRelativePath -AllowMissingLeaf
            if (-not (Test-Path -LiteralPath $requiredFullPath)) {
                $results.Add((New-ValidationResult -Status Failed -Message "Configured required CODEOWNERS path '$requiredPath' does not exist in the repository." -Path 'governance.config.json'))
            }
            else {
                $actualItem = Get-Item -LiteralPath $requiredFullPath -Force
                $actualRelativePath = [System.IO.Path]::GetRelativePath($root, $actualItem.FullName).Replace([char]'\', [char]'/')
                if (-not [string]::Equals($repositoryRelativePath, $actualRelativePath, [System.StringComparison]::Ordinal)) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Configured required CODEOWNERS path '$requiredPath' does not match repository path casing '/$actualRelativePath'." -Path 'governance.config.json'))
                }
                $expectsDirectory = $requiredPath.EndsWith('/', [System.StringComparison]::Ordinal)
                if ($expectsDirectory -and -not $actualItem.PSIsContainer) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Configured required CODEOWNERS path '$requiredPath' ends with '/' but is not a directory." -Path 'governance.config.json'))
                }
                elseif (-not $expectsDirectory -and $actualItem.PSIsContainer) {
                    $results.Add((New-ValidationResult -Status Failed -Message "Configured required CODEOWNERS path '$requiredPath' does not end with '/' but is a directory." -Path 'governance.config.json'))
                }
                elseif ($actualItem.PSIsContainer) {
                    $containedFiles = @()
                    foreach ($containedItem in @(Get-ChildItem -LiteralPath $actualItem.FullName -Recurse -Force)) {
                        if ($containedItem.LinkType -or ($containedItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                            $containedRelativePath = [System.IO.Path]::GetRelativePath($root, $containedItem.FullName).Replace([char]'\', [char]'/')
                            $results.Add((New-ValidationResult -Status Failed -Message "Configured required CODEOWNERS directory '$requiredPath' contains symbolic link or junction '/$containedRelativePath'." -Path 'governance.config.json'))
                            continue
                        }
                        if (-not $containedItem.PSIsContainer) { $containedFiles += $containedItem }
                    }
                    foreach ($containedFile in $containedFiles) {
                        $containedRelativePath = [System.IO.Path]::GetRelativePath($root, $containedFile.FullName).Replace([char]'\', [char]'/')
                        Resolve-SafePath -Root $root -ChildPath $containedRelativePath | Out-Null
                        $evaluationPath = "/$containedRelativePath"
                        if ($seenCodeownerEvaluationPaths.Add($evaluationPath)) { $requiredCodeownerEvaluationPaths.Add($evaluationPath) }
                    }
                    if ($containedFiles.Count -eq 0 -and $seenCodeownerEvaluationPaths.Add($requiredPath)) {
                        $requiredCodeownerEvaluationPaths.Add($requiredPath)
                    }
                }
                elseif ($seenCodeownerEvaluationPaths.Add($requiredPath)) {
                    $requiredCodeownerEvaluationPaths.Add($requiredPath)
                }
            }
        }
        catch {
            $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path 'governance.config.json'))
        }
    }
    foreach ($finding in @(Test-CodeownersContent -Content $text -RepositoryOwnerType $RepositoryOwnerType -RequiredPaths @($requiredCodeownerEvaluationPaths))) {
        $severity = if ($finding.Status -eq 'Passed') { 'info' } else { 'error' }
        $findingData = [ordered]@{
            rulePattern = $finding.Path
            identity = $finding.Identity
            requiredPath = $finding.RequiredPath
            effectivePattern = $finding.EffectivePattern
            effectiveOwners = @($finding.EffectiveOwners)
            ruleIndex = $finding.RuleIndex
            lineNumber = $finding.LineNumber
            repositoryOwnerType = $finding.RepositoryOwnerType
            reason = $finding.Reason
        }
        $results.Add((New-ValidationResult -Status $finding.Status -Message $finding.Message -Path $codeownersRelativePath -Severity $severity -Data $findingData))
    }
}
elseif (-not @($results | Where-Object { $_.status -eq 'Failed' -and $_.path -in @('.github/CODEOWNERS', 'CODEOWNERS', 'docs/CODEOWNERS') })) {
    $results.Add((New-ValidationResult -Status Failed -Message 'Required health file missing. GitHub looks for CODEOWNERS in .github/, the repository root, then docs/.' -Path 'CODEOWNERS'))
}

foreach ($actionDir in Get-ChildItem -LiteralPath (Join-Path $root 'actions') -Directory -ErrorAction SilentlyContinue) {
    foreach ($requiredActionFile in @('action.yml','README.md')) {
        $candidate = Join-Path $actionDir.FullName $requiredActionFile
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $results.Add((New-ValidationResult -Status Failed -Message "Action is missing $requiredActionFile." -Path ([System.IO.Path]::GetRelativePath($root, $candidate).Replace('\','/'))))
        }
    }
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    $results.Add((New-ValidationResult -Status Passed -Message 'Repository health validation completed.' -Path $root -Severity info))
}

$report = New-ValidationReport -Results @($results)
if ($OutputJson) {
    $outPath = Resolve-SafePath -Root $root -ChildPath $OutputJson -AllowMissingLeaf
    New-Item -ItemType Directory -Path (Split-Path -Parent $outPath) -Force | Out-Null
    $report | ConvertTo-OrderedJson | Set-Content -LiteralPath $outPath -Encoding utf8
}
$report.results | ForEach-Object { "[$($_.status)] $($_.path) $($_.message)" }
if ($report.failed -gt 0 -and -not $Advisory) { exit 1 }
exit 0
