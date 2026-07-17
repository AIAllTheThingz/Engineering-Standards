<# .SYNOPSIS Validates the completion-evidence home lab. .DESCRIPTION Uses the deterministic shared runner. #>[CmdletBinding()]param()
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path;& pwsh -NoProfile -File (Join-Path $root 'scripts/Test-HomeLabSkillDemo.ps1') -ProjectPath (Join-Path $PSScriptRoot '..') -SkillName completion-evidence;exit $LASTEXITCODE
