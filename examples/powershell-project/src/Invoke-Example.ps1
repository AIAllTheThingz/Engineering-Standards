function Invoke-ExampleGreeting {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    if ($PSCmdlet.ShouldProcess($Name, 'Create sanitized greeting')) {
        "Hello, $Name"
    }
}
