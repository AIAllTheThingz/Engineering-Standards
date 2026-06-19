Set-StrictMode -Version Latest

function Invoke-ExampleGreeting {
    <#
    .SYNOPSIS
    Returns a deterministic greeting for a validated display name.
    .DESCRIPTION
    This sample command demonstrates the PowerShell standard used by governed
    repositories: strict mode, advanced function metadata, explicit validation,
    WhatIf support, and no secret or production data handling.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 80)]
        [ValidatePattern('^[\p{L}\p{N} ._-]+$')]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'
    $displayName = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        throw 'Name must contain at least one non-whitespace character.'
    }

    if ($PSCmdlet.ShouldProcess($displayName, 'Create sanitized greeting')) {
        "Hello, $displayName"
    }
}

Export-ModuleMember -Function Invoke-ExampleGreeting
