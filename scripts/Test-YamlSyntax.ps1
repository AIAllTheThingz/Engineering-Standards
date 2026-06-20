<#
.SYNOPSIS
Validates repository YAML syntax.
.DESCRIPTION
Parses GitHub workflow, workflow-template, issue-form, and template YAML files
with Python and PyYAML. The script expects PyYAML to be installed by the caller
using a pinned version, such as PyYAML 6.0.2. It produces structured validation
results and returns a nonzero exit code when YAML parsing fails.
.PARAMETER Path
Repository root path.
.PARAMETER OutputJson
Optional JSON report path.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-YamlSyntax.ps1 -Path .
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()
$yamlFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $root '.github') -Recurse -File -Include *.yml,*.yaml -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath (Join-Path $root 'workflows') -Recurse -File -Include *.yml,*.yaml -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath (Join-Path $root 'templates') -Recurse -File -Include *.yml,*.yaml -ErrorAction SilentlyContinue
    Get-ChildItem -LiteralPath (Join-Path $root 'examples') -Recurse -File -Include *.yml,*.yaml -ErrorAction SilentlyContinue
) | Where-Object { $_ } | Sort-Object -Property FullName -Unique

$python = @'
import json
import pathlib
import sys

try:
    import yaml
except Exception as exc:
    print(json.dumps({"available": False, "error": str(exc)}))
    sys.exit(2)

class GithubActionsLoader(yaml.SafeLoader):
    pass

for ch, resolvers in list(GithubActionsLoader.yaml_implicit_resolvers.items()):
    GithubActionsLoader.yaml_implicit_resolvers[ch] = [
        (tag, regexp) for tag, regexp in resolvers
        if tag != "tag:yaml.org,2002:bool"
    ]

files = sys.argv[1:]
parsed = []
failed = []
for item in files:
    try:
        with open(item, "r", encoding="utf-8") as handle:
            yaml.load(handle, Loader=GithubActionsLoader)
        parsed.append(item)
    except Exception as exc:
        failed.append({"path": item, "error": str(exc)})

print(json.dumps({
    "available": True,
    "pyyamlVersion": getattr(yaml, "__version__", "unknown"),
    "parsed": parsed,
    "failed": failed
}))
sys.exit(1 if failed else 0)
'@

$pythonFile = Join-Path ([System.IO.Path]::GetTempPath()) ("yaml-parse-" + [guid]::NewGuid() + ".py")
try {
    Set-Content -LiteralPath $pythonFile -Value $python -Encoding utf8
    $output = & python $pythonFile @($yamlFiles.FullName) 2>&1
    $exitCode = $LASTEXITCODE
}
finally {
    if (Test-Path -LiteralPath $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
}

try {
    $payload = ($output | Out-String).Trim() | ConvertFrom-Json
}
catch {
    $results.Add((New-ValidationResult -Status Failed -Message "YAML parser returned invalid output: $output" -Path $root))
    $payload = $null
}

if ($payload -and -not $payload.available) {
    $results.Add((New-ValidationResult -Status Failed -Message "PyYAML is unavailable: $($payload.error)" -Path $root))
}
elseif ($payload) {
    foreach ($file in @($payload.parsed)) {
        $rel = [System.IO.Path]::GetRelativePath($root, [string]$file).Replace('\','/')
        $results.Add((New-ValidationResult -Status Passed -Message "YAML parsed with PyYAML $($payload.pyyamlVersion)." -Path $rel -Severity info))
    }
    foreach ($failure in @($payload.failed)) {
        $rel = [System.IO.Path]::GetRelativePath($root, [string]$failure.path).Replace('\','/')
        $results.Add((New-ValidationResult -Status Failed -Message "YAML parse failed: $($failure.error)" -Path $rel))
    }
}

if ($yamlFiles.Count -eq 0) {
    $results.Add((New-ValidationResult -Status Failed -Message 'No YAML files were found for validation.' -Path $root))
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0 -or $exitCode -ne 0) { exit 1 }
exit 0
