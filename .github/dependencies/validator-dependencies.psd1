@{
    SchemaVersion = '1.0.0'
    Runner = @{
        Label = 'ubuntu-24.04'
        Architecture = 'X64'
    }
    Runtimes = @{
        PowerShell = @{
            Version = '7.4.11'
            PackageFile = 'powershell-7.4.11-linux-x64.tar.gz'
            SourceUri = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.11/powershell-7.4.11-linux-x64.tar.gz'
            Sha256 = '55c5429d32256fa0cec4c2529856679f684a41525d78071f78b0fbf1fc3d1f0a'
        }
        Python = @{
            Version = '3.12.11'
            SetupAction = 'actions/setup-python'
            ActionSha = 'ece7cb06caefa5fff74198d8649806c4678c61a1'
        }
        Node = @{
            Version = '22.17.0'
            SetupAction = 'actions/setup-node'
            ActionSha = '820762786026740c76f36085b0efc47a31fe5020'
        }
        DotNet = @{
            Version = '8.0.411'
            SetupAction = 'actions/setup-dotnet'
            ActionSha = '26b0ec14cb23fa6904739307f278c14f94c95bf1'
        }
    }
    Packages = @(
        @{
            Name = 'PyYAML'
            Ecosystem = 'Python'
            Version = '6.0.2'
            SourceUri = 'https://pypi.org/simple'
            PackageFile = 'PyYAML-6.0.2-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'
            Sha256 = '80bab7bfc629882493af4aa31a4cfa43a4c57c83813253626916b8c7ada83476'
            Purl = 'pkg:pypi/pyyaml@6.0.2'
        }
        @{
            Name = 'Pester'
            Ecosystem = 'PowerShell'
            Version = '5.7.1'
            SourceUri = 'https://www.powershellgallery.com/api/v2/package/Pester/5.7.1'
            PackageFile = 'Pester.5.7.1.nupkg'
            Sha256 = '4a27904c6814a5fbe4758f8e49861f6a1994aee77b71165a5c43c0371ba6c580'
            ManifestPath = 'Pester.psd1'
            Purl = 'pkg:nuget/Pester@5.7.1'
        }
        @{
            Name = 'PSScriptAnalyzer'
            Ecosystem = 'PowerShell'
            Version = '1.22.0'
            SourceUri = 'https://www.powershellgallery.com/api/v2/package/PSScriptAnalyzer/1.22.0'
            PackageFile = 'PSScriptAnalyzer.1.22.0.nupkg'
            Sha256 = '71bfb9eb58e19d4b662f4494a7d572a724b60e0588848dcff34195a0e08ae1be'
            ManifestPath = 'PSScriptAnalyzer.psd1'
            Purl = 'pkg:nuget/PSScriptAnalyzer@1.22.0'
        }
    )
}
