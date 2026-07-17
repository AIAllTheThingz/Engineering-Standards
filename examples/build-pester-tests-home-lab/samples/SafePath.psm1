Set-StrictMode -Version Latest

function Resolve-SafeChildPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ChildPath
    )

    $rootPath = [IO.Path]::GetFullPath($Root)
    if (-not [IO.Path]::IsPathRooted($rootPath)) {
        throw 'Root must resolve to an absolute path.'
    }
    if ([IO.Path]::IsPathRooted($ChildPath)) {
        throw 'Child path must be relative and remain beneath the supplied root.'
    }

    $candidate = [IO.Path]::GetFullPath((Join-Path $rootPath $ChildPath))
    $separator = [IO.Path]::DirectorySeparatorChar
    $boundary = $rootPath.TrimEnd($separator, [IO.Path]::AltDirectorySeparatorChar) + $separator
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $candidate.StartsWith($boundary, $comparison)) {
        throw 'Child path escapes the supplied root.'
    }

    $candidate
}

Export-ModuleMember -Function Resolve-SafeChildPath
