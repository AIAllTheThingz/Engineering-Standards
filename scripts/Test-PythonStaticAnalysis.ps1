<#
.SYNOPSIS
Performs trusted, non-executing Python static analysis.
.DESCRIPTION
Enumerates bounded Python source as inert data, parses it with the trusted
standard-library AST helper, and runs the exact installed Ruff executable in
isolated, cache-free mode. Caller configuration and suppressions cannot weaken
the baseline.
#>
[CmdletBinding()]
param([string]$Path='.',[string]$OutputJson,[string]$AllowedOutputRoot,[ValidateSet('standards-maintainer','downstream')][string]$Profile='standards-maintainer',[string]$RuffPath=$env:VALIDATOR_RUFF_PATH,[string]$PythonPath=$env:VALIDATOR_PYTHON_PATH)
Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'StaticAnalysisTools.psm1') -Force
$root=(Resolve-Path -LiteralPath $Path).Path
$exclusions = if($Profile -eq 'standards-maintainer') { @('examples/python-review-home-lab/samples/unsafe_maintenance.py') } else { @() }
$findings=[Collections.Generic.List[object]]::new(); $status='Failed'; $tools=[ordered]@{}; $files=@()
try {
    if(-not $PythonPath){ $PythonPath=(Get-Command python -CommandType Application -ErrorAction Stop).Source }
    if(-not $RuffPath -or -not (Test-Path -LiteralPath $RuffPath -PathType Leaf)){ throw 'Trusted Ruff executable is unavailable; set VALIDATOR_RUFF_PATH to the verified installed executable.' }
    $files=@(Get-TrustedSourceFiles -Root $root -Language Python -ExcludedRelativePath $exclusions)
    $selected=@($files|Where-Object{-not $_.excluded}); $paths=@($selected.path)
    $ast=Invoke-BoundedProcess -FilePath $PythonPath -ArgumentList @('-I',(Join-Path $PSScriptRoot 'python-static-ast.py')) -StandardInput (ConvertTo-Json -InputObject @($paths) -Compress) -TimeoutSeconds 60
    if($ast.timedOut){ throw 'Python AST parsing timed out.' }; if($ast.exitCode -ne 0){ throw "Python AST parser failed: $($ast.stderr)" }
    foreach($item in @($ast.stdout|ConvertFrom-Json)){ $rel=[IO.Path]::GetRelativePath($root,$item.path).Replace('\','/'); $findings.Add([ordered]@{tool='PythonAST';rule='SyntaxError';path=$rel;line=$item.line;message=$item.message}) }
    $version=Invoke-BoundedProcess -FilePath $RuffPath -ArgumentList @('--version')
    if($version.exitCode -ne 0 -or $version.stdout.Trim() -ne 'ruff 0.15.22'){ throw "Trusted Ruff version mismatch; expected 'ruff 0.15.22'." }
    if($paths.Count){
        $args=@('check','--isolated','--no-cache','--output-format','json','--select','E9,F,B,S','--ignore-noqa','--no-fix')+$paths
        $ruff=Invoke-BoundedProcess -FilePath $RuffPath -ArgumentList $args -TimeoutSeconds 60
        if($ruff.timedOut){ throw 'Ruff timed out.' }; if($ruff.exitCode -notin @(0,1)){ throw "Ruff failed: $($ruff.stderr)" }
        foreach($item in @($ruff.stdout|ConvertFrom-Json)){
            $rel=[IO.Path]::GetRelativePath($root,$item.filename).Replace('\','/')
            $reviewedExecutorFinding = (
                $Profile -eq 'standards-maintainer' -and
                $item.code -eq 'S603' -and
                $item.message -eq '`subprocess` call: check for execution of untrusted input' -and
                "${rel}:$($item.location.row)" -in @(
                    'scripts/python-project-validation.py:126',
                    'scripts/Install-BashProjectToolchain.py:234',
                    'scripts/bash-project-validation.py:434'
                )
            )
            $reviewedHttpsFinding = (
                $Profile -eq 'standards-maintainer' -and
                $item.code -eq 'S310' -and
                $rel -eq 'scripts/Install-BashProjectToolchain.py' -and
                $item.location.row -eq 210 -and
                $item.message -eq 'Audit URL open for permitted schemes. Allowing use of `file:` or custom schemes is often unexpected.'
            )
            if($reviewedExecutorFinding -or $reviewedHttpsFinding){ continue }
            $findings.Add([ordered]@{tool='Ruff';rule=$item.code;path=$rel;line=$item.location.row;message=$item.message})
        }
    }
    $tools.python=[ordered]@{pathHash=(Get-FileHash -LiteralPath $PythonPath -Algorithm SHA256).Hash.ToLowerInvariant()}; $tools.ruff=[ordered]@{version='0.15.22';sha256=(Get-FileHash -LiteralPath $RuffPath -Algorithm SHA256).Hash.ToLowerInvariant()}
    $status=if($findings.Count){'Failed'}else{'Passed'}
} catch { $findings.Add([ordered]@{tool='Validator';rule='PYV001';path='.';line=0;message=$_.Exception.Message}); $status=if($_.Exception.Message -match 'unavailable|timed out'){'Blocked'}else{'Failed'} }
$report=[ordered]@{schemaVersion='1.0.0';status=$status;profile=$Profile;files=@($files|ForEach-Object{[ordered]@{path=$_.relativePath;bytes=$_.bytes;excluded=$_.excluded}});exclusions=@($exclusions);tools=$tools;findings=@($findings|Select-Object -First 500)}
if($OutputJson){$out=if([IO.Path]::IsPathRooted($OutputJson)){[IO.Path]::GetFullPath($OutputJson)}else{[IO.Path]::GetFullPath((Join-Path $root $OutputJson))};$outputRoot=if($AllowedOutputRoot){[IO.Path]::GetFullPath($AllowedOutputRoot)}else{$root};if(-not $out.StartsWith($outputRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::Ordinal)){throw 'OutputJson must remain beneath the allowed output root.'}; New-Item -ItemType Directory -Path (Split-Path $out -Parent) -Force|Out-Null; $report|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $out -Encoding utf8}
"[$status] PythonStaticAnalysis: $($findings.Count) finding(s)."; if($status -eq 'Passed'){exit 0}; if($status -eq 'Blocked'){exit 3}; exit 1
