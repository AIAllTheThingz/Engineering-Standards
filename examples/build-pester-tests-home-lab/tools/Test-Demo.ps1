<# .SYNOPSIS Validates the build-pester-tests lab demo. .DESCRIPTION Delegates to the repository's deterministic, secret-free lab validator. #>
[CmdletBinding()]
param()
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-HomeLabSkillDemo.ps1') -ProjectPath (Join-Path $PSScriptRoot '..') -SkillName build-pester-tests
exit $LASTEXITCODE
