Describe 'Invoke-ExampleGreeting' {
    BeforeAll { . "$PSScriptRoot/../src/Invoke-Example.ps1" }
    Context 'normal execution' {
        It 'returns a sanitized greeting' {
            Invoke-ExampleGreeting -Name 'Example' | Should -Be 'Hello, Example'
        }
    }
    Context 'WhatIf support' {
        It 'does not throw when WhatIf is used' {
            { Invoke-ExampleGreeting -Name 'Example' -WhatIf } | Should -Not -Throw
        }
    }
}
