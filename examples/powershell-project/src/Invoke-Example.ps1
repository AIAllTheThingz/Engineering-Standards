[CmdletBinding(SupportsShouldProcess)]
param([string]$Name = "Example")
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if ($PSCmdlet.ShouldProcess($Name, "Write sanitized greeting")) { Write-Output "Hello $Name" }
