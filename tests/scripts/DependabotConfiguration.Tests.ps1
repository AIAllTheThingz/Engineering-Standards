Describe 'Dependabot configuration' {
    BeforeAll {
        $script:root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $script:configPath = Join-Path $script:root '.github/dependabot.yml'
        $script:config = Get-Content -LiteralPath $script:configPath -Raw
    }

    It 'keeps GitHub Actions updates enabled with a positive pull-request limit' {
        $script:config | Should -Match '(?m)^[ \t]*-[ \t]*package-ecosystem:[ \t]*github-actions[ \t]*$'
        $script:config | Should -Match '(?m)^[ \t]*directory:[ \t]*/[ \t]*$'
        $script:config | Should -Match '(?m)^[ \t]*interval:[ \t]*weekly[ \t]*$'
        $script:config | Should -Match '(?m)^[ \t]*open-pull-requests-limit:[ \t]*5[ \t]*$'
    }

    It 'ignores only this repository internal reusable workflows' {
        $script:config | Should -Match '(?m)^[ \t]*-[ \t]*dependency-name:[ \t]*"AIAllTheThingz/Engineering-Standards/\.github/workflows/\*"[ \t]*$'
        [regex]::Matches($script:config, '(?m)^[ \t]*-[ \t]*dependency-name:').Count | Should -Be 1
    }

    It 'does not globally ignore external GitHub Actions' {
        foreach ($namespace in @('actions/', 'github/', 'docker/', 'aquasecurity/', 'ossf/')) {
            $script:config | Should -Not -Match ([regex]::Escape(('dependency-name: "' + $namespace)))
        }
    }

    It 'preserves both existing pip update entries' {
        [regex]::Matches($script:config, '(?m)^[ \t]*-[ \t]*package-ecosystem:[ \t]*pip[ \t]*$').Count | Should -Be 2
        $script:config | Should -Match '(?m)^[ \t]*directory:[ \t]*/\.github/dependencies[ \t]*$'
        $script:config | Should -Match '(?m)^[ \t]*directory:[ \t]*/examples/python-project[ \t]*$'
    }

    It 'does not disable Dependabot' {
        $script:config | Should -Match '(?m)^version:[ \t]*2[ \t]*$'
        $script:config | Should -Not -Match '(?m)^[ \t]*open-pull-requests-limit:[ \t]*0[ \t]*$'
    }
}
