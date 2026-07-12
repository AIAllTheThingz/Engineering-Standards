Describe 'Release consistency validation' {
    BeforeAll {
        $script:validator = Join-Path $PSScriptRoot '../../scripts/Test-ReleaseConsistency.ps1'
        $script:invokeFixtureValidation = {
            $script:output = @(& pwsh -NoProfile -File $script:validator -Path $script:fixture 2>&1)
            return $LASTEXITCODE
        }
    }

    BeforeEach {
        $script:canarySha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        $script:historicalSha = '091841c94fba6039443a40b7c4a28e5b9a3af2d2'
        $script:fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('release-consistency-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $script:fixture 'docs/releases') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:fixture 'VERSION') -Value '1.1.0'
        Set-Content -LiteralPath (Join-Path $script:fixture 'CHANGELOG.md') -Value @'
# Changelog

## [Unreleased]

### Fixed

- A post-release correction.

- Consumers requiring the final canary-validated repaired reusable workflow should pin `.github/workflows/governance-ci-reusable.yml` to immutable post-release commit `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`.

## [1.1.0] - 2026-07-11
'@
        Set-Content -LiteralPath (Join-Path $script:fixture 'README.md') -Value @'
# Repository

Current published version: `1.1.0`. Annotated tag `v1.1.0` resolves to immutable commit `1111111111111111111111111111111111111111`. See [Release Status](docs/RELEASE_STATUS.md) and [Unreleased](CHANGELOG.md#unreleased).

Consumers requiring the final canary-validated repaired reusable workflow should pin `.github/workflows/governance-ci-reusable.yml` to immutable post-release commit `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`.
'@
        Set-Content -LiteralPath (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') -Value @'
# Release Status

The latest published version is `1.1.0`. Annotated tag `v1.1.0` has tag-object SHA `1111111111111111111111111111111111111111` and resolves to immutable commit `1111111111111111111111111111111111111111`.

Current `master` contains development after the published target. Historical evidence does not validate current `master`.

Final canary-validated repaired reusable workflow: `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`.
'@
        Set-Content -LiteralPath (Join-Path $script:fixture 'docs/DOWNSTREAM_CANARY.md') -Value @'
# Downstream Canary

| Field | Value |
| --- | --- |
| Validated standards SHA | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |
'@
        Set-Content -LiteralPath (Join-Path $script:fixture 'docs/releases/1.1.0.md') -Value '# Release 1.1.0'
    }

    AfterEach {
        if ($script:fixture -and (Test-Path -LiteralPath $script:fixture)) {
            Remove-Item -LiteralPath $script:fixture -Recurse -Force
        }
    }

    It 'accepts a valid published release with unreleased development' {
        & $script:invokeFixtureValidation | Should -Be 0 -Because ($script:output -join "`n")
    }

    It 'accepts a published tag with no post-tag development wording' {
        Push-Location $script:fixture
        try {
            git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'
            git add .; git commit -qm baseline; git tag -a v1.1.0 -m release
            $tagObject = git rev-parse v1.1.0
            $target = git rev-parse 'v1.1.0^{}'
            $text = (Get-Content docs/RELEASE_STATUS.md -Raw).Replace('tag-object SHA `1111111111111111111111111111111111111111`', "tag-object SHA ``$tagObject``").Replace('resolves to immutable commit `1111111111111111111111111111111111111111`', "resolves to immutable commit ``$target``").Replace('Current `master` contains development after the published target. ', '')
            Set-Content docs/RELEASE_STATUS.md $text
            (Get-Content README.md -Raw).Replace('1111111111111111111111111111111111111111', $target) | Set-Content README.md
            Set-Content CHANGELOG.md "# Changelog`n`n## [Unreleased]`n`nNo unreleased changes are currently recorded.`n`n## [1.1.0] - 2026-07-11`n`nConsumers requiring the final canary-validated repaired reusable workflow should pin .github/workflows/governance-ci-reusable.yml to immutable post-release commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa."
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Be 0 -Because ($script:output -join "`n")
    }

    It 'validates the current repository release records' {
        $repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        & git -C $repositoryRoot rev-parse --verify --quiet 'v1.1.0^{}' *> $null
        $arguments = @('-NoProfile', '-File', $script:validator, '-Path', $repositoryRoot)
        if ($LASTEXITCODE -ne 0) {
            $arguments += '-SkipTagVerification'
        }
        $output = @(& pwsh @arguments 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }

    It 'still validates repository-controlled records when tag verification is explicitly unavailable' {
        $output = @(& pwsh -NoProfile -File $script:validator -Path $script:fixture -SkipTagVerification 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }

    It 'accepts an explicitly prepared and unpublished version before tag creation' {
        Set-Content (Join-Path $script:fixture 'README.md') @'
# Repository

The prepared version is `1.1.0` and is unpublished. See [Release Status](docs/RELEASE_STATUS.md) and [Unreleased](CHANGELOG.md#unreleased).

Consumers requiring the final canary-validated repaired reusable workflow should pin `.github/workflows/governance-ci-reusable.yml` to immutable post-release commit `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`.
'@
        Set-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') @'
# Release Status

The prepared version is `1.1.0` and is unpublished.

Tag state: Not created.

GitHub Release state: Not published.

Current `master` contains development after the published target. Historical evidence does not validate current `master`.

Final canary-validated repaired reusable workflow: `AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`.
'@
        $output = @(& pwsh -NoProfile -File $script:validator -Path $script:fixture 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }

    It 'rejects a prepared and unpublished state after its tag exists' {
        Set-Content (Join-Path $script:fixture 'README.md') "# Repository`n`nThe prepared version is ``1.1.0`` and is unpublished. See [Release Status](docs/RELEASE_STATUS.md) and [Unreleased](CHANGELOG.md#unreleased).`n`nConsumers requiring the final canary-validated repaired reusable workflow should pin .github/workflows/governance-ci-reusable.yml to immutable post-release commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa."
        Set-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') "# Release Status`n`nThe prepared version is ``1.1.0`` and is unpublished.`n`nTag state: Not created.`n`nFinal canary-validated repaired reusable workflow: AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa."
        Push-Location $script:fixture
        try { git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'; git add .; git commit -qm baseline; git tag -a v1.1.0 -m release } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails when Unreleased is missing' {
        (Get-Content (Join-Path $script:fixture 'CHANGELOG.md') -Raw).Replace('## [Unreleased]', '## Upcoming') | Set-Content (Join-Path $script:fixture 'CHANGELOG.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'missing an \[Unreleased\] section'
    }

    It 'fails an empty unreleased claim when post-tag commits exist' {
        Push-Location $script:fixture
        try {
            git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'
            git add .; git commit -qm baseline; git tag -a v1.1.0 -m release
            $tagObject = git rev-parse v1.1.0
            $target = git rev-parse 'v1.1.0^{}'
            $text = (Get-Content docs/RELEASE_STATUS.md -Raw).Replace('tag-object SHA `1111111111111111111111111111111111111111`', "tag-object SHA ``$tagObject``").Replace('resolves to immutable commit `1111111111111111111111111111111111111111`', "resolves to immutable commit ``$target``")
            Set-Content docs/RELEASE_STATUS.md $text
            (Get-Content README.md -Raw).Replace('1111111111111111111111111111111111111111', $target) | Set-Content README.md
            Add-Content README.md 'post tag'; git add .; git commit -qm later
            Set-Content CHANGELOG.md "# Changelog`n`n## [Unreleased]`n`nNo unreleased changes are currently recorded.`n`nConsumers requiring the final canary-validated repaired reusable workflow should pin .github/workflows/governance-ci-reusable.yml to immutable post-release commit aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.`n`n## [1.1.0] - 2026-07-11"
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'Post-tag commits exist'
    }

    It 'fails a blank Unreleased section when post-tag commits exist' {
        Push-Location $script:fixture
        try {
            git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'
            git add .; git commit -qm baseline; git tag -a v1.1.0 -m release
            $tagObject = git rev-parse v1.1.0
            $target = git rev-parse 'v1.1.0^{}'
            $text = (Get-Content docs/RELEASE_STATUS.md -Raw).Replace('tag-object SHA `1111111111111111111111111111111111111111`', "tag-object SHA ``$tagObject``").Replace('resolves to immutable commit `1111111111111111111111111111111111111111`', "resolves to immutable commit ``$target``")
            Set-Content docs/RELEASE_STATUS.md $text
            (Get-Content README.md -Raw).Replace('1111111111111111111111111111111111111111', $target) | Set-Content README.md
            Add-Content README.md 'post tag'; git add .; git commit -qm later
            Set-Content CHANGELOG.md "# Changelog`n`n## [Unreleased]`n`n## [1.1.0] - 2026-07-11"
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'requires the recorded tag object even when local tag verification is skipped' {
        (Get-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') -Raw).Replace('tag-object SHA `1111111111111111111111111111111111111111`', 'tag metadata unavailable') | Set-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md')
        $output = @(& pwsh -NoProfile -File $script:validator -Path $script:fixture -SkipTagVerification 2>&1)
        $LASTEXITCODE | Should -Not -Be 0
        $output -join "`n" | Should -Match 'annotated tag object as a full SHA'
    }

    It 'fails when README records a different published target' {
        (Get-Content (Join-Path $script:fixture 'README.md') -Raw).Replace('1111111111111111111111111111111111111111', '2222222222222222222222222222222222222222') | Set-Content (Join-Path $script:fixture 'README.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails when the expected release tag is absent from README' {
        (Get-Content (Join-Path $script:fixture 'README.md') -Raw).Replace('v1.1.0', 'release-tag') | Set-Content (Join-Path $script:fixture 'README.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails when the published release sentence names the wrong status tag' {
        (Get-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') -Raw).Replace('Annotated tag `v1.1.0`', 'Annotated tag `v1.0.0`') | Set-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails stale unreleased content when no post-tag commits exist' {
        Push-Location $script:fixture
        try {
            git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'; git add .; git commit -qm baseline; git tag -a v1.1.0 -m release
            $tagObject = git rev-parse v1.1.0
            $target = git rev-parse 'v1.1.0^{}'
            $statusText = (Get-Content docs/RELEASE_STATUS.md -Raw).Replace('tag-object SHA `1111111111111111111111111111111111111111`', "tag-object SHA ``$tagObject``").Replace('resolves to immutable commit `1111111111111111111111111111111111111111`', "resolves to immutable commit ``$target``").Replace('Current `master` contains development after the published target. ', '')
            Set-Content docs/RELEASE_STATUS.md $statusText
            (Get-Content README.md -Raw).Replace('1111111111111111111111111111111111111111', $target) | Set-Content README.md
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails a version mismatch' {
        Set-Content (Join-Path $script:fixture 'VERSION') '1.2.0'
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails when the release document is missing' {
        Remove-Item (Join-Path $script:fixture 'docs/releases/1.1.0.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails invalid semantic version syntax' {
        Set-Content (Join-Path $script:fixture 'VERSION') 'v1.1'
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'canonical semantic version'
    }

    It 'fails a shortened published target SHA' {
        (Get-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') -Raw).Replace('1111111111111111111111111111111111111111', '1111111') | Set-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails when the recorded target differs from the local tag' {
        Push-Location $script:fixture
        try {
            git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'; git add .; git commit -qm baseline; git tag -a v1.1.0 -m release
            $tagObject = git rev-parse v1.1.0
            $text = Get-Content docs/RELEASE_STATUS.md -Raw
            $text = $text.Replace('tag-object SHA `1111111111111111111111111111111111111111`', "tag-object SHA ``$tagObject``")
            Set-Content docs/RELEASE_STATUS.md $text
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'match local tag target'
    }

    It 'fails when the recorded annotated tag object differs from the local tag object' {
        Push-Location $script:fixture
        try {
            git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'; git add .; git commit -qm baseline
            git tag -a v1.1.0 -m release
            $target = git rev-parse 'v1.1.0^{}'
            $text = Get-Content docs/RELEASE_STATUS.md -Raw
            $text = $text.Replace('resolves to immutable commit `1111111111111111111111111111111111111111`', "resolves to immutable commit ``$target``")
            Set-Content docs/RELEASE_STATUS.md $text
            (Get-Content README.md -Raw).Replace('1111111111111111111111111111111111111111', $target) | Set-Content README.md
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'match local tag object'
    }

    It 'fails when the published tag is lightweight' {
        Push-Location $script:fixture
        try {
            git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'; git add .; git commit -qm baseline; git tag v1.1.0
            $commit = git rev-parse v1.1.0
            (Get-Content docs/RELEASE_STATUS.md -Raw).Replace('1111111111111111111111111111111111111111', $commit) | Set-Content docs/RELEASE_STATUS.md
            (Get-Content README.md -Raw).Replace('1111111111111111111111111111111111111111', $commit) | Set-Content README.md
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'must be an annotated tag object'
    }

    It 'fails a published state with a missing local tag' {
        Push-Location $script:fixture
        try { git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'; git add .; git commit -qm baseline } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'does not exist locally'
    }

    It 'fails unexplained stale pending-publication wording' {
        Add-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') 'GitHub Release is pending.'
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails when historical evidence is presented as current proof' {
        Push-Location $script:fixture
        try {
            git init -q; git config user.email 'test@example.invalid'; git config user.name 'Test'; git add .; git commit -qm baseline; git tag -a v1.1.0 -m release
            $tagObject = git rev-parse v1.1.0
            $target = git rev-parse 'v1.1.0^{}'
            $statusText = (Get-Content docs/RELEASE_STATUS.md -Raw).Replace('tag-object SHA `1111111111111111111111111111111111111111`', "tag-object SHA ``$tagObject``").Replace('resolves to immutable commit `1111111111111111111111111111111111111111`', "resolves to immutable commit ``$target``").Replace('does not validate current `master`', 'validates current `master`')
            Set-Content docs/RELEASE_STATUS.md $statusText
            (Get-Content README.md -Raw).Replace('1111111111111111111111111111111111111111', $target) | Set-Content README.md
            Add-Content README.md 'post tag'; git add .; git commit -qm later
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails README and release-status disagreement' {
        (Get-Content (Join-Path $script:fixture 'README.md') -Raw).Replace('1.1.0', '1.0.0') | Set-Content (Join-Path $script:fixture 'README.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails when README recommends a different canary SHA' {
        (Get-Content (Join-Path $script:fixture 'README.md') -Raw).Replace($script:canarySha, 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb') | Set-Content (Join-Path $script:fixture 'README.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    }

    It 'fails when CHANGELOG recommends a different canary SHA' {
        (Get-Content (Join-Path $script:fixture 'CHANGELOG.md') -Raw).Replace($script:canarySha, 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb') | Set-Content (Join-Path $script:fixture 'CHANGELOG.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    }

    It 'fails when release status recommends a different canary SHA' {
        (Get-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') -Raw).Replace($script:canarySha, 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb') | Set-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    }

    It 'fails when the canary SHA record is missing' {
        (Get-Content (Join-Path $script:fixture 'docs/DOWNSTREAM_CANARY.md') -Raw).Replace('Validated standards SHA', 'Candidate standards SHA') | Set-Content (Join-Path $script:fixture 'docs/DOWNSTREAM_CANARY.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'DOWNSTREAM_CANARY.md'
    }

    It 'fails when the canary SHA is shortened' {
        (Get-Content (Join-Path $script:fixture 'docs/DOWNSTREAM_CANARY.md') -Raw).Replace($script:canarySha, 'aaaaaaa') | Set-Content (Join-Path $script:fixture 'docs/DOWNSTREAM_CANARY.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'invalid Validated standards SHA'
    }

    It 'fails when the canary SHA is not hexadecimal' {
        (Get-Content (Join-Path $script:fixture 'docs/DOWNSTREAM_CANARY.md') -Raw).Replace($script:canarySha, 'gggggggggggggggggggggggggggggggggggggggg') | Set-Content (Join-Path $script:fixture 'docs/DOWNSTREAM_CANARY.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'invalid Validated standards SHA'
    }

    It 'fails when a recommendation uses a moving branch' {
        (Get-Content (Join-Path $script:fixture 'README.md') -Raw).Replace("commit ``$($script:canarySha)``", 'commit `@master`') | Set-Content (Join-Path $script:fixture 'README.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match '@master'
    }

    It 'fails when a recommendation uses a release tag' {
        (Get-Content (Join-Path $script:fixture 'README.md') -Raw).Replace("commit ``$($script:canarySha)``", 'commit `@v1.1.0`') | Set-Content (Join-Path $script:fixture 'README.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match '@v1.1.0'
    }

    It 'fails when a recommendation uses any other named ref' {
        $path = Join-Path $script:fixture 'docs/RELEASE_STATUS.md'
        (Get-Content $path -Raw).Replace("@$($script:canarySha)", '@stable') + "`nValidated canary SHA: ``$($script:canarySha)``." | Set-Content $path
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match '@stable'
    }

    It 'allows the prior self-CI pin when clearly recorded as historical' {
        Add-Content (Join-Path $script:fixture 'CHANGELOG.md') "Historical PR #30 trusted self-CI pin rotation used ``$($script:historicalSha)``."
        & $script:invokeFixtureValidation | Should -Be 0
    }

    It 'ignores a historical canary workflow recommendation outside Unreleased' {
        Add-Content (Join-Path $script:fixture 'CHANGELOG.md') "## [1.0.0] - 2026-01-01`n`nConsumers requiring the historical canary-proven repaired reusable workflow pinned .github/workflows/governance-ci-reusable.yml@$($script:historicalSha)."
        & $script:invokeFixtureValidation | Should -Be 0
    }

    It 'fails conflicting canary workflow recommendations in one document' {
        Add-Content (Join-Path $script:fixture 'README.md') 'A canary-proven repaired reusable workflow should pin bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.'
        & $script:invokeFixtureValidation | Should -Not -Be 0
        $script:output -join "`n" | Should -Match 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    }
}
