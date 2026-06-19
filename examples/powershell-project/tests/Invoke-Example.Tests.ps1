Describe 'Invoke-ExampleGreeting' {
    BeforeAll {
        $modulePath = Join-Path $PSScriptRoot '..\ExampleModule.psd1'
        Import-Module $modulePath -Force
    }

    Context 'normal execution' {
        It 'returns a deterministic greeting' {
            Invoke-ExampleGreeting -Name 'Example' | Should -Be 'Hello, Example'
        }

        It 'trims leading and trailing whitespace' {
            Invoke-ExampleGreeting -Name '  Example User  ' | Should -Be 'Hello, Example User'
        }
    }

    Context 'input validation' {
        It 'rejects unsupported characters' {
            { Invoke-ExampleGreeting -Name 'Example/User' } | Should -Throw
        }

        It 'rejects whitespace-only values after trimming' {
            { Invoke-ExampleGreeting -Name '   ' } | Should -Throw
        }
    }

    Context 'WhatIf support' {
        It 'does not emit a greeting when WhatIf is used' {
            Invoke-ExampleGreeting -Name 'Example' -WhatIf | Should -BeNullOrEmpty
        }
    }
}
