<#
.SYNOPSIS
Validates governance contract adoption.
.DESCRIPTION
Validates manifest, governance config, required documentation, applicable agent standards, exception references, evidence paths, and documentation completeness for the standards repository.
.PARAMETER Path
Repository path.
.PARAMETER ManifestPath
Manifest path relative to repository root.
.PARAMETER ConfigPath
Governance config path relative to repository root.
.PARAMETER OutputJson
Optional JSON report.
.PARAMETER Advisory
Return success while preserving findings.
.PARAMETER ExpectedRepository
Trusted owner/name repository identity, when available.
.PARAMETER ExpectedStandardsRepository
Trusted owner/name repository identity that supplied the standards workflow, when available.
.PARAMETER RepositoryOwnerType
Trusted repository owner type. Unknown performs structural-only owner-type validation.
.PARAMETER ExpectedGovernanceCommitSha
Trusted immutable standards commit SHA, when available.
.PARAMETER ExpectedWorkflowInterfaceVersion
Trusted workflow interface version, when available.
.PARAMETER ExpectedWorkflowProfile
Trusted workflow validation profile, when available.
.PARAMETER ExpectedRequiredCheckName
Trusted required check name, when available.
.PARAMETER ValidationDateUtc
UTC date used for deterministic exception expiration checks.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$ManifestPath = 'project-manifest.json',
    [string]$ConfigPath = 'governance.config.json',
    [string]$OutputJson,
    [string]$ExpectedRepository,
    [string]$ExpectedStandardsRepository,
    [ValidateSet('Unknown','User','Organization')][string]$RepositoryOwnerType = 'Unknown',
    [string]$ExpectedGovernanceCommitSha,
    [string]$ExpectedWorkflowInterfaceVersion,
    [string]$ExpectedWorkflowProfile,
    [string]$ExpectedRequiredCheckName,
    [datetime]$ValidationDateUtc = [datetime]::UtcNow,
    [switch]$Advisory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$standardsRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$results = [System.Collections.Generic.List[object]]::new()

try {
    $manifestFull = Resolve-SafePath -Root $root -ChildPath $ManifestPath
    $configFull = Resolve-SafePath -Root $root -ChildPath $ConfigPath
}
catch {
    $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $Path))
}

if ($results.Count -eq 0) {
    if (Test-Path -LiteralPath $manifestFull -PathType Leaf) {
        foreach ($item in @(Test-GovernanceJsonDocument -Path $manifestFull -Kind 'project-manifest')) { $results.Add($item) }
    }
    else {
        $results.Add((New-ValidationResult -Status Failed -Message 'Project manifest missing.' -Path $ManifestPath))
    }

    if (Test-Path -LiteralPath $configFull -PathType Leaf) {
        foreach ($item in @(Test-GovernanceJsonDocument -Path $configFull -Kind 'governance-config')) { $results.Add($item) }
    }
    else {
        $results.Add((New-ValidationResult -Status Failed -Message 'Governance config missing.' -Path $ConfigPath))
    }
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    $manifest = Read-JsonFile -Path $manifestFull
    $config = Read-JsonFile -Path $configFull

    foreach ($item in @(Test-GovernanceContractSemantics -Root $root -Manifest $manifest -Config $config -ExpectedRepository $ExpectedRepository -ExpectedStandardsRepository $ExpectedStandardsRepository -RepositoryOwnerType $RepositoryOwnerType -ExpectedGovernanceCommitSha $ExpectedGovernanceCommitSha -ExpectedWorkflowInterfaceVersion $ExpectedWorkflowInterfaceVersion -ExpectedWorkflowProfile $ExpectedWorkflowProfile -ExpectedRequiredCheckName $ExpectedRequiredCheckName -ValidationDateUtc $ValidationDateUtc)) {
        $results.Add($item)
    }

    foreach ($doc in @($config.requiredDocumentationPaths)) {
        try {
            $resolved = Resolve-SafePath -Root $root -ChildPath $doc
            if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Required documentation missing.' -Path $doc))
            }
        }
        catch {
            $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $doc))
        }
    }

    foreach ($standard in @($config.applicableAgentStandards + $manifest.applicableStandards | Select-Object -Unique)) {
        try {
            $resolved = Resolve-SafePath -Root $root -ChildPath $standard -AllowMissingLeaf
            $centralResolved = Resolve-SafePath -Root $standardsRoot -ChildPath $standard -AllowMissingLeaf
            if (-not ((Test-Path -LiteralPath $resolved -PathType Leaf) -or (Test-Path -LiteralPath $centralResolved -PathType Leaf))) {
                $results.Add((New-ValidationResult -Status Failed -Message 'Applicable agent standard missing.' -Path $standard))
            }
        }
        catch {
            $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path $standard))
        }
    }

    try {
        $completionEvidencePath = if ($manifest.schemaVersion -eq '1.2.0') { $manifest.evidence.local.completion } else { $manifest.evidence.completionEvidencePath }
        $testEvidencePath = if ($manifest.schemaVersion -eq '1.2.0') { $manifest.evidence.local.tests } else { $manifest.evidence.testEvidencePath }
        $completionEvidence = Resolve-SafePath -Root $root -ChildPath $completionEvidencePath -AllowMissingLeaf
        $testEvidence = Resolve-SafePath -Root $root -ChildPath $testEvidencePath -AllowMissingLeaf
        if (-not $completionEvidence.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Completion evidence path must target a JSON file.' -Path $completionEvidencePath))
        }
        if (-not $testEvidence.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Test evidence path must target a JSON file.' -Path $testEvidencePath))
        }
    }
    catch {
        $results.Add((New-ValidationResult -Status Failed -Message $_.Exception.Message -Path 'project-manifest.json'))
    }

    foreach ($exception in @($manifest.exceptions + $config.exceptions)) {
        $identifier = if ($exception -is [string]) { $exception } else { $exception.identifier }
        if ($identifier -notmatch '^GOV-[A-Z0-9-]+$') {
            $results.Add((New-ValidationResult -Status Failed -Message "Invalid exception reference '$identifier'." -Path $ConfigPath))
        }
    }

    if ([string]::Equals($root, $standardsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        & pwsh -NoProfile -File (Join-Path $standardsRoot 'scripts/Test-DocumentationCompleteness.ps1') -Path $root | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $results.Add((New-ValidationResult -Status Failed -Message 'Documentation completeness validation failed.' -Path $root))
        }
    }
    else {
        $results.Add((New-ValidationResult -Status Passed -Message 'Downstream documentation paths and agent standards validated from governance config.' -Path $root -Severity info))
    }
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    $results.Add((New-ValidationResult -Status Passed -Message 'Contract validation completed.' -Path $root -Severity info))
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0 -and -not $Advisory) { exit 1 }
exit 0
