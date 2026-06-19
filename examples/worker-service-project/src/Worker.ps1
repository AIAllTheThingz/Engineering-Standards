function Invoke-ExampleJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$JobId,
        [int]$Attempt = 1
    )
    Set-StrictMode -Version Latest
    if ($Attempt -lt 1) { throw 'Attempt must be positive.' }
    [ordered]@{ JobId = $JobId; State = 'Completed'; Attempt = $Attempt; IdempotencyKey = "job:$JobId" }
}
