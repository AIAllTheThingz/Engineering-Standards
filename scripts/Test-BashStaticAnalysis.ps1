<#
.SYNOPSIS
Performs trusted, non-executing Bash static analysis.
.DESCRIPTION
Enumerates bounded Bash source as inert data, runs the trusted Bash parser with
startup loading disabled and no execution, then runs the exact verified
ShellCheck executable without caller configuration or external source loading.
#>
[CmdletBinding()]
param([string]$Path='.',[string]$OutputJson,[string]$AllowedOutputRoot,[ValidateSet('standards-maintainer','downstream')][string]$Profile='standards-maintainer',[string]$ShellCheckPath=$env:VALIDATOR_SHELLCHECK_PATH,[string]$BashPath=$env:VALIDATOR_BASH_PATH)
Set-StrictMode -Version Latest; $ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'StaticAnalysisTools.psm1') -Force
$root=(Resolve-Path -LiteralPath $Path).Path
$exclusions=if($Profile -eq 'standards-maintainer'){@('examples/bash-review-home-lab/samples/unsafe-maintenance.sh')}else{@()}
$findings=[Collections.Generic.List[object]]::new(); $status='Failed'; $tools=[ordered]@{}; $files=@()
try {
    if(-not $BashPath){$BashPath=(Get-Command bash -CommandType Application -ErrorAction Stop).Source}
    if(-not $ShellCheckPath -or -not(Test-Path -LiteralPath $ShellCheckPath -PathType Leaf)){throw 'Trusted ShellCheck executable is unavailable; set VALIDATOR_SHELLCHECK_PATH to the verified installed executable.'}
    $bashVersion=Invoke-BoundedProcess -FilePath $BashPath -ArgumentList @('--noprofile','--norc','-c','printf %s "$BASH_VERSION"') -Environment @{BASH_ENV='';ENV=''}
    if($bashVersion.exitCode -ne 0 -or $bashVersion.stdout -notmatch '^(?<v>\d+)\.'){throw 'Trusted Bash parser version could not be verified.'}; if([int]$Matches.v -lt 4){throw 'Bash 4.0 or later is required.'}
    $scVersion=Invoke-BoundedProcess -FilePath $ShellCheckPath -ArgumentList @('--version'); if($scVersion.exitCode -ne 0 -or $scVersion.stdout -notmatch '(?m)^version:\s+0\.11\.0$'){throw 'Trusted ShellCheck version mismatch; expected 0.11.0.'}
    $files=@(Get-TrustedSourceFiles -Root $root -Language Bash -ExcludedRelativePath $exclusions)
    foreach($file in @($files|Where-Object{-not $_.excluded})){
        $syntax=Invoke-BoundedProcess -FilePath $BashPath -ArgumentList @('--noprofile','--norc','-n',$file.path) -TimeoutSeconds 30 -Environment @{BASH_ENV='';ENV='';SHELLOPTS=''}
        if($syntax.timedOut){throw "Bash parsing timed out for '$($file.relativePath)'."}; if($syntax.exitCode -ne 0){$findings.Add([ordered]@{tool='Bash';rule='SyntaxError';path=$file.relativePath;line=0;message=$syntax.stderr.Trim()})}
        $shell=Invoke-BoundedProcess -FilePath $ShellCheckPath -ArgumentList @('--format=json1','--severity=warning','--external-sources=false','--source-path=SCRIPTDIR','--rcfile=/dev/null','--enable=all',$file.path) -TimeoutSeconds 30
        if($shell.timedOut){throw "ShellCheck timed out for '$($file.relativePath)'."}; if($shell.exitCode -notin @(0,1)){throw "ShellCheck failed: $($shell.stderr)"}
        if($shell.stdout.Trim()){foreach($comment in @(($shell.stdout|ConvertFrom-Json).comments)){ $findings.Add([ordered]@{tool='ShellCheck';rule="SC$($comment.code)";path=$file.relativePath;line=$comment.line;message=$comment.message}) }}
        foreach($line in Get-Content -LiteralPath $file.path){if($line -match 'shellcheck\s+(?:disable|source)='){$findings.Add([ordered]@{tool='Validator';rule='BASH001';path=$file.relativePath;line=0;message='ShellCheck suppression or source directives are not permitted in the mandatory baseline.'});break}}
    }
    $tools.bash=[ordered]@{version=$bashVersion.stdout;sha256=(Get-FileHash -LiteralPath $BashPath -Algorithm SHA256).Hash.ToLowerInvariant()}; $tools.shellcheck=[ordered]@{version='0.11.0';sha256=(Get-FileHash -LiteralPath $ShellCheckPath -Algorithm SHA256).Hash.ToLowerInvariant()}; $status=if($findings.Count){'Failed'}else{'Passed'}
}catch{$findings.Add([ordered]@{tool='Validator';rule='BSV001';path='.';line=0;message=$_.Exception.Message});$status=if($_.Exception.Message -match 'unavailable|timed out'){'Blocked'}else{'Failed'}}
$report=[ordered]@{schemaVersion='1.0.0';status=$status;profile=$Profile;files=@($files|ForEach-Object{[ordered]@{path=$_.relativePath;bytes=$_.bytes;excluded=$_.excluded}});exclusions=@($exclusions);tools=$tools;findings=@($findings|Select-Object -First 500)}
if($OutputJson){$out=if([IO.Path]::IsPathRooted($OutputJson)){[IO.Path]::GetFullPath($OutputJson)}else{[IO.Path]::GetFullPath((Join-Path $root $OutputJson))};$outputRoot=if($AllowedOutputRoot){[IO.Path]::GetFullPath($AllowedOutputRoot)}else{$root};if(-not $out.StartsWith($outputRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::Ordinal)){throw 'OutputJson must remain beneath the allowed output root.'};New-Item -ItemType Directory -Path (Split-Path $out -Parent) -Force|Out-Null;$report|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $out -Encoding utf8}
"[$status] BashStaticAnalysis: $($findings.Count) finding(s).";if($status -eq 'Passed'){exit 0};if($status -eq 'Blocked'){exit 3};exit 1
