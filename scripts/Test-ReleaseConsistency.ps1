[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = '.',

    [Parameter()]
    [switch]$SkipTagVerification
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Path).Path
$failures = [System.Collections.Generic.List[string]]::new()

function Get-RequiredText {
    param([Parameter(Mandatory)][string]$RelativePath)
    $fullPath = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $failures.Add("Required file '$RelativePath' is missing.")
        return ''
    }
    return Get-Content -LiteralPath $fullPath -Raw
}

$version = (Get-RequiredText 'VERSION').Trim()
$changelog = Get-RequiredText 'CHANGELOG.md'
$readme = Get-RequiredText 'README.md'
$status = Get-RequiredText 'docs/RELEASE_STATUS.md'

if ($version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
    $failures.Add("VERSION '$version' is not canonical semantic version syntax.")
}
$isPublished = $version -and $status -match [regex]::Escape(('latest published version is `{0}`' -f $version))
$isPrepared = $version -and $status -match [regex]::Escape(('prepared version is `{0}` and is unpublished' -f $version))
if ($isPublished -eq $isPrepared) {
    $failures.Add('Release status must declare exactly one canonical state: published or prepared and unpublished.')
}

$releaseDocument = "docs/releases/$version.md"
if ($version -and -not (Test-Path -LiteralPath (Join-Path $root $releaseDocument) -PathType Leaf)) {
    $failures.Add("Released-version document '$releaseDocument' is missing.")
}

if ($changelog -notmatch '(?m)^## \[Unreleased\]\s*$') {
    $failures.Add("CHANGELOG.md is missing an [Unreleased] section.")
}
if ($version -and $changelog -notmatch "(?m)^## \[$([regex]::Escape($version))\](?:\s|$)") {
    $failures.Add("CHANGELOG.md has no released section for VERSION '$version'.")
}

$fullShaPattern = '[0-9a-f]{40}'
$targetMatch = [regex]::Match($status, ('resolves to immutable commit `{0}`' -f "($fullShaPattern)"))
$tagObjectMatch = [regex]::Match($status, ('tag-object SHA `{0}`' -f "($fullShaPattern)"))
$readmeTargetMatch = [regex]::Match($readme, ('resolves to immutable commit `{0}`' -f "($fullShaPattern)"))
$readmeTagMatch = [regex]::Match($readme, 'Annotated tag `(v[^`]+)` resolves to immutable commit')
$statusTagMatch = [regex]::Match($status, 'Annotated tag `(v[^`]+)` has tag-object SHA')
if ($isPublished -and -not $targetMatch.Success) {
    $failures.Add('Release status does not identify the published target as a full immutable commit SHA.')
}
if ($isPublished -and -not $tagObjectMatch.Success) {
    $failures.Add('Release status does not identify the annotated tag object as a full SHA.')
}
if ($isPublished -and (-not $readmeTargetMatch.Success -or
    ($targetMatch.Success -and $readmeTargetMatch.Groups[1].Value -ne $targetMatch.Groups[1].Value))) {
    $failures.Add('README published target does not match release status.')
}

if ($version) {
    foreach ($record in @($readme, $status)) {
        $colonPhrase = 'published version: `{0}`' -f $version
        $sentencePhrase = 'published version is `{0}`' -f $version
        $preparedPhrase = 'prepared version is `{0}` and is unpublished' -f $version
        if (($isPublished -and $record -notmatch [regex]::Escape($colonPhrase) -and
            $record -notmatch [regex]::Escape($sentencePhrase)) -or
            ($isPrepared -and $record -notmatch [regex]::Escape($preparedPhrase))) {
            $failures.Add("A current release summary does not identify the canonical state for version '$version'.")
        }
    }
}

if ($readme -notmatch 'docs/RELEASE_STATUS\.md' -or $readme -notmatch 'CHANGELOG\.md#unreleased') {
    $failures.Add('README.md must link to release status and [Unreleased].')
}
if ($isPublished -and
    (-not $readmeTagMatch.Success -or $readmeTagMatch.Groups[1].Value -ne "v$version" -or
     -not $statusTagMatch.Success -or $statusTagMatch.Groups[1].Value -ne "v$version")) {
    $failures.Add("README and release status must identify expected tag 'v$version'.")
}
if ($status -notmatch '(?i)does not validate current `master`') {
    $failures.Add('Release status does not bound historical evidence to its recorded commit.')
}

$gitDirectory = Join-Path $root '.git'
if ($isPublished -and -not $SkipTagVerification -and (Test-Path -LiteralPath $gitDirectory)) {
    $tagName = "v$version"
    & git -C $root rev-parse --verify --quiet "$tagName^{}" *> $null
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Published tag '$tagName' does not exist locally.")
    }
    elseif ($targetMatch.Success) {
        $tagType = (& git -C $root cat-file -t $tagName 2>$null).Trim()
        if ($tagType -ne 'tag') {
            $failures.Add("Published tag '$tagName' must be an annotated tag object; found '$tagType'.")
        }

        $actualTagObject = (& git -C $root rev-parse $tagName 2>$null).Trim()
        if ($tagObjectMatch.Success -and $actualTagObject -ne $tagObjectMatch.Groups[1].Value) {
            $failures.Add("Recorded tag object '$($tagObjectMatch.Groups[1].Value)' does not match local tag object '$actualTagObject'.")
        }

        $actualTarget = (& git -C $root rev-parse "$tagName^{}" 2>$null).Trim()
        if ($actualTarget -ne $targetMatch.Groups[1].Value) {
            $failures.Add("Recorded tag target '$($targetMatch.Groups[1].Value)' does not match local tag target '$actualTarget'.")
        }

        $postTagCount = [int]((& git -C $root rev-list --count "$tagName^{}..HEAD" 2>$null).Trim())
        $unreleasedMatch = [regex]::Match($changelog, '(?ms)^## \[Unreleased\]\s*$(.*?)(?=^## |\z)')
        $substantiveUnreleasedLines = @()
        if ($unreleasedMatch.Success) {
            $substantiveUnreleasedLines = @($unreleasedMatch.Groups[1].Value -split '\r?\n' | Where-Object {
                $line = $_.Trim()
                $line -and $line -notmatch '^#' -and $line -notmatch '^No unreleased changes are currently recorded\.?$'
            })
        }
        if ($postTagCount -gt 0 -and $substantiveUnreleasedLines.Count -eq 0) {
            $failures.Add('Post-tag commits exist while the [Unreleased] section has no substantive entries.')
        }
        if ($postTagCount -eq 0 -and $substantiveUnreleasedLines.Count -gt 0) {
            $failures.Add('No post-tag commits exist but the [Unreleased] section contains substantive entries.')
        }
        if ($postTagCount -gt 0 -and $changelog -match '(?im)^No unreleased changes are currently recorded\.?\s*$') {
            $failures.Add('Post-tag commits exist while CHANGELOG.md claims no unreleased changes.')
        }
        if ($postTagCount -gt 0 -and $status -notmatch '(?i)current `master` contains development after the published target') {
            $failures.Add('Release status does not distinguish current master from the published target.')
        }
    }
}

foreach ($line in ($status -split '\r?\n')) {
    if ($line -match '(?i)(?:tag|GitHub Release).*(?:pending|not published|not created)' -and
        $line -notmatch '(?i)retains stale preparation-era statements' -and
        -not ($isPrepared -and $line -match '(?i)prepared version.*unpublished')) {
        $failures.Add('Current published release status contains stale pending-publication wording.')
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Error $failure }
    exit 1
}

Write-Host "Release consistency validation passed for published version $version."
exit 0
