<# .SYNOPSIS Validates the bash-review home-lab demo. .DESCRIPTION Delegates to the deterministic shared validator without sourcing or executing the unsafe Bash sample. #>
[CmdletBinding()]
param()
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-HomeLabSkillDemo.ps1') -ProjectPath (Join-Path $PSScriptRoot '..') -SkillName bash-review
exit $LASTEXITCODE
