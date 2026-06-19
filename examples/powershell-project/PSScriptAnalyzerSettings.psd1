@{
    Severity = @('Error', 'Warning')
    Rules = @{
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $true
        }
        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }
    }
    ExcludeRules = @()
}
