Describe 'Base agent simplicity and runtime validation contract' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot/../..").Path
        $script:basePath = Join-Path $script:repoRoot 'agents/AGENTS_Base.md'

        function Get-BaseSimplicityContractFailures {
            param(
                [Parameter(Mandatory)]
                [string]$Text
            )

            $failures = [System.Collections.Generic.List[string]]::new()

            if ($Text -notmatch '(?im)^\|\s*Version\s*\|\s*(?<version>[0-9]+\.[0-9]+\.[0-9]+)\s*\|') {
                $failures.Add('The base standard must declare a semantic version.')
            }
            else {
                try {
                    if ([version]$Matches['version'] -lt [version]'1.1.0') {
                        $failures.Add('The base standard version must be at least 1.1.0.')
                    }
                }
                catch {
                    $failures.Add('The base standard version must be a valid semantic version.')
                }
            }

            $requiredPatterns = @(
                @{ Pattern = '(?im)^## Simplicity And Proportional Design\s*$'; Message = 'The proportional-design section is required.' },
                @{ Pattern = 'Agents MUST implement the smallest complete change that satisfies the current requirements, applicable standards, and validation obligations\.'; Message = 'The smallest-complete-change requirement is required.' },
                @{ Pattern = 'Introduce an abstraction only when it removes demonstrated duplication, isolates a meaningful boundary, improves testability, or represents a real domain concept required by the current task\.'; Message = 'Abstractions must be justified by current demonstrated need.' },
                @{ Pattern = 'Add a dependency only when it provides a clear benefit in correctness, security, interoperability, maintainability, or overall complexity that outweighs its operational and supply-chain cost\.'; Message = 'Dependencies must have a documented net benefit.' },
                @{ Pattern = 'provided required behavior, compatibility, security controls, tests, documentation, and evidence remain intact\.'; Message = 'Simplification must preserve mandatory controls and evidence.' },
                @{ Pattern = 'Extract a private helper when it names an important invariant, isolates side effects, centralizes security-sensitive logic, prevents meaningful duplication, reduces material complexity, or improves testing\.'; Message = 'Private helpers must remain available when they clarify real boundaries or invariants.' },
                @{ Pattern = 'Agents MUST NOT:[\s\S]*Add speculative extension points, generic frameworks, factories, interfaces, configuration switches, or plugin systems for requirements that do not exist\.'; Message = 'Speculative extension mechanisms must be prohibited.' },
                @{ Pattern = 'Remove required validation, testing, documentation, compatibility behavior, evidence, or security controls in the name of simplicity\.'; Message = 'Simplicity must not remove governance or safety controls.' },
                @{ Pattern = '(?im)^## Runtime Validation Discipline\s*$'; Message = 'The runtime-validation section is required.' },
                @{ Pattern = 'Runtime validation MUST be placed at trust boundaries and wherever an invariant can no longer be assumed\.'; Message = 'Runtime validation must be required at trust boundaries.' },
                @{ Pattern = 'Within a single trusted control flow, agents SHOULD avoid repeatedly validating an invariant that has already been established and cannot have changed\.'; Message = 'Redundant validation should be avoided only inside an unchanged trusted flow.' },
                @{ Pattern = 'Runtime guards, type checks, fallbacks, retries, and exception handling MUST protect a documented invariant or credible failure mode\.'; Message = 'Defensive checks must protect a credible invariant or failure mode.' },
                @{ Pattern = 'Catch-all exception handling MUST NOT swallow failures or fabricate successful behavior\.'; Message = 'Catch-all handling must preserve failure semantics.' }
            )

            foreach ($required in $requiredPatterns) {
                if ($Text -notmatch $required.Pattern) {
                    $failures.Add($required.Message)
                }
            }

            @($failures)
        }
    }

    It 'passes for the governed base standard' {
        $text = Get-Content -LiteralPath $script:basePath -Raw
        @(Get-BaseSimplicityContractFailures -Text $text) | Should -BeNullOrEmpty
    }

    It 'fails when the base standard version predates the contract' {
        $text = (Get-Content -LiteralPath $script:basePath -Raw).Replace('| Version | 1.1.0 |', '| Version | 1.0.0 |')
        @(Get-BaseSimplicityContractFailures -Text $text) | Should -Not -BeNullOrEmpty
    }

    It 'fails when smallest-complete-change language is weakened' {
        $text = (Get-Content -LiteralPath $script:basePath -Raw).Replace(
            'Agents MUST implement the smallest complete change',
            'Agents SHOULD implement the smallest complete change'
        )
        @(Get-BaseSimplicityContractFailures -Text $text) | Should -Not -BeNullOrEmpty
    }

    It 'fails when simplification no longer preserves mandatory controls' {
        $text = (Get-Content -LiteralPath $script:basePath -Raw).Replace(
            'provided required behavior, compatibility, security controls, tests, documentation, and evidence remain intact.',
            'provided the result is shorter.'
        )
        @(Get-BaseSimplicityContractFailures -Text $text) | Should -Not -BeNullOrEmpty
    }

    It 'fails when runtime validation at trust boundaries is weakened' {
        $text = (Get-Content -LiteralPath $script:basePath -Raw).Replace(
            'Runtime validation MUST be placed at trust boundaries',
            'Runtime validation SHOULD be placed at trust boundaries'
        )
        @(Get-BaseSimplicityContractFailures -Text $text) | Should -Not -BeNullOrEmpty
    }

    It 'fails when catch-all handling may swallow failures' {
        $text = (Get-Content -LiteralPath $script:basePath -Raw).Replace(
            'Catch-all exception handling MUST NOT swallow failures or fabricate successful behavior.',
            'Catch-all exception handling SHOULD usually preserve failures.'
        )
        @(Get-BaseSimplicityContractFailures -Text $text) | Should -Not -BeNullOrEmpty
    }
}
