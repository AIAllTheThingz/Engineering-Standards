Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TrustedSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][ValidateSet('Python','Bash')][string]$Language,
        [string[]]$ExcludedRelativePath = @(),
        [int]$MaximumFileCount = 2000,
        [long]$MaximumBytesPerFile = 1048576,
        [long]$MaximumAggregateBytes = 52428800,
        [int]$MaximumPathLength = 512
    )
    $rootPath = (Resolve-Path -LiteralPath $Root).Path
    $rootItem = Get-Item -LiteralPath $rootPath -Force
    if (-not $rootItem.PSIsContainer -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Validation root must be a real directory, not a link or reparse point.' }
    $ignored = @('.git','.venv','venv','site-packages','.tox','.nox','__pycache__','build','dist','coverage','TestResults','node_modules','bin','obj','.tmp','evidence')
    $excluded = @{}; foreach ($path in $ExcludedRelativePath) { $excluded[$path.Replace('\','/')] = $true }
    $files = [Collections.Generic.List[object]]::new(); [long]$aggregate = 0
    foreach ($item in Get-ChildItem -LiteralPath $rootPath -File -Recurse -Force) {
        $relative = [IO.Path]::GetRelativePath($rootPath,$item.FullName).Replace('\','/')
        $parts = $relative.Split('/')
        if (@($parts | Where-Object { $_ -in $ignored }).Count -gt 0) { continue }
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Source '$relative' is a link or reparse point." }
        $selected = if ($Language -eq 'Python') { $item.Extension -in @('.py','.pyi') } else { $item.Extension -in @('.sh','.bash') }
        if (-not $selected -and $Language -eq 'Bash' -and -not $item.Extension -and $item.Length -le $MaximumBytesPerFile) {
            $reader = [IO.StreamReader]::new($item.FullName,$true)
            try { $selected = ($reader.ReadLine() -match '^#!\s*(?:/usr/bin/env\s+(?:-S\s+)?|/bin/|/usr/bin/)bash(?:\s|$)') } finally { $reader.Dispose() }
        }
        if (-not $selected) { continue }
        if ($relative.Length -gt $MaximumPathLength) { throw "Source path exceeds the $MaximumPathLength character limit: '$relative'." }
        if ($item.Length -gt $MaximumBytesPerFile) { throw "Source '$relative' exceeds the $MaximumBytesPerFile byte limit." }
        if ($excluded.ContainsKey($relative)) { $files.Add([ordered]@{ path=$item.FullName; relativePath=$relative; bytes=$item.Length; excluded=$true }); continue }
        $aggregate += $item.Length
        if ($aggregate -gt $MaximumAggregateBytes) { throw "Selected source exceeds the $MaximumAggregateBytes aggregate byte limit." }
        $files.Add([ordered]@{ path=$item.FullName; relativePath=$relative; bytes=$item.Length; excluded=$false })
        if (@($files | Where-Object { -not $_.excluded }).Count -gt $MaximumFileCount) { throw "Selected source exceeds the $MaximumFileCount file limit." }
    }
    @($files)
}

function Invoke-BoundedProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FilePath,[Parameter(Mandatory)][string[]]$ArgumentList,[string]$StandardInput,[int]$TimeoutSeconds=60,[int]$MaximumOutputBytes=1048576,[hashtable]$Environment=@{})
    $resolved = (Resolve-Path -LiteralPath $FilePath).Path
    $start = [Diagnostics.ProcessStartInfo]::new(); $start.FileName=$resolved; $start.UseShellExecute=$false; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true; $start.RedirectStandardInput=$true
    foreach($argument in $ArgumentList){ [void]$start.ArgumentList.Add($argument) }
    foreach($key in $Environment.Keys){ $start.Environment[$key]=[string]$Environment[$key] }
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start; [void]$process.Start()
    if($null -ne $StandardInput){ $process.StandardInput.Write($StandardInput) }; $process.StandardInput.Close()
    $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit($TimeoutSeconds*1000)){ $process.Kill($true); $process.WaitForExit(); return [ordered]@{ exitCode=$null; timedOut=$true; stdout=''; stderr='Tool timed out.' } }
    $stdout=$stdoutTask.Result; $stderr=$stderrTask.Result
    if(([Text.Encoding]::UTF8.GetByteCount($stdout)+[Text.Encoding]::UTF8.GetByteCount($stderr)) -gt $MaximumOutputBytes){ throw "Tool output exceeded the $MaximumOutputBytes byte limit." }
    [ordered]@{exitCode=$process.ExitCode;timedOut=$false;stdout=$stdout;stderr=$stderr}
}

Export-ModuleMember -Function Get-TrustedSourceFiles,Invoke-BoundedProcess
