Describe 'Dependabot configuration' {
    BeforeAll {
        $script:dependabotRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $script:dependabotConfigPath = Join-Path $script:dependabotRoot '.github/dependabot.yml'
        $script:dependabotConfigText = Get-Content -LiteralPath $script:dependabotConfigPath -Raw
    }

    It 'keeps GitHub Actions updates enabled with a positive pull-request limit' {
        $script:dependabotConfigText | Should -Match '(?m)^[ \t]*-[ \t]*package-ecosystem:[ \t]*github-actions[ \t]*$'
        $script:dependabotConfigText | Should -Match '(?m)^[ \t]*directory:[ \t]*/[ \t]*$'
        $script:dependabotConfigText | Should -Match '(?m)^[ \t]*interval:[ \t]*weekly[ \t]*$'
        $script:dependabotConfigText | Should -Match '(?m)^[ \t]*open-pull-requests-limit:[ \t]*5[ \t]*$'
    }

    It 'ignores only this repository internal reusable workflows' {
        $script:dependabotConfigText | Should -Match '(?m)^[ \t]*-[ \t]*dependency-name:[ \t]*"AIAllTheThingz/Engineering-Standards/\.github/workflows/\*"[ \t]*$'
        [regex]::Matches($script:dependabotConfigText, '(?m)^[ \t]*-[ \t]*dependency-name:').Count | Should -Be 1
    }

    It 'does not globally ignore external GitHub Actions' {
        foreach ($namespace in @('actions/', 'github/', 'docker/', 'aquasecurity/', 'ossf/')) {
            $script:dependabotConfigText | Should -Not -Match ([regex]::Escape(('dependency-name: "' + $namespace)))
        }
    }

    It 'preserves both existing pip update entries' {
        [regex]::Matches($script:dependabotConfigText, '(?m)^[ \t]*-[ \t]*package-ecosystem:[ \t]*pip[ \t]*$').Count | Should -Be 2
        $script:dependabotConfigText | Should -Match '(?m)^[ \t]*directory:[ \t]*/\.github/dependencies[ \t]*$'
        $script:dependabotConfigText | Should -Match '(?m)^[ \t]*directory:[ \t]*/examples/python-project[ \t]*$'
    }

    It 'does not disable Dependabot' {
        $script:dependabotConfigText | Should -Match '(?m)^version:[ \t]*2[ \t]*$'
        $script:dependabotConfigText | Should -Not -Match '(?m)^[ \t]*open-pull-requests-limit:[ \t]*0[ \t]*$'
    }
}
