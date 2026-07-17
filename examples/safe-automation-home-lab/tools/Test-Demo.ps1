<# .SYNOPSIS Validates the safe-automation home-lab demo. .DESCRIPTION Delegates to the deterministic shared runner. #>
[CmdletBinding()]param()
$root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-HomeLabSkillDemo.ps1') -ProjectPath (Join-Path $PSScriptRoot '..') -SkillName safe-automation
exit $LASTEXITCODE
