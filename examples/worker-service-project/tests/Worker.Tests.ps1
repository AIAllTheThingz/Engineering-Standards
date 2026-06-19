Describe 'Invoke-ExampleJob' {
    BeforeAll { . "$PSScriptRoot/../src/Worker.ps1" }
    It 'returns a completed job state' {
        $result = Invoke-ExampleJob -JobId 'example'
        $result.State | Should -Be 'Completed'
        $result.IdempotencyKey | Should -Be 'job:example'
    }
}
