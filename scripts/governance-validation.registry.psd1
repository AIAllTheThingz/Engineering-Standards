@{
    SchemaVersion = '1.0.0'

    Profiles = @{
        'standards-maintainer' = @{
            Description = 'Complete validation for the trusted Engineering Standards repository.'
            ExecutesRepositoryCode = $true
            TrustModel = 'Runs only after the repository identity matches the Engineering Standards maintainer profile. Candidate code executes only in the isolated, read-only candidate harness.'
        }
        downstream = @{
            Description = 'Trusted central static validation of an untrusted downstream repository.'
            ExecutesRepositoryCode = $false
            TrustModel = 'Loads validators only from the trusted standards checkout and treats caller files as inert data. Caller scripts, tests, examples, package commands, and modules are never executed.'
        }
    }

    Categories = @(
        @{
            Name = 'Contract'
            Order = 10
            Profiles = @('standards-maintainer', 'downstream')
            MandatoryProfiles = @('standards-maintainer', 'downstream')
            Runner = 'Script'
            Path = 'actions/validate-contract/Invoke-ContractValidation.ps1'
            Applicability = 'Always'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'AgentStandards'
            Order = 20
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Test-AgentStandards.ps1'
            Applicability = 'Always'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'CodexSkills'
            Order = 30
            Profiles = @('standards-maintainer', 'downstream')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Test-CodexSkills.ps1'
            Applicability = 'WhenSkillsPresent'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'JsonSchemas'
            Order = 40
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Test-JsonSchemas.ps1'
            Applicability = 'Always'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'YamlSyntax'
            Order = 50
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Test-YamlSyntax.ps1'
            Applicability = 'Always'
            RequiredCommands = @('python')
            RequiredPythonModules = @('yaml')
        }
        @{
            Name = 'WorkflowArchitecture'
            Order = 60
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Test-GitHubWorkflowArchitecture.ps1'
            Applicability = 'Always'
            RequiredCommands = @('python')
            RequiredPythonModules = @('yaml')
        }
        @{
            Name = 'MarkdownLinks'
            Order = 70
            Profiles = @('standards-maintainer', 'downstream')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Test-MarkdownLinks.ps1'
            Applicability = 'Always'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'DocumentationCompleteness'
            Order = 80
            Profiles = @('standards-maintainer', 'downstream')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Test-DocumentationCompleteness.ps1'
            Applicability = 'Always'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'ForbiddenPatterns'
            Order = 90
            Profiles = @('standards-maintainer', 'downstream')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1'
            Applicability = 'Always'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'RepositoryHealth'
            Order = 100
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'actions/repository-health/Invoke-RepositoryHealth.ps1'
            Applicability = 'Always'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'Evidence'
            Order = 110
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'actions/validate-evidence/Invoke-EvidenceValidation.ps1'
            Applicability = 'Always'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'PowerShellParser'
            Order = 120
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'PowerShellParser'
            Path = $null
            Applicability = 'WhenPowerShellPresent'
            RequiredCommands = @()
            RequiredPythonModules = @()
        }
        @{
            Name = 'Pester'
            Order = 130
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Invoke-PesterSuite.ps1'
            Applicability = 'Always'
            RequiredCommands = @('Invoke-Pester')
            RequiredPythonModules = @()
        }
        @{
            Name = 'PSScriptAnalyzer'
            Order = 140
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'PSScriptAnalyzer'
            Path = $null
            Applicability = 'WhenPowerShellPresent'
            RequiredCommands = @('Invoke-ScriptAnalyzer')
            RequiredPythonModules = @()
        }
        @{
            Name = 'Examples'
            Order = 150
            Profiles = @('standards-maintainer')
            MandatoryProfiles = @('standards-maintainer')
            Runner = 'Script'
            Path = 'scripts/Test-Examples.ps1'
            Applicability = 'Always'
            RequiredCommands = @('Invoke-Pester', 'dotnet', 'npm', 'python')
            RequiredPythonModules = @('yaml')
        }
    )
}
