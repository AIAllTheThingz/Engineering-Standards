<#
.SYNOPSIS
Validates AI-agent instruction standard consistency.
.DESCRIPTION
Checks the base and repository-root AGENTS documents for hierarchy, inheritance,
mandatory work phases, evidence semantics, repository commands, technology
standard references, placeholders, and broken relative links.
.PARAMETER Path
Repository root.
.PARAMETER OutputJson
Optional structured JSON output path.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [ValidateSet('Passed','Failed','Warning','NotRun','Blocked')][string]$Status,
        [string]$Message,
        [string]$RelativePath
    )
    $results.Add((New-ValidationResult -Status $Status -Message $Message -Path $RelativePath))
}

function Get-RelativePath {
    param([string]$FullPath)
    [System.IO.Path]::GetRelativePath($root, $FullPath).Replace('\','/')
}

function Get-WordCount {
    param([string]$Text)
    @($Text -split '\s+' | Where-Object { $_ }).Count
}

function Test-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message,
        [string]$RelativePath
    )
    if ($Text -match $Pattern) {
        Add-Result Passed $Message $RelativePath
    }
    else {
        Add-Result Failed $Message $RelativePath
    }
}

function Test-MarkdownRelativeLinks {
    param(
        [string]$Text,
        [string]$FullPath
    )
    $relativeFile = Get-RelativePath -FullPath $FullPath
    foreach ($match in [regex]::Matches($Text, '(?<!!)\[[^\]]+\]\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target -match '^(https?:|mailto:|#)' -or $target -eq '') { continue }
        $target = $target.Split('#')[0].Trim('<','>')
        if ($target -eq '') { continue }
        try {
            $resolved = if ([System.IO.Path]::IsPathRooted($target)) {
                [System.IO.Path]::GetFullPath($target)
            }
            else {
                [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $FullPath) $target))
            }
            if (-not $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                Add-Result Failed "Relative link '$target' resolves outside the repository." $relativeFile
            }
            elseif (-not (Test-Path -LiteralPath $resolved)) {
                Add-Result Failed "Relative link '$target' is broken." $relativeFile
            }
        }
        catch {
            Add-Result Failed "Relative link '$target' could not be resolved: $($_.Exception.Message)" $relativeFile
        }
    }
}

$basePath = Join-Path $root 'agents/AGENTS_Base.md'
$rootPath = Join-Path $root 'AGENTS.md'

if (-not (Test-Path -LiteralPath $basePath -PathType Leaf)) {
    Add-Result Failed 'AGENTS_Base.md exists.' 'agents/AGENTS_Base.md'
}
else {
    Add-Result Passed 'AGENTS_Base.md exists.' 'agents/AGENTS_Base.md'
}

if (-not (Test-Path -LiteralPath $rootPath -PathType Leaf)) {
    Add-Result Failed 'Root AGENTS.md exists.' 'AGENTS.md'
}
else {
    Add-Result Passed 'Root AGENTS.md exists.' 'AGENTS.md'
}

if (-not (Test-Path -LiteralPath $basePath -PathType Leaf) -or -not (Test-Path -LiteralPath $rootPath -PathType Leaf)) {
    $report = New-ValidationReport -Results @($results)
    Write-ValidationReport -Report $report -OutputJson $OutputJson
    exit 1
}

$base = Get-Content -LiteralPath $basePath -Raw
$rootAgents = Get-Content -LiteralPath $rootPath -Raw

if ($base -match '(?im)\binherits?\s+(?:\[[^\]]+\]\()?AGENTS_Base\.md|inherits?\s+itself|inherits?\s+this\s+base') {
    Add-Result Failed 'Base standard does not claim to inherit itself.' 'agents/AGENTS_Base.md'
}
else {
    Add-Result Passed 'Base standard does not claim to inherit itself.' 'agents/AGENTS_Base.md'
}

Test-Contains $rootAgents '(?is)extends\s+\[?agents/AGENTS_Base\.md|inherits?.*agents/AGENTS_Base\.md' 'Root states that it extends the base standard.' 'AGENTS.md'
Test-Contains $rootAgents '(?im)Default branch\s*\|\s*`?master`?|\bdefault branch\b[^`\r\n]*`?master`?' 'Root declares master as the default branch.' 'AGENTS.md'

$hierarchyPatterns = @(
    'Organization governance documents',
    'agents/AGENTS_Base\.md',
    'technology-specific agent standards?',
    'Repository-root `?AGENTS\.md`?',
    'directory-local `?AGENTS\.md`?'
)
foreach ($pattern in $hierarchyPatterns) {
    Test-Contains $base $pattern "Required hierarchy includes '$pattern'." 'agents/AGENTS_Base.md'
}

foreach ($phase in @(
    'Phase 1 - Discovery',
    'Phase 2 - Validation Planning',
    'Phase 3 - Safe Implementation',
    'Phase 4 - Dry Run Or Simulation',
    'Phase 5 - Validation',
    'Phase 6 - Evidence',
    'Phase 7 - Final Review'
)) {
    Test-Contains $base ([regex]::Escape($phase)) "Required work phase '$phase' is present." 'agents/AGENTS_Base.md'
}

foreach ($status in @('Passed','Failed','Blocked','NotRun','NotApplicable')) {
    Test-Contains $base ([regex]::Escape("``$status``")) "Completion status '$status' is present." 'agents/AGENTS_Base.md'
}

foreach ($term in @('Fabricate test results','Fabricate GitHub runs','Fabricate artifact hashes','Fabricate citations','Claim external execution that did not happen')) {
    Test-Contains $base $term "Prohibited fabrication language includes '$term'." 'agents/AGENTS_Base.md'
}

Test-Contains $base 'EXCEPTION_PROCESS\.md' 'Base references the exception process.' 'agents/AGENTS_Base.md'
Test-Contains $rootAgents 'EXCEPTION_PROCESS\.md' 'Root references the exception process.' 'AGENTS.md'

$requiredCommands = @(
    'pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-YamlSyntax.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-GitHubWorkflowArchitecture.ps1 -Path . -DefaultBranch master',
    'pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .',
    'pwsh -NoProfile -File actions/validate-contract/Invoke-ContractValidation.ps1 -Path .',
    'pwsh -NoProfile -File actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1 -Path . -OutputJson evidence/forbidden-patterns.json',
    'pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path .',
    'Invoke-Pester -Path tests -Output Detailed',
    'Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error',
    'git status --short',
    'git diff --check',
    'git diff',
    'git ls-files'
)
foreach ($command in $requiredCommands) {
    if ($rootAgents.Contains($command)) {
        Add-Result Passed "Required repository validation command is present: $command" 'AGENTS.md'
    }
    else {
        Add-Result Failed "Required repository validation command is missing: $command" 'AGENTS.md'
    }
}

$placeholderPattern = '(?i)\b(TODO|TBD|REPLACE-ME|placeholder-only|lorem ipsum)\b'
foreach ($doc in @(@{ path = 'agents/AGENTS_Base.md'; text = $base }, @{ path = 'AGENTS.md'; text = $rootAgents })) {
    if ($doc.text -match $placeholderPattern) {
        Add-Result Failed 'Document contains unresolved placeholder text.' $doc.path
    }
    else {
        Add-Result Passed 'Document contains no unresolved placeholder text.' $doc.path
    }
}

Test-MarkdownRelativeLinks -Text $base -FullPath $basePath
Test-MarkdownRelativeLinks -Text $rootAgents -FullPath $rootPath

$technologyStandards = @(
    'agents/AGENTS_PowerShell.md',
    'agents/AGENTS_DotNet.md',
    'agents/AGENTS_WebFrontend.md',
    'agents/AGENTS_Database.md',
    'agents/AGENTS_WorkerService.md',
    'agents/AGENTS_Integration.md',
    'agents/AGENTS_Infrastructure.md'
)
foreach ($standard in $technologyStandards) {
    if ($rootAgents.Contains($standard) -and (Test-Path -LiteralPath (Join-Path $root $standard) -PathType Leaf)) {
        Add-Result Passed "Technology-specific standard is referenced: $standard" 'AGENTS.md'
    }
    else {
        Add-Result Failed "Technology-specific standard is missing or unreferenced: $standard" 'AGENTS.md'
    }
}

$baseWordCount = Get-WordCount -Text $base
$rootWordCount = Get-WordCount -Text $rootAgents
if ($rootWordCount -lt [math]::Floor($baseWordCount * 0.85)) {
    Add-Result Passed 'Root AGENTS.md does not duplicate the full base standard.' 'AGENTS.md'
}
else {
    Add-Result Failed 'Root AGENTS.md is too similar in size to the base standard and may duplicate it.' 'AGENTS.md'
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    Add-Result Passed 'Agent standards validation completed.' '.'
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0) { exit 1 }
exit 0
