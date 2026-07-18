<# .SYNOPSIS Validates the python-review home-lab demo. .DESCRIPTION Delegates to the repository's deterministic, secret-free home-lab validator without importing or executing the unsafe Python sample. #>
[CmdletBinding()]
param()
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-HomeLabSkillDemo.ps1') -ProjectPath (Join-Path $PSScriptRoot '..') -SkillName python-review
exit $LASTEXITCODE
