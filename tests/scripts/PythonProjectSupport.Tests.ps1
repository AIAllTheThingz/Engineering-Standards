BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:example = Join-Path $script:root 'examples/python-project'
    $script:workflow = Get-Content -LiteralPath (Join-Path $script:root '.github/workflows/python-ci-reusable.yml') -Raw
    $script:driver = Get-Content -LiteralPath (Join-Path $script:root 'scripts/python-project-validation.py') -Raw
}

Describe 'Governed Python project support' {
    It 'keeps functional execution in the dedicated Python workflow' {
        $aggregate=Get-Content (Join-Path $script:root 'scripts/Test-Examples.ps1') -Raw
        $aggregate | Should -Not -Match 'examples/python-project/tools/Test-Example\.ps1'
        (Get-Content (Join-Path $script:root '.github/workflows/python-ci-reusable.yml') -Raw) | Should -Match 'python-project-validation\.py'
    }

    It 'provides the complete functional example contract' {
        foreach ($path in @('pyproject.toml','requirements-ci.in','requirements-ci.lock','requirements-runtime.lock','project-manifest.json','governance.config.json','src/governed_paths/paths.py','tests/test_paths.py','tools/Test-Example.ps1')) {
            Test-Path -LiteralPath (Join-Path $script:example $path) -PathType Leaf | Should -BeTrue
        }
        (Get-Content -LiteralPath (Join-Path $script:example 'project-manifest.json') -Raw | ConvertFrom-Json).projectType | Should -BeExactly 'python'
    }

    It 'pins every functional requirement and supplies hashes' {
        $lock = Get-Content -LiteralPath (Join-Path $script:example 'requirements-ci.lock') -Raw
        foreach ($package in @('pytest==9.1.1','mypy==2.3.0','pip-audit==2.10.1','build==1.5.0','hatchling==1.31.0','ruff==0.15.22','cyclonedx-bom==7.3.0')) {
            $lock | Should -Match ([regex]::Escape($package))
        }
        $lock | Should -Match '(?m)^\s+--hash=sha256:[0-9a-f]{64}'
        $lock | Should -Not -Match '(?m)^[A-Za-z0-9_.-]+(?:>=|~=|>)'
    }

    It 'keeps functional tools outside the central static validator lock' {
        $central = Get-Content -LiteralPath (Join-Path $script:root '.github/dependencies/validator-dependencies.psd1') -Raw
        $central | Should -Not -Match "(?i)Name\s*=\s*'(pytest|mypy|pip-audit|build|hatchling|cyclonedx-bom)'"
    }

    It 'uses immutable actions, fixed runtime, read-only permission, and evidence-before-enforcement' {
        $script:workflow | Should -Match 'runs-on:\s*ubuntu-24\.04'
        $script:workflow | Should -Match 'default:\s*3\.12\.11'
        $script:workflow | Should -Match 'actions/checkout@[0-9a-f]{40}'
        $script:workflow | Should -Match 'actions/setup-python@[0-9a-f]{40}'
        $script:workflow | Should -Match 'actions/upload-artifact@[0-9a-f]{40}'
        $script:workflow | Should -Match 'permissions:\s*\r?\n\s+contents:\s*read'
        $script:workflow.IndexOf('Upload Python evidence before enforcement') | Should -BeLessThan $script:workflow.IndexOf('Enforce Python validation')
    }

    It 'locks down caller-controlled test and type-check configuration' {
        $script:driver | Should -Match 'PYTEST_DISABLE_PLUGIN_AUTOLOAD'
        $script:driver | Should -Match '(?s)"-c",\s+os\.devnull'
        $script:driver | Should -Match '"--config-file"'
        $script:driver | Should -Match 'python-mypy\.ini|mypy_config'
        $script:driver | Should -Match '"-I"'
        $script:driver | Should -Match '"--no-isolation"'
    }

    It 'fails mutations that remove representative trust controls' -ForEach @(
        @{ Pattern='PYTEST_DISABLE_PLUGIN_AUTOLOAD'; Replacement='PYTEST_PLUGIN_AUTOLOAD' },
        @{ Pattern='--config-file'; Replacement='--caller-config' },
        @{ Pattern='inspect_wheel\(wheel, metadata\)'; Replacement='list()' },
        @{ Pattern='Blocked'; Replacement='Passed' }
    ) {
        $mutant = $script:driver -replace $Pattern, $Replacement
        $mutant | Should -Not -BeExactly $script:driver
        $mutant | Should -Not -Match $Pattern
    }

    It 'rejects rooted and traversal paths in the reusable workflow' {
        $script:workflow | Should -Match 'IsPathRooted'
        $script:workflow | Should -Match '\\\.\\\.'
        $script:workflow | Should -Match 'LinkType|ReparsePoint'
    }

    It 'preserves non-bypassable static-language applicability' {
        $aggregate = Get-Content -LiteralPath (Join-Path $script:root 'scripts/Invoke-GovernanceValidation.ps1') -Raw
        $aggregate | Should -Match 'Get-TrustedSourceFiles -Root \$ProjectRoot -Language Python'
        $aggregate | Should -Match 'Get-TrustedSourceFiles -Root \$ProjectRoot -Language Bash'
        $aggregate | Should -Match 'Downstream caller configuration cannot disable mandatory category'
    }
}
