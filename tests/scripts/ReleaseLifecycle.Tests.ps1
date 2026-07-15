Describe 'Release lifecycle gates' {
    BeforeAll {
        $script:root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $script:validator = Join-Path $script:root 'scripts/Test-ReleaseLifecycle.ps1'
        $script:validFixture = Join-Path $script:root 'tests/fixtures/release-lifecycle/valid/full-lifecycle.json'
        $script:tempRoot = Join-Path $script:root ('.tmp/release-lifecycle-tests-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null

        function script:Invoke-ReleaseFixture {
            param(
                [Parameter(Mandatory)][string]$Name,
                [Parameter(Mandatory)][string]$Stage,
                [scriptblock]$Mutate
            )

            $fixturePath = Join-Path $script:tempRoot "$Name.json"
            $fixture = Get-Content -LiteralPath $script:validFixture -Raw | ConvertFrom-Json
            if ($Mutate) { & $Mutate $fixture }
            $fixture | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $fixturePath -Encoding utf8
            $relativeFixture = [System.IO.Path]::GetRelativePath($script:root, $fixturePath).Replace('\', '/')
            $output = @(& pwsh -NoProfile -File $script:validator -Path $script:root -EvidencePath $relativeFixture -Stage $Stage 2>&1)
            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output = $output -join "`n"
                Path = $fixturePath
            }
        }
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
        }
    }

    It 'passes a complete synthetic lifecycle through all three gates' {
        & pwsh -NoProfile -File $script:validator -Path $script:root -EvidencePath 'tests/fixtures/release-lifecycle/valid/full-lifecycle.json' -Stage All
        $LASTEXITCODE | Should -Be 0
    }

    It 'passes the complete synthetic record through the default pre-release gate' {
        & pwsh -NoProfile -File $script:validator -Path $script:root -EvidencePath 'tests/fixtures/release-lifecycle/valid/full-lifecycle.json'
        $LASTEXITCODE | Should -Be 0
    }

    It 'rejects approvals attached to a stale final head' {
        $result = Invoke-ReleaseFixture -Name 'stale-head' -Stage PreRelease -Mutate {
            param($fixture)
            $fixture.finalHeadSha = '9999999999999999999999999999999999999999'
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG058'
    }

    It 'does not pass readiness when the exact-candidate canary did not run' {
        $result = Invoke-ReleaseFixture -Name 'canary-not-run' -Stage PreRelease -Mutate {
            param($fixture)
            $fixture.preRelease.downstreamCanary.status = 'NotRun'
            $fixture.preRelease.downstreamCanary.reason = 'The downstream canary was deliberately not executed for this negative test.'
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'preRelease\.downstreamCanary must be Passed'
    }

    It 'rejects a controlled failure that occurred before final mandatory enforcement' {
        $result = Invoke-ReleaseFixture -Name 'early-controlled-failure' -Stage PreRelease -Mutate {
            param($fixture)
            $fixture.preRelease.controlledFailureRun.failedStep = 'Run trusted governance validation'
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG077'
    }

    It 'rejects controlled-failure evidence that was not independently verified' {
        $result = Invoke-ReleaseFixture -Name 'unverified-failure-artifact' -Stage PreRelease -Mutate {
            param($fixture)
            $fixture.preRelease.controlledFailureRun.artifact.verified = $false
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG014'
    }

    It 'rejects a canary scenario whose observed conclusion differs from its contract' {
        $result = Invoke-ReleaseFixture -Name 'wrong-canary-conclusion' -Stage PreRelease -Mutate {
            param($fixture)
            $fixture.preRelease.downstreamCanary.scenarios[2].conclusion = 'success'
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG036'
    }

    It 'rejects publication when the release tag was rewritten' {
        $result = Invoke-ReleaseFixture -Name 'rewritten-tag' -Stage Publication -Mutate {
            param($fixture)
            $fixture.publication.tag.rewritten = $true
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG104'
    }

    It 'rejects published notes that differ from reviewed notes' {
        $result = Invoke-ReleaseFixture -Name 'notes-drift' -Stage Publication -Mutate {
            param($fixture)
            $fixture.publication.githubRelease.notesSha256 = '9999999999999999999999999999999999999999999999999999999999999999'
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG107'
    }

    It 'requires a follow-up issue for every downstream defect regression' {
        $result = Invoke-ReleaseFixture -Name 'missing-follow-up' -Stage PostRelease -Mutate {
            param($fixture)
            $fixture.postRelease.regressions = @(
                [pscustomobject]@{
                    repository = 'example/downstream'
                    summary = 'The published workflow introduced an unexpected validation regression.'
                    disposition = 'Defect'
                }
            )
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG122'
    }

    It 'rejects a post-release canary bound to a different published version' {
        $result = Invoke-ReleaseFixture -Name 'wrong-published-canary-ref' -Stage PostRelease -Mutate {
            param($fixture)
            $fixture.postRelease.downstreamCanary.publishedRef = 'v1.0.0'
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG032'
    }

    It 'rejects post-release prerelease state that contradicts a stable version' {
        $result = Invoke-ReleaseFixture -Name 'wrong-post-release-prerelease-state' -Stage PostRelease -Mutate {
            param($fixture)
            $fixture.postRelease.githubReleaseVerification.prerelease = $true
        }
        $result.ExitCode | Should -Be 1
        $result.Output | Should -Match 'RLG127'
    }

    It 'writes machine-readable actionable findings' {
        $reportPath = Join-Path $script:tempRoot 'finding-report.json'
        $result = Invoke-ReleaseFixture -Name 'report-output' -Stage PreRelease -Mutate {
            param($fixture)
            $fixture.preRelease.successRun.targetSha = '8888888888888888888888888888888888888888'
        }
        & pwsh -NoProfile -File $script:validator -Path $script:root -EvidencePath ([System.IO.Path]::GetRelativePath($script:root, $result.Path).Replace('\', '/')) -Stage PreRelease -OutputJson $reportPath
        $LASTEXITCODE | Should -Be 1
        $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $report.failed | Should -BeGreaterThan 0
        @($report.results.data.code) | Should -Contain 'RLG020'
    }
}
