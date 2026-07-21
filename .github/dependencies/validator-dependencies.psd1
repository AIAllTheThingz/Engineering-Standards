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
            ActionSha = '5fda3b95a4ea91299a34e894583c3862153e4b97'
        }
        Node = @{
            Version = '22.17.0'
            SetupAction = 'actions/setup-node'
            ActionSha = '820762786026740c76f36085b0efc47a31fe5020'
        }
        DotNet = @{
            Version = '8.0.411'
            SetupAction = 'actions/setup-dotnet'
            ActionSha = 'a98b56852c35b8e3190ac28c8c2271da59106c68'
        }
    }
    Packages = @(
        @{
            Name = 'PyYAML'
            Ecosystem = 'Python'
            InstallationKind = 'PythonWheel'
            Version = '6.0.2'
            SourceUri = 'https://files.pythonhosted.org/packages/b9/2b/614b4752f2e127db5cc206abc23a8c19678e92b23c3db30fc86ab731d3bd/PyYAML-6.0.2-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'
            PackageIndexUri = 'https://pypi.org/simple'
            PackageFile = 'PyYAML-6.0.2-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'
            Sha256 = '80bab7bfc629882493af4aa31a4cfa43a4c57c83813253626916b8c7ada83476'
            Purl = 'pkg:pypi/pyyaml@6.0.2'
        }
        @{
            Name = 'Ruff'
            Ecosystem = 'Python'
            InstallationKind = 'PythonWheel'
            Version = '0.15.22'
            SourceUri = 'https://files.pythonhosted.org/packages/f6/f9/a0d4871d12fae702eb1f41b686caf05f1f8b124dc6db6f784f53d74918fa/ruff-0.15.22-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'
            PackageIndexUri = 'https://pypi.org/simple'
            PackageFile = 'ruff-0.15.22-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl'
            Sha256 = '365523eb91d9224e1bcb03b022fbf0facb8f9e23792a2c53d9d4b3924bdbdebb'
            Purl = 'pkg:pypi/ruff@0.15.22'
        }
        @{
            Name = 'ShellCheck'
            Ecosystem = 'BinaryTool'
            InstallationKind = 'TarXzExecutable'
            Version = '0.11.0'
            SourceUri = 'https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz'
            PackageFile = 'shellcheck-v0.11.0.linux.x86_64.tar.xz'
            Sha256 = '8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198'
            Purl = 'pkg:github/koalaman/shellcheck@v0.11.0'
        }
        @{
            Name = 'Pester'
            Ecosystem = 'PowerShell'
            InstallationKind = 'PowerShellModule'
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
            InstallationKind = 'PowerShellModule'
            Version = '1.22.0'
            SourceUri = 'https://www.powershellgallery.com/api/v2/package/PSScriptAnalyzer/1.22.0'
            PackageFile = 'PSScriptAnalyzer.1.22.0.nupkg'
            Sha256 = '71bfb9eb58e19d4b662f4494a7d572a724b60e0588848dcff34195a0e08ae1be'
            ManifestPath = 'PSScriptAnalyzer.psd1'
            Purl = 'pkg:nuget/PSScriptAnalyzer@1.22.0'
        }
    )
}
