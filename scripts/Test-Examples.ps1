<#
.SYNOPSIS
Validates Engineering Standards example projects.
.DESCRIPTION
Runs the repository-maintainer example suite only from this trusted standards
checkout. Downstream callers never execute their own scripts or examples through
the reusable governance workflow.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-Examples.ps1
.OUTPUTS
Tool output and a nonzero exit code on the first failed example command.
.NOTES
Generated build output remains excluded from commits by repository policy.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Assert-LastExitCode {
    param([Parameter(Mandatory)][string]$Name)
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE." }
}

& pwsh -NoProfile -File (Join-Path $root 'examples/powershell-project/tools/Test-Example.ps1')
Assert-LastExitCode -Name 'PowerShell example'
# The Python project has a dedicated hash-locked workflow because its functional
# toolchain is intentionally absent from the immutable governance harness.
& pwsh -NoProfile -File (Join-Path $root 'examples/powershell-review-home-lab/tools/Test-Demo.ps1')
Assert-LastExitCode -Name 'PowerShell review home-lab demo'
foreach ($homeLab in @(
    'bash-review',
    'build-pester-tests',
    'completion-evidence',
    'frameworks',
    'governance-validation',
    'infrastructure-automation-design',
    'networking',
    'operating-systems',
    'platforms',
    'python-review',
    'safe-automation',
    'terraform-review',
    'vendor-documentation-analysis',
    'virtualization'
)) {
    & pwsh -NoProfile -File (Join-Path $root "examples/$homeLab-home-lab/tools/Test-Demo.ps1")
    Assert-LastExitCode -Name "$homeLab home-lab demo"
}
& pwsh -NoProfile -File (Join-Path $root 'examples/database-project/tools/Test-Migrations.ps1') -Path (Join-Path $root 'examples/database-project')
Assert-LastExitCode -Name 'Database example'
& pwsh -NoProfile -File (Join-Path $root 'examples/integration-project/tools/Test-Example.ps1') -Path 'examples/integration-project'
Assert-LastExitCode -Name 'Integration example'
& pwsh -NoProfile -File (Join-Path $root 'examples/infrastructure-project/tools/Test-Example.ps1') -Path 'examples/infrastructure-project'
Assert-LastExitCode -Name 'Infrastructure example'
& pwsh -NoProfile -File (Join-Path $root 'examples/combined-script-runner-project/tools/Test-Example.ps1') -Path 'examples/combined-script-runner-project'
Assert-LastExitCode -Name 'Combined script-runner example'

$pester = Invoke-Pester -Path (Join-Path $root 'examples/worker-service-project/tests') -Output Detailed -PassThru
if ($pester.FailedCount -gt 0) { throw 'Worker-service example tests failed.' }

& dotnet build (Join-Path $root 'examples/dotnet-project/Example.Service.csproj') --configuration Release
Assert-LastExitCode -Name '.NET service build'
& dotnet build (Join-Path $root 'examples/dotnet-project/src/Example.csproj') --configuration Release
Assert-LastExitCode -Name '.NET library build'
& dotnet run --project (Join-Path $root 'examples/dotnet-project/tests/Example.Service.Tests.csproj') --configuration Release
Assert-LastExitCode -Name '.NET example tests'

$webRoot = Join-Path $root 'examples/web-project'
& npm ci --prefix $webRoot
Assert-LastExitCode -Name 'Web dependency restore'
& npm run lint --prefix $webRoot
Assert-LastExitCode -Name 'Web lint'
& npm test --prefix $webRoot
Assert-LastExitCode -Name 'Web tests'
& npm run build --prefix $webRoot
Assert-LastExitCode -Name 'Web build'
exit 0
