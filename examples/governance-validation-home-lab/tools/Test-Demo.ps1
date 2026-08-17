<# .SYNOPSIS Validates the governance-validation lab. .DESCRIPTION Uses the shared deterministic runner. #>[CmdletBinding()]param()
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path;& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-HomeLabSkillDemo.ps1') -ProjectPath (Join-Path $PSScriptRoot '..') -SkillName governance-validation;exit $LASTEXITCODE
