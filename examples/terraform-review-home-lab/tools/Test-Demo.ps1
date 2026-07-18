<# .SYNOPSIS Validates the terraform-review home-lab demo. .DESCRIPTION Delegates to the deterministic shared validator without installing Terraform or accessing providers, backends, state, plans, or clouds. #>
[CmdletBinding()]
param()
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-HomeLabSkillDemo.ps1') -ProjectPath (Join-Path $PSScriptRoot '..') -SkillName terraform-review
exit $LASTEXITCODE
