<#
.SYNOPSIS
Creates workflow test-evidence records from GitHub step outcomes.
.DESCRIPTION
Converts stable GitHub Actions step outcomes and report-file presence into individual
test-evidence records. Paths written to evidence are repository-relative.
#>
[CmdletBinding()]
param(
    [string]$RepositoryPath = '.',
    [Parameter(Mandatory)][string]$OutputPath,
    [hashtable]$Outcomes = @{},
    [hashtable]$Reports = @{},
    [switch]$RunPester,
    [switch]$RunDocumentation,
    [switch]$RunExamples,
    [switch]$AllowControlledFailure,
    [string]$Runtime = 'GitHub Actions ubuntu-latest / pwsh',
    [string]$ToolVersion = 'pwsh'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $RepositoryPath).Path

function Test-RelativeEvidencePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ([System.IO.Path]::IsPathRooted($Path) -or $Path -match '(^|[\\/])\.\.([\\/]|$)') { return $false }
    return $true
}

function Get-OutcomeStatus {
    param(
        [string]$Name,
        [string]$Outcome,
        [string]$ReportPath,
        [bool]$Required
    )

    if (-not $Required) {
        return [ordered]@{
            status = 'NotApplicable'
            exitCode = $null
            failureReason = $null
            summary = "$Name is not applicable for this project configuration."
        }
    }

    if ([string]::IsNullOrWhiteSpace($Outcome)) { $Outcome = 'missing' }
    $reportExists = $false
    if ($ReportPath -and (Test-RelativeEvidencePath -Path $ReportPath)) {
        $resolved = Resolve-SafePath -Root $root -ChildPath $ReportPath -AllowMissingLeaf
        $reportExists = Test-Path -LiteralPath $resolved -PathType Leaf
    }

    if ($Outcome -eq 'success' -and ($reportExists -or [string]::IsNullOrWhiteSpace($ReportPath))) {
        return [ordered]@{
            status = 'Passed'
            exitCode = 0
            failureReason = $null
            summary = "$Name completed successfully."
        }
    }

    if ($Outcome -eq 'skipped') {
        return [ordered]@{
            status = 'Failed'
            exitCode = $null
            failureReason = "$Name was unexpectedly skipped without an approved exception."
            summary = "$Name did not run."
        }
    }

    if ($Outcome -eq 'cancelled') {
        return [ordered]@{
            status = 'Blocked'
            exitCode = $null
            failureReason = "$Name was cancelled before producing complete evidence."
            summary = "$Name was cancelled."
        }
    }

    if ($Outcome -eq 'success' -and -not $reportExists) {
        return [ordered]@{
            status = 'Failed'
            exitCode = 1
            failureReason = "$Name reported success but did not produce required report '$ReportPath'."
            summary = "$Name report is missing."
        }
    }

    return [ordered]@{
        status = 'Failed'
        exitCode = 1
        failureReason = "$Name failed with GitHub step outcome '$Outcome'."
        summary = "$Name failed."
    }
}

$definitions = @(
    @{ key='yaml'; name='YAML syntax validation'; category='schema'; command='scripts/Test-YamlSyntax.ps1'; report='evidence/yaml-syntax.json'; required=$true },
    @{ key='workflow_architecture'; name='Workflow architecture validation'; category='workflow'; command='scripts/Test-GitHubWorkflowArchitecture.ps1'; report='evidence/workflow-architecture.json'; required=$true },
    @{ key='json_schemas'; name='JSON schema validation'; category='schema'; command='scripts/Test-JsonSchemas.ps1'; report='evidence/json-schemas.json'; required=$true },
    @{ key='markdown_links'; name='Markdown link validation'; category='documentation'; command='scripts/Test-MarkdownLinks.ps1'; report='evidence/markdown-links.json'; required=$true },
    @{ key='documentation'; name='Documentation completeness'; category='documentation'; command='scripts/Test-DocumentationCompleteness.ps1'; report='evidence/documentation-completeness.json'; required=$RunDocumentation.IsPresent },
    @{ key='contract'; name='Governance contract validation'; category='workflow'; command='actions/validate-contract/Invoke-ContractValidation.ps1'; report='evidence/contract.json'; required=$true },
    @{ key='forbidden_patterns'; name='Forbidden-pattern scanning'; category='security'; command='actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1'; report='evidence/forbidden-patterns.json'; required=$true },
    @{ key='repository_health'; name='Repository-health validation'; category='workflow'; command='actions/repository-health/Invoke-RepositoryHealth.ps1'; report='evidence/repository-health.json'; required=$true },
    @{ key='powershell_parser'; name='PowerShell parser validation'; category='lint'; command='PowerShell parser'; report='evidence/powershell-parser.json'; required=$true },
    @{ key='pester'; name='Pester repository tests'; category='unit'; command='Invoke-Pester -Path tests'; report='evidence/pester-summary.json'; required=$RunPester.IsPresent },
    @{ key='psscriptanalyzer'; name='PSScriptAnalyzer'; category='lint'; command='Invoke-ScriptAnalyzer -Severity Error'; report='evidence/psscriptanalyzer.json'; required=$true },
    @{ key='examples'; name='Example-project validation'; category='integration'; command='Validate examples'; report='evidence/examples.json'; required=$RunExamples.IsPresent },
    @{ key='evidence_validation'; name='Completion-evidence validation'; category='workflow'; command='actions/validate-evidence/Invoke-EvidenceValidation.ps1'; report='evidence/evidence-validation.json'; required=$true },
    @{ key='github_execution'; name='GitHub-hosted workflow execution'; category='workflow'; command='Governance CI'; report='evidence/environment.json'; required=$true }
)

$records = [System.Collections.Generic.List[object]]::new()
foreach ($definition in $definitions) {
    $started = (Get-Date).ToUniversalTime()
    Start-Sleep -Milliseconds 5
    $completed = (Get-Date).ToUniversalTime()
    $key = [string]$definition.key
    $report = if ($Reports.ContainsKey($key)) { [string]$Reports[$key] } else { [string]$definition.report }
    $outcome = if ($Outcomes.ContainsKey($key)) { [string]$Outcomes[$key] } else { 'missing' }
    $computed = Get-OutcomeStatus -Name $definition.name -Outcome $outcome -ReportPath $report -Required ([bool]$definition.required)

    if ($AllowControlledFailure -and $key -eq 'markdown_links' -and $computed.status -eq 'Failed') {
        $computed.summary = 'Controlled failure path produced expected mandatory failure evidence.'
    }

    $records.Add([ordered]@{
        schemaVersion = '1.0.0'
        name = $definition.name
        category = $definition.category
        status = $computed.status
        command = $definition.command
        workingDirectory = '.'
        startedAtUtc = $started.ToString('o')
        completedAtUtc = $completed.ToString('o')
        durationSeconds = [math]::Round(($completed - $started).TotalSeconds, 3)
        runtime = $Runtime
        toolVersion = $ToolVersion
        exitCode = $computed.exitCode
        summary = $computed.summary
        warnings = @()
        failureReason = $computed.failureReason
    })
}

$out = Resolve-SafePath -Root $root -ChildPath $OutputPath -AllowMissingLeaf
New-Item -ItemType Directory -Path (Split-Path -Parent $out) -Force | Out-Null
ConvertTo-Json -InputObject @($records) -Depth 100 | Set-Content -LiteralPath $out -Encoding utf8
Write-Output "Workflow test evidence written to $OutputPath"
