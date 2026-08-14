BeforeAll {
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:resolver = Join-Path $script:repoRoot 'scripts/Resolve-ReusableWorkflowIdentity.ps1'
    $script:workflowPrefix = 'AIAllTheThingz/Engineering-Standards/.github/workflows/governance-ci-reusable.yml@'
    $script:head = (& git -C $script:repoRoot rev-parse --verify 'HEAD^{commit}').Trim()
    $script:createdTags = [System.Collections.Generic.List[string]]::new()
}

AfterAll {
    foreach ($tag in $script:createdTags) {
        & git -C $script:repoRoot tag -d $tag *> $null
    }
}

function script:Invoke-IdentityResolver {
    param(
        [Parameter(Mandatory)][string]$WorkflowSha,
        [Parameter(Mandatory)][string]$Reference,
        [string]$WorkflowPath = '.github/workflows/governance-ci-reusable.yml',
        [string]$Repository = 'AIAllTheThingz/Engineering-Standards'
    )

    $output = @(& pwsh -NoProfile -File $script:resolver `
        -Path $script:repoRoot `
        -StandardsRepository $Repository `
        -WorkflowPath $WorkflowPath `
        -WorkflowSha $WorkflowSha `
        -WorkflowRef $Reference 2>&1)
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = (($output | ForEach-Object { [string]$_ }) -join "`n")
    }
}

function script:New-TestTagName {
    param([string]$Suffix)
    "v999.0.0-$Suffix-$([guid]::NewGuid().ToString('N').Substring(0, 10))"
}

Describe 'Reusable workflow immutable identity resolution' {
    It 'accepts a direct immutable commit reference' {
        $result = Invoke-IdentityResolver -WorkflowSha $script:head -Reference "$script:workflowPrefix$script:head"

        $result.ExitCode | Should -Be 0 -Because $result.Output
        $identity = $result.Output | ConvertFrom-Json
        $identity.status | Should -BeExactly 'Passed'
        $identity.referenceKind | Should -BeExactly 'Commit'
        $identity.workflowObjectSha | Should -BeExactly $script:head
        $identity.standardsCommitSha | Should -BeExactly $script:head
    }

    It 'accepts an annotated semantic-version tag object that peels to HEAD' {
        $tag = New-TestTagName -Suffix annotated
        $script:createdTags.Add($tag)
        & git -C $script:repoRoot tag -a $tag -m "Synthetic annotated workflow identity tag" $script:head
        $LASTEXITCODE | Should -Be 0
        $tagObject = (& git -C $script:repoRoot rev-parse --verify "refs/tags/$tag").Trim()

        $result = Invoke-IdentityResolver -WorkflowSha $tagObject -Reference "$script:workflowPrefix`refs/tags/$tag"

        $result.ExitCode | Should -Be 0 -Because $result.Output
        $identity = $result.Output | ConvertFrom-Json
        $identity.referenceKind | Should -BeExactly 'AnnotatedTag'
        $identity.workflowObjectSha | Should -BeExactly $tagObject
        $identity.standardsCommitSha | Should -BeExactly $script:head
    }

    It 'rejects a lightweight semantic-version tag' {
        $tag = New-TestTagName -Suffix lightweight
        $script:createdTags.Add($tag)
        & git -C $script:repoRoot tag $tag $script:head
        $LASTEXITCODE | Should -Be 0
        $tagObject = (& git -C $script:repoRoot rev-parse --verify "refs/tags/$tag").Trim()

        $result = Invoke-IdentityResolver -WorkflowSha $tagObject -Reference "$script:workflowPrefix`refs/tags/$tag"

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'lightweight tags are not accepted'
    }

    It 'rejects a branch workflow ref even when its commit equals HEAD' {
        $result = Invoke-IdentityResolver -WorkflowSha $script:head -Reference "$script:workflowPrefix`refs/heads/master"

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Branches and other refs are not accepted'
    }

    It 'rejects an annotated tag whose peeled commit is not the checked-out HEAD' {
        $parent = (& git -C $script:repoRoot rev-parse --verify 'HEAD^').Trim()
        $tag = New-TestTagName -Suffix stale
        $script:createdTags.Add($tag)
        & git -C $script:repoRoot tag -a $tag -m "Synthetic stale workflow identity tag" $parent
        $LASTEXITCODE | Should -Be 0
        $tagObject = (& git -C $script:repoRoot rev-parse --verify "refs/tags/$tag").Trim()

        $result = Invoke-IdentityResolver -WorkflowSha $tagObject -Reference "$script:workflowPrefix`refs/tags/$tag"

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'peeled commit does not match'
    }

    It 'rejects a tag ref whose object does not match job.workflow_sha' {
        $tag = New-TestTagName -Suffix mismatch
        $script:createdTags.Add($tag)
        & git -C $script:repoRoot tag -a $tag -m "Synthetic mismatch workflow identity tag" $script:head
        $LASTEXITCODE | Should -Be 0

        $result = Invoke-IdentityResolver -WorkflowSha $script:head -Reference "$script:workflowPrefix`refs/tags/$tag"

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'tag-object SHA reported by job.workflow_sha'
    }

    It 'rejects an unexpected workflow path and malformed ref' {
        $wrongPath = Invoke-IdentityResolver -WorkflowSha $script:head -WorkflowPath '.github/workflows/other.yml' -Reference "$script:workflowPrefix$script:head"
        $wrongPath.ExitCode | Should -Not -Be 0
        $wrongPath.Output | Should -Match 'Unexpected reusable workflow path'

        $malformed = Invoke-IdentityResolver -WorkflowSha $script:head -Reference 'not-a-workflow-ref'
        $malformed.ExitCode | Should -Not -Be 0
        $malformed.Output | Should -Match 'Unexpected reusable workflow ref'
    }

    It 'rejects an unexpected standards repository' {
        $result = Invoke-IdentityResolver -WorkflowSha $script:head -Repository 'ExampleOrg/Other' -Reference "$script:workflowPrefix$script:head"

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Unexpected standards workflow repository'
    }
}
