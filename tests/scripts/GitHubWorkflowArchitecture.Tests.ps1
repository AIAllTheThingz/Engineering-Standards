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

Describe 'GitHub workflow architecture validation' {
    It 'passes a valid one-way workflow call with a pinned action' {
        $root = New-WorkflowFixture -Name 'valid'
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
      governance-version: 1.0.0
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
      governance-version: { type: string, required: false, default: 1.0.0 }
      run-examples: { type: boolean, required: false, default: true }
      run-pester: { type: boolean, required: false, default: true }
      run-documentation-validation: { type: boolean, required: false, default: true }
      artifact-retention-days: { type: number, required: false, default: 30 }
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
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
# downstream repository.
name: PowerShell CI
on:
  workflow_call:
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
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
jobs:
  governance:
    uses: ./.github/workflows/governance-ci-reusable.yml
'@
        Set-FixtureFile -Root $root -RelativePath '.github/workflows/governance-ci-reusable.yml' -Content @'
name: Reusable
on:
  workflow_call:
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
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
