[CmdletBinding()]
param([string]$Path='.')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$migrations = Get-ChildItem -LiteralPath (Join-Path $Path 'migrations') -Filter '*.sql'
if (-not $migrations) { throw 'No migrations found.' }
foreach ($migration in $migrations) {
    $content = Get-Content -LiteralPath $migration.FullName -Raw
    if ($content -match '(?i)\bDROP\s+TABLE\b') { throw "Destructive statement found in $($migration.Name)." }
}
Write-Output 'Migration validation passed.'
