BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot/../.."
    $script:validator = Join-Path $script:repoRoot 'scripts/Test-GitHubWorkflowArchitecture.ps1'
    $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("workflow-architecture-tests-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
}

AfterAll {
    if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
        Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
    }
}

function script:New-WorkflowFixture {
    param([Parameter(Mandatory)][string]$Name)
    $root = Join-Path $script:tempRoot $Name
    New-Item -ItemType Directory -Path (Join-Path $root '.github/workflows') -Force | Out-Null
    $root
}

function script:Set-FixtureFile {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Content
    )
    $path = Join-Path $Root $RelativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    Set-Content -LiteralPath $path -Value $Content -Encoding utf8
}

function script:New-CurrentWorkflowFixture {
    param([Parameter(Mandatory)][string]$Name)
    $root = New-WorkflowFixture -Name $Name
    Set-FixtureFile -Root $root -RelativePath 'project-manifest.json' -Content (Get-Content -LiteralPath (Join-Path $script:repoRoot 'project-manifest.json') -Raw)
    foreach ($relative in @('.github/workflows/governance-ci.yml','.github/workflows/governance-ci-reusable.yml','.github/workflows/governance-ci-candidate.yml','.github/workflows/codex-skill-behavior.yml')) {
        Set-FixtureFile -Root $root -RelativePath $relative -Content (Get-Content -LiteralPath (Join-Path $script:repoRoot $relative) -Raw)
    }
    Set-FixtureFile -Root $root -RelativePath 'governance/codex-skill-behavior-evaluation.psd1' -Content (Get-Content -LiteralPath (Join-Path $script:repoRoot 'governance/codex-skill-behavior-evaluation.psd1') -Raw)
    $root
}

Describe 'GitHub workflow architecture validation' {
    It 'requires immutable trusted baseline and candidate implementation validation' {
        $root = New-CurrentWorkflowFixture -Name 'current-dual-validation'
        $entryText = Get-Content -LiteralPath (Join-Path $root '.github/workflows/governance-ci.yml') -Raw
        $pinMatch = [regex]::Match($entryText, 'governance-ci-candidate\.yml@([a-fA-F0-9]{40})')
        $pinMatch.Success | Should -BeTrue
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -ExpectedReusableWorkflowSha $pinMatch.Groups[1].Value -RequireCandidateValidation
        $LASTEXITCODE | Should -Be 0
    }

    It 'requires caller history for evidence commit verification' {
        $root = New-CurrentWorkflowFixture -Name 'shallow-caller-checkout'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $content = $content.Replace('fetch-depth: 0', 'fetch-depth: 1')
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content $content

        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)

        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'fetch full history'
    }

    It 'requires repository owner type from trusted GitHub event context' {
        $root = New-CurrentWorkflowFixture -Name 'untrusted-owner-type-source'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace('${{ github.event.repository.owner.type }}', '${{ inputs.repository-owner-type }}')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'trusted github.event.repository.owner.type context'
    }

    It 'requires case-sensitive normalization of supported repository owner types' {
        $root = New-CurrentWorkflowFixture -Name 'owner-type-case-insensitive-normalization'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace('switch -CaseSensitive ($env:CALLER_REPOSITORY_OWNER_TYPE)', 'switch ($env:CALLER_REPOSITORY_OWNER_TYPE)')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'normalize only exact User or Organization'
    }

    It 'requires propagation of normalized repository owner type to aggregate validation' {
        $root = New-CurrentWorkflowFixture -Name 'missing-owner-type-propagation'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("            -RepositoryOwnerType `$env:CALLER_REPOSITORY_OWNER_TYPE ```n", '')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'pass the normalized trusted repository owner type'
    }

    It 'rejects a caller-controlled repository owner type input' {
        $root = New-CurrentWorkflowFixture -Name 'caller-owner-type-input'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $content = $content.Replace("      project-path:`n", "      repository-owner-type:`n        type: string`n        required: false`n        default: Unknown`n      project-path:`n")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must not be able to supply or override the trusted repository owner type'
    }

    It 'preserves exact read-only reusable workflow permissions' {
        $root = New-CurrentWorkflowFixture -Name 'reusable-owner-type-write-permission'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("permissions:`n  contents: read", "permissions:`n  contents: write")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'permissions must be exactly contents: read'
    }

    It 'rejects a missing candidate implementation validation call' {
        $root = New-CurrentWorkflowFixture -Name 'missing-candidate-call'
        $path = Join-Path $root '.github/workflows/governance-ci.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $content = [regex]::Replace($content, '(?ms)\r?\n  candidate_implementation:.*\z', '')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'candidate-validation harness'
    }

    It 'does not allow manifest identity changes to opt out of candidate policy' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-manifest-opt-out'
        $manifestPath = Join-Path $root 'project-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $manifest.repository = 'ExampleOrg/not-standards'
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding utf8
        $entryPath = Join-Path $root '.github/workflows/governance-ci.yml'
        $entry = Get-Content -LiteralPath $entryPath -Raw
        $entry = [regex]::Replace($entry, '(?ms)\r?\n  candidate_implementation:.*\z', '')
        Set-Content -LiteralPath $entryPath -Value $entry -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'candidate-validation harness'
    }

    It 'rejects elevated candidate harness permissions' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-write-permission'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $content = $content.Replace("    permissions:`n      contents: read", "    permissions:`n      contents: write")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'permissions must be exactly contents: read|prohibited trigger, secret, or elevated permission'
    }

    It 'rejects pull_request_target for candidate validation' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-pull-request-target'
        $path = Join-Path $root '.github/workflows/governance-ci.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace('  pull_request:', '  pull_request_target:')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'pull_request_target'
    }

    It 'rejects additive pull_request_target alongside safe triggers' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-additive-pull-request-target'
        $path = Join-Path $root '.github/workflows/governance-ci.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("  pull_request:`n", "  pull_request:`n  pull_request_target:`n")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must not use pull_request_target'
    }

    It 'rejects a condition that can skip candidate validation' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-if-false'
        $path = Join-Path $root '.github/workflows/governance-ci.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $content = $content.Replace("  candidate_implementation:`n    name:", "  candidate_implementation:`n    if: false`n    name:")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must not use a condition that can skip execution'
    }

    It 'rejects candidate secret inheritance' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-secret-inheritance'
        $path = Join-Path $root '.github/workflows/governance-ci.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $content = [regex]::Replace($content, '(?m)^(    uses: AIAllTheThingz/Engineering-Standards/\.github/workflows/governance-ci-candidate\.yml@[a-fA-F0-9]{40})$', "`$1`n    secrets: inherit")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must not receive secrets'
    }

    It 'rejects a candidate checkout that persists credentials or uses the wrong ref' {
        $root = New-CurrentWorkflowFixture -Name 'unsafe-candidate-checkout'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $content = $content.Replace('ref: ${{ github.sha }}','ref: master').Replace('persist-credentials: false','persist-credentials: true')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'Candidate checkout must use github.repository/github.sha|persist-credentials'
    }

    It 'rejects swallowed candidate failures' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-continue-on-error'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $content = $content.Replace("      - name: Run candidate implementation validation`n", "      - name: Run candidate implementation validation`n        continue-on-error: true`n")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must propagate failures'
    }

    It 'rejects a condition on the reusable candidate harness job' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-harness-job-if-false'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("  candidate:`n    name:", "  candidate:`n    if: false`n    name:")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'Candidate harness job must not use a condition that can skip execution'
    }

    It 'rejects a condition on the candidate validation step' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-validation-step-if-false'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("      - name: Run candidate implementation validation`n", "      - name: Run candidate implementation validation`n        if: false`n")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'Candidate implementation validation step must not use a condition that can skip execution'
    }

    It 'rejects CandidateMaintainerValidation mentioned only in a comment' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-comment-only-maintainer-mode'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("              '-CandidateMaintainerValidation'", "              '-OmittedCandidateMaintainerValidation' # '-CandidateMaintainerValidation'")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match "missing required argument '-CandidateMaintainerValidation'"
    }

    It 'rejects workflow-command suspension mentioned only in a comment' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-comment-only-stop-commands'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace('          Write-Output "::stop-commands::$commandMarker"', '          # Write-Output "::stop-commands::$commandMarker"')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must suspend workflow-command processing'
    }

    It 'rejects an omitted authoritative candidate validator' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-missing-authoritative-validator'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("'scripts/Invoke-GovernanceValidation.ps1'", "'scripts/Omitted-GovernanceValidation.ps1'")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match "must invoke the authoritative 'scripts/Invoke-GovernanceValidation.ps1' exactly once"
    }

    It 'rejects an additional candidate script beside the authoritative aggregate' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-duplicate-orchestration'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace(
            "            Invoke-CandidateScript 'scripts/Invoke-GovernanceValidation.ps1' @(",
            "            Invoke-CandidateScript 'scripts/Test-AgentStandards.ps1' @('-Path',`$root)`n            Invoke-CandidateScript 'scripts/Invoke-GovernanceValidation.ps1' @("
        )
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must not orchestrate additional candidate scripts'
    }

    It 'rejects candidate aggregate identity not bound to trusted GitHub context' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-untrusted-identity-binding'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace(
            '          CANDIDATE_SHA: ${{ github.sha }}' + "`n" + '          HARNESS_SHA: ${{ job.workflow_sha }}',
            '          CANDIDATE_SHA: ${{ github.event.before }}' + "`n" + '          HARNESS_SHA: ${{ job.workflow_sha }}'
        )
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must bind caller, candidate, and harness identities to trusted GitHub context'
    }

    It 'rejects candidate repository-health validation without the explicit central User owner type' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-owner-type-unknown'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("'-RepositoryOwnerType','User',", '')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'authoritative validation must explicitly use RepositoryOwnerType User'
    }

    It 'rejects a case-variant candidate repository owner type' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-owner-type-case-variant'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("'-RepositoryOwnerType','User'", "'-RepositoryOwnerType','user'")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'authoritative validation must explicitly use RepositoryOwnerType User'
    }

    It 'rejects the authoritative candidate validator mentioned only in a comment' {
        $root = New-CurrentWorkflowFixture -Name 'candidate-comment-only-authoritative-validator'
        $path = Join-Path $root '.github/workflows/governance-ci-candidate.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("'scripts/Invoke-GovernanceValidation.ps1' @(", "'scripts/Omitted-GovernanceValidation.ps1' @( # scripts/Invoke-GovernanceValidation.ps1")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -RequireCandidateValidation 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match "must invoke the authoritative 'scripts/Invoke-GovernanceValidation.ps1' exactly once"
    }

    It 'passes a valid one-way workflow call with a pinned action' {
        $root = New-WorkflowFixture -Name 'valid'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: governance-${{ github.ref }}
  cancel-in-progress: true
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          persist-credentials: false
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: governance-${{ github.run_id }}
          path: evidence
          if-no-files-found: error
      - shell: pwsh
        run: |
          Write-Output '${{ inputs.project-path }}'
          Write-Output '${{ inputs.governance-version }}'
          Write-Output '${{ inputs.run-examples }}'
          Write-Output '${{ inputs.run-pester }}'
          Write-Output '${{ inputs.run-documentation-validation }}'
          Write-Output '${{ inputs.artifact-retention-days }}'
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts a full-SHA remote self-CI call that matches the expected trusted SHA' {
        $root = New-WorkflowFixture -Name 'remote-self-call'
        $sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @"
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: governance-self
  cancel-in-progress: true
jobs:
  governance:
    uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@$sha
"@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      artifact-retention-days: { type: number, required: false, default: 30 }
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - run: |
          echo '${{ inputs.project-path }}'
          echo '${{ inputs.governance-version }}'
          echo '${{ inputs.artifact-retention-days }}'
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -ExpectedReusableWorkflowSha $sha
        $LASTEXITCODE | Should -Be 0
    }

    It 'rejects a remote self-CI SHA that differs from the expected trusted SHA' {
        $root = New-WorkflowFixture -Name 'remote-self-call-mismatch'
        $entrySha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        $expectedSha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @"
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: governance-self
  cancel-in-progress: true
jobs:
  governance:
    uses: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@$entrySha
"@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      artifact-retention-days: { type: number, required: false, default: 30 }
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - run: |
          echo '${{ inputs.project-path }}'
          echo '${{ inputs.governance-version }}'
          echo '${{ inputs.artifact-retention-days }}'
'@
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -ExpectedReusableWorkflowSha $expectedSha 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'does not match expected trusted SHA'
    }

    It 'fails direct self-reference' {
        $root = New-WorkflowFixture -Name 'self-reference'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.0.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
jobs:
  loop:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.0.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails two-file recursion' {
        $root = New-WorkflowFixture -Name 'two-file-recursion'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.0.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
jobs:
  back:
    uses: ./.github/workflows/governance-ci.yml
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails missing reusable workflow target' {
        $root = New-WorkflowFixture -Name 'missing-target'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
jobs:
  governance:
    uses: ./.github/workflows/missing.yml
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails a reusable workflow target missing workflow_call' {
        $root = New-WorkflowFixture -Name 'missing-workflow-call'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  push:
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - run: echo ok
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails unsupported inputs passed to reusable workflow' {
        $root = New-WorkflowFixture -Name 'invalid-inputs'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      unsupported: true
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.0.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo '${{ inputs.project-path }}'
          echo '${{ inputs.governance-version }}'
          echo '${{ inputs.run-examples }}'
          echo '${{ inputs.run-pester }}'
          echo '${{ inputs.run-documentation-validation }}'
          echo '${{ inputs.artifact-retention-days }}'
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails unpinned third-party action references' {
        $root = New-WorkflowFixture -Name 'unpinned-action'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.0.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          echo '${{ inputs.project-path }}'
          echo '${{ inputs.governance-version }}'
          echo '${{ inputs.run-examples }}'
          echo '${{ inputs.run-pester }}'
          echo '${{ inputs.run-documentation-validation }}'
          echo '${{ inputs.artifact-retention-days }}'
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails broad permissions' {
        $root = New-WorkflowFixture -Name 'broad-permissions'
        $broadPermission = 'write' + '-all'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @"
name: Governance CI
on:
  push:
    branches: [master]
permissions: $broadPermission
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
"@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails missing explicit permissions' {
        $root = New-WorkflowFixture -Name 'missing-permissions'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          persist-credentials: false
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: governance-${{ github.run_id }}
          path: evidence
          if-no-files-found: error
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails missing entry concurrency' {
        $root = New-WorkflowFixture -Name 'missing-concurrency'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          persist-credentials: false
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: governance-${{ github.run_id }}
          path: evidence
          if-no-files-found: error
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails missing timeout on executable job' {
        $root = New-WorkflowFixture -Name 'missing-timeout'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: governance-${{ github.ref }}
  cancel-in-progress: true
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          persist-credentials: false
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: governance-${{ github.run_id }}
          path: evidence
          if-no-files-found: error
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails checkout without persist-credentials false' {
        $root = New-WorkflowFixture -Name 'checkout-persist-credentials'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: governance-${{ github.ref }}
  cancel-in-progress: true
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: governance-${{ github.run_id }}
          path: evidence
          if-no-files-found: error
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails artifact upload with warn-on-missing files' {
        $root = New-WorkflowFixture -Name 'artifact-warn'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: governance-${{ github.ref }}
  cancel-in-progress: true
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          persist-credentials: false
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: governance-${{ github.run_id }}
          path: evidence
          if-no-files-found: warn
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails default branch trigger mismatch' {
        $root = New-WorkflowFixture -Name 'branch-mismatch'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [main]
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'fails invalid local reusable workflow locations' {
        $root = New-WorkflowFixture -Name 'invalid-local-location'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
jobs:
  governance:
    uses: ./workflows/governance-ci.yml
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'treats valid root distribution templates as informational' {
        $root = New-WorkflowFixture -Name 'valid-root-template'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: governance-${{ github.ref }}
  cancel-in-progress: true
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          persist-credentials: false
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: governance-${{ github.run_id }}
          path: evidence
          if-no-files-found: error
      - run: |
          echo '${{ inputs.project-path }}'
          echo '${{ inputs.governance-version }}'
          echo '${{ inputs.run-examples }}'
          echo '${{ inputs.run-pester }}'
          echo '${{ inputs.run-documentation-validation }}'
          echo '${{ inputs.artifact-retention-days }}'
'@
        Set-FixtureFile -Root $root -RelativePath 'workflows/powershell-ci.yml' -Content @'
# Distribution template only. GitHub does not execute reusable workflows from
# this root workflows/ directory until copied into .github/workflows/ in a
# downstream repository, and this file is not executable until copied into
# .github/workflows/ in the downstream repository.
name: PowerShell CI
on:
  workflow_call:
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          persist-credentials: false
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: powershell-${{ github.run_id }}
          path: evidence
          if-no-files-found: error
      - run: echo ok
'@
        $report = Join-Path $root 'report.json'
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master -OutputJson $report
        $LASTEXITCODE | Should -Be 0
        $json = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
        @($json.results | Where-Object { $_.path -eq 'workflows/powershell-ci.yml' -and $_.status -eq 'Passed' }).Count | Should -BeGreaterThan 0
        $json.warnings | Should -Be 0
    }

    It 'fails a mislabeled root distribution template' {
        $root = New-WorkflowFixture -Name 'invalid-root-template-label'
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci.yml' -Content @'
name: Governance CI
on:
  push:
    branches: [master]
permissions:
  contents: read
concurrency:
  group: governance-${{ github.ref }}
  cancel-in-progress: true
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
    with:
      project-path: .
      governance-version: 1.1.0
      run-examples: true
      run-pester: true
      run-documentation-validation: true
      artifact-retention-days: 30
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
    inputs:
      project-path: { type: string, required: false, default: . }
      governance-version: { type: string, required: false, default: 1.1.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          persist-credentials: false
      - uses: actions/upload-artifact@50769540e7f4bd5e21e526ee35c689e35e0d6874
        with:
          name: governance-${{ github.run_id }}
          path: evidence
          if-no-files-found: error
      - run: echo ok
'@
        Set-FixtureFile -Root $root -RelativePath 'workflows/powershell-ci.yml' -Content @'
name: PowerShell CI
on:
  workflow_call:
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - run: echo ok
'@
        & pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'rejects direct execution of a caller-controlled PowerShell script' {
        $root = New-CurrentWorkflowFixture -Name 'caller-script-execution'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $insertion = "      - name: Malicious caller script`n        shell: pwsh`n        run: '& ./caller/evil.ps1'`n`n      - name: Normalize evidence report paths"
        Set-Content -LiteralPath $path -Value $content.Replace('      - name: Normalize evidence report paths', $insertion) -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must not directly execute caller-controlled code'
    }

    It 'rejects a caller-controlled local composite action' {
        $root = New-CurrentWorkflowFixture -Name 'caller-local-action'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $insertion = "      - name: Malicious caller action`n        uses: ./caller/action`n`n      - name: Normalize evidence report paths"
        Set-Content -LiteralPath $path -Value $content.Replace('      - name: Normalize evidence report paths', $insertion) -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must not load a caller-controlled local action'
    }

    It 'rejects caller working-directory command execution' {
        $root = New-CurrentWorkflowFixture -Name 'caller-working-directory'
        $path = Join-Path $root '.github/workflows/governance-ci-reusable.yml'
        $content = Get-Content -LiteralPath $path -Raw
        $insertion = "      - name: Malicious caller working directory`n        working-directory: caller`n        run: npm test`n`n      - name: Normalize evidence report paths"
        Set-Content -LiteralPath $path -Value $content.Replace('      - name: Normalize evidence report paths', $insertion) -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'must not execute commands from the caller working directory'
    }
}

Describe 'Trusted Codex behavior workflow isolation' {
    It 'rejects automatic triggers' {
        $root = New-CurrentWorkflowFixture -Name 'codex-automatic-trigger'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("on:`n  workflow_dispatch:", "on:`n  pull_request:`n  workflow_dispatch:")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'triggered only by workflow_dispatch'
    }

    It 'rejects workflow-scoped secret exposure' {
        $root = New-CurrentWorkflowFixture -Name 'codex-workflow-secret'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("permissions:`n  contents: read", "env:`n  OPENAI_API_KEY: `${{ secrets.OPENAI_API_KEY }}`n`npermissions:`n  contents: read")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'workflow scope|Only the trusted model collector'
    }

    It 'rejects job-scoped secret exposure' {
        $root = New-CurrentWorkflowFixture -Name 'codex-job-secret'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("    permissions:`n      contents: read`n    steps:", "    permissions:`n      contents: read`n    env:`n      OPENAI_API_KEY: `${{ secrets.OPENAI_API_KEY }}`n    steps:")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'job scope|Only the trusted model collector'
    }

    It 'rejects candidate code execution' {
        $root = New-CurrentWorkflowFixture -Name 'codex-candidate-execution'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("          `$ErrorActionPreference = 'Stop'`n          Import-Module ./trusted/scripts/CodexSkillBehaviorEvaluation.psm1 -Force", "          `$ErrorActionPreference = 'Stop'`n          & ./candidate/scripts/Test-CodexSkills.ps1`n          Import-Module ./trusted/scripts/CodexSkillBehaviorEvaluation.psm1 -Force")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'untrusted data'
    }

    It 'rejects candidate execution through <CaseName>' -ForEach @(
        @{ CaseName = 'dot sourcing'; Command = '. ./candidate/scripts/extensionless' }
        @{ CaseName = 'module import'; Command = 'Import-Module ./candidate/scripts/Candidate.psm1' }
        @{ CaseName = 'process launch'; Command = 'Start-Process ./candidate/tools/runner' }
        @{ CaseName = 'shell indirection'; Command = 'bash -c ./candidate/tools/runner' }
        @{ CaseName = 'expression piping'; Command = 'Get-Content ./candidate/tools/runner | Invoke-Expression' }
    ) {
        $root = New-CurrentWorkflowFixture -Name "codex-candidate-$($CaseName.Replace(' ', '-'))"
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace(
            "          `$ErrorActionPreference = 'Stop'`n          Import-Module ./trusted/scripts/CodexSkillBehaviorEvaluation.psm1 -Force",
            "          `$ErrorActionPreference = 'Stop'`n          $Command`n          Import-Module ./trusted/scripts/CodexSkillBehaviorEvaluation.psm1 -Force"
        )
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'untrusted data'
    }

    It 'rejects execution outside the trusted repository and default branch' {
        $root = New-CurrentWorkflowFixture -Name 'codex-untrusted-context'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("github.repository == 'AIAllTheThingz/Engineering-Standards'", "github.repository != 'AIAllTheThingz/Engineering-Standards'")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'trusted repository and default master branch'
    }

    It 'rejects removal of candidate symlink enforcement' {
        $root = New-CurrentWorkflowFixture -Name 'codex-symlink-enforcement'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace('Test-CodexBehaviorCandidateTrust', 'Get-CodexBehaviorInput')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'reject symlinks'
    }

    It 'rejects npm lifecycle script enablement' {
        $root = New-CurrentWorkflowFixture -Name 'codex-npm-lifecycle'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace('npm ci --ignore-scripts --no-audit --no-fund', 'npm ci --no-audit --no-fund')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'lifecycle scripts'
    }

    It 'rejects removal of evaluator dependency provenance' {
        $root = New-CurrentWorkflowFixture -Name 'codex-dependency-provenance'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace("bomFormat = 'CycloneDX'", "bomFormat = 'Omitted'")
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'hashed dependency provenance'
    }

    It 'rejects removal of trusted evaluator hash binding' {
        $root = New-CurrentWorkflowFixture -Name 'codex-evaluator-hash'
        $path = Join-Path $root '.github/workflows/codex-skill-behavior.yml'
        $content = (Get-Content -LiteralPath $path -Raw).Replace('-TrustedPath ./trusted', '-TrustedPath ./candidate')
        Set-Content -LiteralPath $path -Value $content -Encoding utf8
        $output = @(& pwsh -NoProfile -File $script:validator -Path $root -DefaultBranch master 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'evaluator hash'
    }
}

Describe 'Composite action output wiring' {
    It 'passes validate-evidence inputs and writes declared outputs safely' {
        $action = Get-Content -LiteralPath (Join-Path $script:repoRoot 'actions/validate-evidence/action.yml') -Raw
        $action | Should -Match 'EvidencePath'
        $action | Should -Match 'ExpectedCommitSha'
        $action | Should -Match 'GITHUB_OUTPUT'
        $action | Should -Match 'Out-File'
    }

    It 'writes declared outputs in all composite action definitions' {
        foreach ($actionPath in Get-ChildItem -LiteralPath (Join-Path $script:repoRoot 'actions') -Filter action.yml -Recurse) {
            $content = Get-Content -LiteralPath $actionPath.FullName -Raw
            $content | Should -Match 'report-path='
            $content | Should -Match 'failed-count='
            $content | Should -Match 'GITHUB_OUTPUT'
        }
    }
}

Describe 'Governance workflow enforcement ordering' {
    It 'uploads artifacts before final enforcement and validates final evidence first' {
        $workflow = Get-Content -LiteralPath (Join-Path $script:repoRoot '.github/workflows/governance-ci-reusable.yml') -Raw
        $ordered = @(
            'Ensure validation failure evidence',
            'Generate workflow test evidence',
            'Generate completion evidence',
            'Validate completion evidence',
            'Finalize workflow test evidence',
            'Generate final completion evidence',
            'Validate final completion evidence',
            'Upload governance evidence',
            'Enforce mandatory governance result'
        )
        $last = -1
        foreach ($name in $ordered) {
            $index = $workflow.IndexOf("name: $name", [StringComparison]::Ordinal)
            $index | Should -BeGreaterThan $last
            $last = $index
        }
        $workflow | Should -Match "steps\.final_evidence_validation\.outcome"
        $workflow | Should -Match 'Write-GovernanceBootstrapFailureReport'
        $workflow | Should -Not -Match "Set-Content -LiteralPath evidence/governance-validation\.json"
    }
}
