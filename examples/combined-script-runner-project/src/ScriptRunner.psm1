Set-StrictMode -Version Latest

function Get-RunnerCatalog {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$CatalogPath)

    Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json -Depth 20
}

function New-RunnerJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Catalog,
        [Parameter(Mandatory)][hashtable]$Request
    )

    $scriptId = [string]$Request.scriptId
    $tenantId = [string]$Request.tenantId
    $requestId = [string]$Request.requestId

    $scriptRecord = @($Catalog.scripts | Where-Object id -eq $scriptId | Select-Object -First 1)
    if ($scriptRecord.Count -ne 1) {
        throw "Script '$scriptId' is not approved."
    }
    if ($Request.ContainsKey('commandText')) {
        throw 'Arbitrary command text is prohibited.'
    }

    [ordered]@{
        jobId = "job-$requestId"
        requestId = $requestId
        tenantId = $tenantId
        scriptId = $scriptId
        state = 'Queued'
        idempotencyKey = "$tenantId/$requestId/$scriptId"
        attempts = 0
        duplicateHandling = 'return-existing-job'
        artifactState = 'Pending'
        leaseOwner = $null
    }
}

function Claim-RunnerJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Job,
        [Parameter(Mandatory)][string]$WorkerId
    )

    if ($Job.state -eq 'Completed') {
        throw 'Completed jobs cannot be claimed again.'
    }
    if ($Job.leaseOwner) {
        throw 'Job is already leased.'
    }

    $Job.state = 'Running'
    $Job.leaseOwner = $WorkerId
    $Job.attempts = [int]$Job.attempts + 1
    $Job
}

function Complete-RunnerJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Job,
        [Parameter(Mandatory)][string]$ReportDirectory
    )

    $tempPath = Join-Path $ReportDirectory ($Job.jobId + '.tmp.json')
    $finalPath = Join-Path $ReportDirectory ($Job.jobId + '.json')
    New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null

    $report = [ordered]@{
        jobId = $Job.jobId
        requestId = $Job.requestId
        tenantId = $Job.tenantId
        scriptId = $Job.scriptId
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        status = 'Completed'
    }

    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tempPath -Encoding utf8
    Move-Item -LiteralPath $tempPath -Destination $finalPath -Force

    $Job.state = 'Completed'
    $Job.artifactState = 'Final'
    $Job.leaseOwner = $null
    $Job.reportPath = $finalPath
    $Job
}

Export-ModuleMember -Function @(
    'Get-RunnerCatalog',
    'New-RunnerJob',
    'Claim-RunnerJob',
    'Complete-RunnerJob'
)
