<#
.SYNOPSIS
Resolves and verifies the immutable identity of the reusable governance workflow.
.DESCRIPTION
Validates GitHub reusable-workflow provenance without weakening commit binding.
A direct full commit pin must match both job.workflow_sha and checkout HEAD.
An annotated release tag must resolve to the exact tag-object SHA reported by
GitHub and peel to checkout HEAD. Branches, lightweight tags, malformed refs,
unexpected repositories, and unexpected workflow paths fail closed.
.PARAMETER Path
Path to the checked-out Engineering Standards repository.
.PARAMETER StandardsRepository
GitHub owner/name reported by job.workflow_repository.
.PARAMETER WorkflowPath
Expected reusable workflow path. Defaults to the governed reusable workflow.
.PARAMETER WorkflowSha
Full SHA reported by job.workflow_sha. For an annotated tag GitHub reports the
tag-object SHA; for a direct commit pin it reports the commit SHA.
.PARAMETER WorkflowRef
Full job.workflow_ref value.
.EXAMPLE
pwsh -NoProfile -File scripts/Resolve-ReusableWorkflowIdentity.ps1 -Path . -StandardsRepository AIAllTheThingz/Engineering-Standards -WorkflowSha $sha -WorkflowRef $ref
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [Parameter(Mandatory)][string]$StandardsRepository,
    [string]$WorkflowPath = '.github/workflows/governance-ci-reusable.yml',
    [Parameter(Mandatory)][string]$WorkflowSha,
    [Parameter(Mandatory)][string]$WorkflowRef
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedRepository = 'AIAllTheThingz/Engineering-Standards'
$expectedWorkflowPath = '.github/workflows/governance-ci-reusable.yml'

function Invoke-IdentityGit {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = @(& git -C $root @Arguments 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Git identity query failed: git $($Arguments -join ' ')"
    }
    (($output -join "`n").Trim())
}

$root = (Resolve-Path -LiteralPath $Path).Path
if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
    throw 'Reusable workflow identity validation requires a Git checkout.'
}
if ($StandardsRepository -cne $expectedRepository) {
    throw "Unexpected standards workflow repository '$StandardsRepository'."
}
if ($WorkflowPath -cne $expectedWorkflowPath) {
    throw "Unexpected reusable workflow path '$WorkflowPath'."
}
if ($WorkflowSha -cnotmatch '^[0-9a-f]{40}$') {
    throw 'job.workflow_sha must be a lowercase full 40-character hexadecimal object SHA.'
}

$expectedPrefix = "$expectedRepository/$expectedWorkflowPath@"
if (-not $WorkflowRef.StartsWith($expectedPrefix, [StringComparison]::Ordinal)) {
    throw "Unexpected reusable workflow ref '$WorkflowRef'."
}
$reference = $WorkflowRef.Substring($expectedPrefix.Length)
if ([string]::IsNullOrWhiteSpace($reference)) {
    throw 'Reusable workflow ref is missing its immutable reference component.'
}

$head = Invoke-IdentityGit -Arguments @('rev-parse', '--verify', 'HEAD^{commit}')
if ($head -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Checked-out standards HEAD did not resolve to a full commit SHA.'
}

$referenceKind = $null
$commitSha = $null
if ($reference -cmatch '^[0-9a-f]{40}$') {
    if ($reference -cne $WorkflowSha) {
        throw 'Direct commit workflow_ref does not match job.workflow_sha.'
    }
    $objectType = Invoke-IdentityGit -Arguments @('cat-file', '-t', $WorkflowSha)
    if ($objectType -cne 'commit') {
        throw 'Direct immutable workflow reference must identify a commit object.'
    }
    if ($head -cne $WorkflowSha) {
        throw 'Standards checkout HEAD does not match the direct immutable reusable workflow commit.'
    }
    $referenceKind = 'Commit'
    $commitSha = $head
}
elseif ($reference -cmatch '^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$') {
    $tagObjectSha = Invoke-IdentityGit -Arguments @('rev-parse', '--verify', $reference)
    if ($tagObjectSha -cne $WorkflowSha) {
        throw 'Annotated workflow tag ref does not resolve to the tag-object SHA reported by job.workflow_sha.'
    }
    $objectType = Invoke-IdentityGit -Arguments @('cat-file', '-t', $WorkflowSha)
    if ($objectType -cne 'tag') {
        throw 'Published workflow tag refs must identify annotated tag objects; lightweight tags are not accepted.'
    }
    $peeledCommit = Invoke-IdentityGit -Arguments @('rev-parse', '--verify', "$reference^{}")
    $peeledType = Invoke-IdentityGit -Arguments @('cat-file', '-t', $peeledCommit)
    if ($peeledType -cne 'commit') {
        throw 'Annotated workflow tag did not peel to a commit object.'
    }
    if ($peeledCommit -cne $head) {
        throw 'Annotated workflow tag peeled commit does not match the checked-out standards HEAD.'
    }
    $referenceKind = 'AnnotatedTag'
    $commitSha = $peeledCommit
}
else {
    throw 'Reusable workflow ref must be a full immutable commit SHA or an annotated refs/tags/v<semver> release tag. Branches and other refs are not accepted.'
}

[ordered]@{
    schemaVersion = '1.0.0'
    status = 'Passed'
    standardsRepository = $StandardsRepository
    workflowPath = $WorkflowPath
    workflowRef = $WorkflowRef
    workflowObjectSha = $WorkflowSha
    referenceKind = $referenceKind
    standardsCommitSha = $commitSha
} | ConvertTo-Json -Depth 8
