BeforeAll {
    Import-Module "$PSScriptRoot/../src/ScriptRunner.psm1" -Force
    $script:catalogPath = Join-Path $PSScriptRoot '../catalog/approved-scripts.json'
    $script:catalog = Get-RunnerCatalog -CatalogPath $script:catalogPath
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("runner-example-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
    }
}

Describe 'Script runner example' {
    It 'creates, claims, and completes an approved job' {
        $job = New-RunnerJob -Catalog $script:catalog -Request @{
            requestId = 'req-001'
            tenantId = 'tenant-a'
            scriptId = 'example-report'
        }
        $job.state | Should -Be 'Queued'

        $claimed = Claim-RunnerJob -Job $job -WorkerId 'worker-a'
        $claimed.state | Should -Be 'Running'

        $completed = Complete-RunnerJob -Job $claimed -ReportDirectory $script:tempRoot
        $completed.state | Should -Be 'Completed'
        Test-Path -LiteralPath $completed.reportPath | Should -BeTrue
    }

    It 'rejects arbitrary command text' {
        { New-RunnerJob -Catalog $script:catalog -Request @{
            requestId = 'req-002'
            tenantId = 'tenant-a'
            scriptId = 'example-report'
            commandText = 'Write-Host arbitrary-command'
        } } | Should -Throw
    }
}
