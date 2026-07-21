[CmdletBinding()]
param([string]$ProjectPath = (Join-Path $PSScriptRoot '..'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $ProjectPath).Path
& python (Join-Path $root 'tools/validate.py') --project $root
exit $LASTEXITCODE
