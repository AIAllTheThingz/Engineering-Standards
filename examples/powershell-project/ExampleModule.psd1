@{
    RootModule = 'src/ExampleModule.psm1'
    ModuleVersion = '1.0.0'
    GUID = '2de8d10f-669f-47fd-92a8-87f2e3c6e611'
    Author = 'AIAllTheThingz'
    CompanyName = 'AIAllTheThingz'
    Copyright = '(c) AIAllTheThingz. All rights reserved.'
    Description = 'Functional example PowerShell module for Engineering Standards governance adoption.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @('Invoke-ExampleGreeting')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('governance', 'example', 'powershell')
            ProjectUri = 'https://github.com/AIAllTheThingz/Engineering-Standards'
        }
    }
}
