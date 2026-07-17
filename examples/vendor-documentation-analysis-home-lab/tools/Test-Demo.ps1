<# .SYNOPSIS Validates the vendor-documentation-analysis home lab. .DESCRIPTION Uses the deterministic shared runner. #>[CmdletBinding()]param()
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path;& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-HomeLabSkillDemo.ps1') -ProjectPath (Join-Path $PSScriptRoot '..') -SkillName vendor-documentation-analysis;exit $LASTEXITCODE
