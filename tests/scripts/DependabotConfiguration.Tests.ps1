Describe 'Dependabot configuration' {
    BeforeAll {
        $script:dependabotConfigPath = (Resolve-Path (Join-Path $PSScriptRoot '../../.github/dependabot.yml')).Path
        $script:dependabotParser = @'
import json
import sys

import yaml


class GithubActionsLoader(yaml.SafeLoader):
    pass


for ch, resolvers in list(GithubActionsLoader.yaml_implicit_resolvers.items()):
    GithubActionsLoader.yaml_implicit_resolvers[ch] = [
        (tag, regexp) for tag, regexp in resolvers
        if tag != "tag:yaml.org,2002:bool"
    ]


with open(sys.argv[1], "r", encoding="utf-8") as handle:
    print(json.dumps(yaml.load(handle, Loader=GithubActionsLoader)))
'@
        $script:dependabotParserPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dependabot-parser-" + [guid]::NewGuid() + '.py')
        try {
            Set-Content -LiteralPath $script:dependabotParserPath -Value $script:dependabotParser -Encoding utf8
            $output = & python $script:dependabotParserPath $script:dependabotConfigPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "PyYAML parser failed: $($output | Out-String)"
            }
            $script:dependabotConfig = ($output | Out-String).Trim() | ConvertFrom-Json
        }
        finally {
            if (Test-Path -LiteralPath $script:dependabotParserPath) {
                Remove-Item -LiteralPath $script:dependabotParserPath -Force
            }
        }
    }

    It 'keeps GitHub Actions updates enabled with a positive pull-request limit' {
        $actionsUpdate = @($script:dependabotConfig.updates | Where-Object { $_.'package-ecosystem' -eq 'github-actions' -and $_.directory -eq '/' })
        $actionsUpdate | Should -HaveCount 1
        $actionsUpdate[0].schedule.interval | Should -Be 'weekly'
        $actionsUpdate[0].'open-pull-requests-limit' | Should -Be 5
    }

    It 'ignores only this repository internal reusable workflows' {
        $actionsUpdate = @($script:dependabotConfig.updates | Where-Object { $_.'package-ecosystem' -eq 'github-actions' })
        $ignored = @($actionsUpdate[0].ignore)
        $ignored | Should -HaveCount 1
        $ignored[0].'dependency-name' | Should -Be 'AIAllTheThingz/Engineering-Standards/.github/workflows/*'
    }

    It 'does not globally ignore external GitHub Actions' {
        $actionsUpdate = @($script:dependabotConfig.updates | Where-Object { $_.'package-ecosystem' -eq 'github-actions' })
        $ignoredNames = @($actionsUpdate[0].ignore | ForEach-Object { $_.'dependency-name' })
        foreach ($namespace in @('actions/', 'github/', 'docker/', 'aquasecurity/', 'ossf/')) {
            $ignoredNames | Should -Not -Contain $namespace
        }
    }

    It 'preserves both existing pip update entries' {
        $pipUpdates = @($script:dependabotConfig.updates | Where-Object { $_.'package-ecosystem' -eq 'pip' })
        $pipUpdates | Should -HaveCount 2
        @($pipUpdates.directory) | Should -Contain '/.github/dependencies'
        @($pipUpdates.directory) | Should -Contain '/examples/python-project'
    }

    It 'does not disable Dependabot' {
        $script:dependabotConfig.version | Should -Be 2
        @($script:dependabotConfig.updates) | Should -HaveCount 3
        @($script:dependabotConfig.updates | Where-Object { $_.'open-pull-requests-limit' -eq 0 }) | Should -HaveCount 0
    }
}
