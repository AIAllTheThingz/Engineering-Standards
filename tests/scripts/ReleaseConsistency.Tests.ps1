Describe 'Release consistency validation' {
    BeforeAll {
        $script:validator = Join-Path $PSScriptRoot '../../scripts/Test-ReleaseConsistency.ps1'
        $script:invokeFixtureValidation = {
            $script:output = @(& pwsh -NoProfile -File $script:validator -Path $script:fixture 2>&1)
            return $LASTEXITCODE
        }
    }

    BeforeEach {
        $script:fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('release-consistency-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $script:fixture 'docs/releases') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:fixture 'VERSION') -Value '1.1.0'
        Set-Content -LiteralPath (Join-Path $script:fixture 'CHANGELOG.md') -Value @'
# Changelog

## [Unreleased]

### Fixed

- A post-release correction.

## [1.1.0] - 2026-07-11
'@
        Set-Content -LiteralPath (Join-Path $script:fixture 'README.md') -Value @'
# Repository

Current published version: `1.1.0`. See [Release Status](docs/RELEASE_STATUS.md) and [Unreleased](CHANGELOG.md#unreleased).
'@
        Set-Content -LiteralPath (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') -Value @'
# Release Status

The latest published version is `1.1.0`. Annotated tag `v1.1.0` has tag-object SHA `1111111111111111111111111111111111111111` and resolves to immutable commit `1111111111111111111111111111111111111111`.

Current `master` contains development after the published target. Historical evidence does not validate current `master`.
'@
        Set-Content -LiteralPath (Join-Path $script:fixture 'docs/releases/1.1.0.md') -Value '# Release 1.1.0'
    }

    AfterEach {
        if ($script:fixture -and (Test-Path -LiteralPath $script:fixture)) {
            Remove-Item -LiteralPath $script:fixture -Recurse -Force
        }
    }

    It 'accepts a valid published release with unreleased development' {
        & $script:invokeFixtureValidation | Should -Be 0
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
        } finally { Pop-Location }
        & $script:invokeFixtureValidation | Should -Be 0
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
            Add-Content README.md 'post tag'; git add .; git commit -qm later
            Set-Content CHANGELOG.md "# Changelog`n`n## [Unreleased]`n`nNo unreleased changes are currently recorded.`n`n## [1.1.0] - 2026-07-11"
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
        (Get-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md') -Raw).Replace('does not validate current `master`', 'validates current `master`') | Set-Content (Join-Path $script:fixture 'docs/RELEASE_STATUS.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }

    It 'fails README and release-status disagreement' {
        (Get-Content (Join-Path $script:fixture 'README.md') -Raw).Replace('1.1.0', '1.0.0') | Set-Content (Join-Path $script:fixture 'README.md')
        & $script:invokeFixtureValidation | Should -Not -Be 0
    }
}
