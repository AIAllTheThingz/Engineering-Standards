BeforeAll {
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:resolver = Join-Path $script:repoRoot 'scripts/Resolve-ReusableWorkflowIdentity.ps1'
    $script:workflowPath = Join-Path $script:repoRoot '.github/workflows/governance-ci-reusable.yml'
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

function script:New-AnnotatedTestTag {
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Message
    )

    & git -C $script:repoRoot `
        -c user.name='Engineering Standards Test' `
        -c user.email='engineering-standards-test@example.invalid' `
        tag -a $Tag -m $Message $Target
    $LASTEXITCODE | Should -Be 0
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
        New-AnnotatedTestTag -Tag $tag -Target $script:head -Message 'Synthetic annotated workflow identity tag'
        $tagObject = (& git -C $script:repoRoot rev-parse --verify "refs/tags/$tag").Trim()

        $result = Invoke-IdentityResolver -WorkflowSha $tagObject -Reference "${script:workflowPrefix}refs/tags/$tag"

        $result.ExitCode | Should -Be 0 -Because $result.Output
        $identity = $result.Output | ConvertFrom-Json
        $identity.referenceKind | Should -BeExactly 'AnnotatedTag'
        $identity.workflowRef | Should -BeExactly "${script:workflowPrefix}refs/tags/$tag"
        $identity.workflowObjectSha | Should -BeExactly $tagObject
        $identity.standardsCommitSha | Should -BeExactly $script:head
    }

    It 'rejects a lightweight semantic-version tag' {
        $tag = New-TestTagName -Suffix lightweight
        $script:createdTags.Add($tag)
        & git -C $script:repoRoot tag $tag $script:head
        $LASTEXITCODE | Should -Be 0
        $tagObject = (& git -C $script:repoRoot rev-parse --verify "refs/tags/$tag").Trim()

        $result = Invoke-IdentityResolver -WorkflowSha $tagObject -Reference "${script:workflowPrefix}refs/tags/$tag"

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'lightweight tags are not accepted'
    }

    It 'rejects a branch workflow ref even when its commit equals HEAD' {
        $result = Invoke-IdentityResolver -WorkflowSha $script:head -Reference "${script:workflowPrefix}refs/heads/master"

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'Branches and other refs are not accepted'
    }

    It 'rejects an annotated tag whose peeled commit is not the checked-out HEAD' {
        $parent = (& git -C $script:repoRoot rev-parse --verify 'HEAD^').Trim()
        $tag = New-TestTagName -Suffix stale
        $script:createdTags.Add($tag)
        New-AnnotatedTestTag -Tag $tag -Target $parent -Message 'Synthetic stale workflow identity tag'
        $tagObject = (& git -C $script:repoRoot rev-parse --verify "refs/tags/$tag").Trim()

        $result = Invoke-IdentityResolver -WorkflowSha $tagObject -Reference "${script:workflowPrefix}refs/tags/$tag"

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'peeled commit does not match'
    }

    It 'rejects a tag ref whose object does not match job.workflow_sha' {
        $tag = New-TestTagName -Suffix mismatch
        $script:createdTags.Add($tag)
        New-AnnotatedTestTag -Tag $tag -Target $script:head -Message 'Synthetic mismatch workflow identity tag'

        $result = Invoke-IdentityResolver -WorkflowSha $script:head -Reference "${script:workflowPrefix}refs/tags/$tag"

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

    It 'records the workflow object, peeled commit, ref, and reference kind in hosted environment evidence' {
        $workflow = Get-Content -LiteralPath $script:workflowPath -Raw

        $workflow | Should -Match 'STANDARDS_WORKFLOW_SHA:\s*\$\{\{\s*steps\.inputs\.outputs\.standards-commit-sha\s*\}\}'
        $workflow | Should -Match 'STANDARDS_WORKFLOW_OBJECT_SHA:\s*\$\{\{\s*job\.workflow_sha\s*\}\}'
        $workflow | Should -Match 'STANDARDS_WORKFLOW_REF:\s*\$\{\{\s*job\.workflow_ref\s*\}\}'
        $workflow | Should -Match "STANDARDS_WORKFLOW_REFERENCE_KIND:\s*\$\{\{\s*steps\.inputs\.outputs\.workflow-reference-kind\s*\|\|\s*'Unresolved'\s*\}\}"
        $workflow | Should -Match 'standardsWorkflowSha\s*=\s*\$resolvedStandardsSha'
        $workflow | Should -Match 'standardsWorkflowObjectSha\s*=\s*\$env:STANDARDS_WORKFLOW_OBJECT_SHA'
        $workflow | Should -Match 'standardsWorkflowRef\s*=\s*\$env:STANDARDS_WORKFLOW_REF'
        $workflow | Should -Match 'standardsWorkflowReferenceKind\s*=\s*\$env:STANDARDS_WORKFLOW_REFERENCE_KIND'
        $workflow | Should -Not -Match 'steps\.inputs\.outputs\.standards-commit-sha\s*\|\|\s*job\.workflow_sha'
    }

    It 'persists verified identity before caller input validation can fail' {
        $workflow = Get-Content -LiteralPath $script:workflowPath -Raw
        $identityOutputIndex = $workflow.IndexOf('"standards-commit-sha=$($identity.standardsCommitSha)"')
        $identityResolvedIndex = $workflow.IndexOf("'identity-resolved=true'")
        $projectValidationIndex = $workflow.IndexOf("project-path must not be empty.")

        $identityOutputIndex | Should -BeGreaterOrEqual 0
        $identityResolvedIndex | Should -BeGreaterOrEqual 0
        $projectValidationIndex | Should -BeGreaterOrEqual 0
        $identityOutputIndex | Should -BeLessThan $projectValidationIndex
        $identityResolvedIndex | Should -BeLessThan $projectValidationIndex
        $workflow | Should -Match 'input-validation-error=\$inputError'
        $workflow | Should -Match 'caller input validation failed after workflow identity was verified'
    }
}
