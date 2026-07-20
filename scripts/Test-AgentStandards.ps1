<#
.SYNOPSIS
Validates AI-agent instruction standard consistency.
.DESCRIPTION
Checks the base and repository-root AGENTS documents for hierarchy, inheritance,
mandatory work phases, evidence semantics, repository commands, technology
standard references, placeholders, and broken relative links.
.PARAMETER Path
Repository root.
.PARAMETER OutputJson
Optional structured JSON output path.
.EXAMPLE
pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GovernanceValidation.psm1') -Force

$root = (Resolve-Path -LiteralPath $Path).Path
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [ValidateSet('Passed','Failed','NotRun','Blocked','NotApplicable')][string]$Status,
        [string]$Message,
        [string]$RelativePath,
        [ValidateSet('info','warning','error')][string]$Severity = $(if ($Status -eq 'Passed' -or $Status -eq 'NotApplicable') { 'info' } else { 'error' })
    )
    $results.Add((New-ValidationResult -Status $Status -Message $Message -Path $RelativePath -Severity $Severity))
}

function Get-RelativePath {
    param([string]$FullPath)
    [System.IO.Path]::GetRelativePath($root, $FullPath).Replace('\','/')
}

function Get-WordCount {
    param([string]$Text)
    @($Text -split '\s+' | Where-Object { $_ }).Count
}

function Test-Contains {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message,
        [string]$RelativePath
    )
    if ($Text -match $Pattern) {
        Add-Result Passed $Message $RelativePath
    }
    else {
        Add-Result Failed $Message $RelativePath
    }
}

function Test-MinimumSemanticVersion {
    param(
        [string]$Text,
        [string]$MinimumVersion,
        [string]$Message,
        [string]$RelativePath
    )

    if ($Text -notmatch '(?im)^\|\s*Version\s*\|\s*(?<version>[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)\s*\|') {
        Add-Result Failed $Message $RelativePath
        return
    }

    $rawVersion = $Matches['version']
    $versionCore = ($rawVersion -split '[-+]')[0]
    $minimumCore = ($MinimumVersion -split '[-+]')[0]
    try {
        $actual = [version]$versionCore
        $minimum = [version]$minimumCore
        if ($actual -ge $minimum) {
            Add-Result Passed $Message $RelativePath
        }
        else {
            Add-Result Failed $Message $RelativePath
        }
    }
    catch {
        Add-Result Failed $Message $RelativePath
    }
}

function Test-MarkdownRelativeLinks {
    param(
        [string]$Text,
        [string]$FullPath
    )
    $relativeFile = Get-RelativePath -FullPath $FullPath
    foreach ($match in [regex]::Matches($Text, '(?<!!)\[[^\]]+\]\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target -match '^(https?:|mailto:|#)' -or $target -eq '') { continue }
        $target = $target.Split('#')[0].Trim('<','>')
        if ($target -eq '') { continue }
        try {
            $resolved = if ([System.IO.Path]::IsPathRooted($target)) {
                [System.IO.Path]::GetFullPath($target)
            }
            else {
                [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $FullPath) $target))
            }
            if (-not $resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                Add-Result Failed "Relative link '$target' resolves outside the repository." $relativeFile
            }
            elseif (-not (Test-Path -LiteralPath $resolved)) {
                Add-Result Failed "Relative link '$target' is broken." $relativeFile
            }
        }
        catch {
            Add-Result Failed "Relative link '$target' could not be resolved: $($_.Exception.Message)" $relativeFile
        }
    }
}

$basePath = Join-Path $root 'agents/AGENTS_Base.md'
$rootPath = Join-Path $root 'AGENTS.md'
$powerShellPath = Join-Path $root 'agents/AGENTS_PowerShell.md'
$dotNetPath = Join-Path $root 'agents/AGENTS_DotNet.md'
$webFrontendPath = Join-Path $root 'agents/AGENTS_WebFrontend.md'
$databasePath = Join-Path $root 'agents/AGENTS_Database.md'
$workerPath = Join-Path $root 'agents/AGENTS_WorkerService.md'
$integrationPath = Join-Path $root 'agents/AGENTS_Integration.md'
$infrastructurePath = Join-Path $root 'agents/AGENTS_Infrastructure.md'
$pythonPath = Join-Path $root 'agents/AGENTS_Python.md'
$bashPath = Join-Path $root 'agents/AGENTS_Bash.md'

if (-not (Test-Path -LiteralPath $basePath -PathType Leaf)) {
    Add-Result Failed 'AGENTS_Base.md exists.' 'agents/AGENTS_Base.md'
}
else {
    Add-Result Passed 'AGENTS_Base.md exists.' 'agents/AGENTS_Base.md'
}

if (-not (Test-Path -LiteralPath $rootPath -PathType Leaf)) {
    Add-Result Failed 'Root AGENTS.md exists.' 'AGENTS.md'
}
else {
    Add-Result Passed 'Root AGENTS.md exists.' 'AGENTS.md'
}

if (-not (Test-Path -LiteralPath $basePath -PathType Leaf) -or -not (Test-Path -LiteralPath $rootPath -PathType Leaf)) {
    $report = New-ValidationReport -Results @($results)
    Write-ValidationReport -Report $report -OutputJson $OutputJson
    exit 1
}

$base = Get-Content -LiteralPath $basePath -Raw
$rootAgents = Get-Content -LiteralPath $rootPath -Raw
$powerShellAgents = if (Test-Path -LiteralPath $powerShellPath -PathType Leaf) { Get-Content -LiteralPath $powerShellPath -Raw } else { '' }
$dotNetAgents = if (Test-Path -LiteralPath $dotNetPath -PathType Leaf) { Get-Content -LiteralPath $dotNetPath -Raw } else { '' }
$webFrontendAgents = if (Test-Path -LiteralPath $webFrontendPath -PathType Leaf) { Get-Content -LiteralPath $webFrontendPath -Raw } else { '' }
$databaseAgents = if (Test-Path -LiteralPath $databasePath -PathType Leaf) { Get-Content -LiteralPath $databasePath -Raw } else { '' }
$workerAgents = if (Test-Path -LiteralPath $workerPath -PathType Leaf) { Get-Content -LiteralPath $workerPath -Raw } else { '' }
$integrationAgents = if (Test-Path -LiteralPath $integrationPath -PathType Leaf) { Get-Content -LiteralPath $integrationPath -Raw } else { '' }
$infrastructureAgents = if (Test-Path -LiteralPath $infrastructurePath -PathType Leaf) { Get-Content -LiteralPath $infrastructurePath -Raw } else { '' }
$pythonAgents = if (Test-Path -LiteralPath $pythonPath -PathType Leaf) { Get-Content -LiteralPath $pythonPath -Raw } else { '' }
$bashAgents = if (Test-Path -LiteralPath $bashPath -PathType Leaf) { Get-Content -LiteralPath $bashPath -Raw } else { '' }

if ($base -match '(?im)\binherits?\s+(?:\[[^\]]+\]\()?AGENTS_Base\.md|inherits?\s+itself|inherits?\s+this\s+base') {
    Add-Result Failed 'Base standard does not claim to inherit itself.' 'agents/AGENTS_Base.md'
}
else {
    Add-Result Passed 'Base standard does not claim to inherit itself.' 'agents/AGENTS_Base.md'
}

Test-Contains $rootAgents '(?is)extends\s+\[?agents/AGENTS_Base\.md|inherits?.*agents/AGENTS_Base\.md' 'Root states that it extends the base standard.' 'AGENTS.md'
Test-Contains $rootAgents '(?im)Default branch\s*\|\s*`?master`?|\bdefault branch\b[^`\r\n]*`?master`?' 'Root declares master as the default branch.' 'AGENTS.md'

$hierarchyPatterns = @(
    'Organization governance documents',
    'agents/AGENTS_Base\.md',
    'technology-specific agent standards?',
    'Repository-root `?AGENTS\.md`?',
    'directory-local `?AGENTS\.md`?'
)
foreach ($pattern in $hierarchyPatterns) {
    Test-Contains $base $pattern "Required hierarchy includes '$pattern'." 'agents/AGENTS_Base.md'
}

foreach ($phase in @(
    'Phase 1 - Discovery',
    'Phase 2 - Validation Planning',
    'Phase 3 - Safe Implementation',
    'Phase 4 - Dry Run Or Simulation',
    'Phase 5 - Validation',
    'Phase 6 - Evidence',
    'Phase 7 - Final Review'
)) {
    Test-Contains $base ([regex]::Escape($phase)) "Required work phase '$phase' is present." 'agents/AGENTS_Base.md'
}

foreach ($status in @('Passed','Failed','Blocked','NotRun','NotApplicable')) {
    Test-Contains $base ([regex]::Escape("``$status``")) "Completion status '$status' is present." 'agents/AGENTS_Base.md'
}

foreach ($term in @('Fabricate test results','Fabricate GitHub runs','Fabricate artifact hashes','Fabricate citations','Claim external execution that did not happen')) {
    Test-Contains $base $term "Prohibited fabrication language includes '$term'." 'agents/AGENTS_Base.md'
}

Test-Contains $base 'EXCEPTION_PROCESS\.md' 'Base references the exception process.' 'agents/AGENTS_Base.md'
Test-Contains $rootAgents 'EXCEPTION_PROCESS\.md' 'Root references the exception process.' 'AGENTS.md'

$requiredCommands = @(
    'pwsh -NoProfile -File scripts/Invoke-GovernanceValidation.ps1 -Path . -RepositoryOwnerType User',
    'pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-YamlSyntax.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-GitHubWorkflowArchitecture.ps1 -Path . -DefaultBranch master',
    'pwsh -NoProfile -File scripts/Test-CodexSkills.ps1 -Path . -OutputJson .tmp/codex-skills-validation.json',
    'pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .',
    'pwsh -NoProfile -File actions/validate-contract/Invoke-ContractValidation.ps1 -Path .',
    'pwsh -NoProfile -File actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1 -Path . -OutputJson evidence/forbidden-patterns.json',
    'pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path . -RepositoryOwnerType User',
    'Invoke-Pester -Path tests -Output Detailed',
    'Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error',
    'git status --short',
    'git diff --check',
    'git diff',
    'git ls-files'
)

$requiredCommandsSectionMatch = [regex]::Match(
    $rootAgents,
    '(?ms)^## Required Local Commands\s*\r?\n(?<body>.*?)(?=^##\s|\z)'
)
$requiredCommandLines = @()
if ($requiredCommandsSectionMatch.Success) {
    foreach ($block in [regex]::Matches($requiredCommandsSectionMatch.Groups['body'].Value, '(?ms)^```(?:powershell|bash)?\s*\r?\n(?<commands>.*?)^```\s*$')) {
        $requiredCommandLines += @(
            $block.Groups['commands'].Value -split '\r?\n' |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ }
        )
    }
}
else {
    Add-Result Failed 'Required Local Commands section is present.' 'AGENTS.md'
}

foreach ($command in $requiredCommands) {
    if ($requiredCommandLines -ccontains $command) {
        Add-Result Passed "Required repository validation command is present: $command" 'AGENTS.md'
    }
    else {
        Add-Result Failed "Required repository validation command is missing: $command" 'AGENTS.md'
    }
}


$repositoryHealthCommandPrefix = 'pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1'
$repositoryHealthCommands = @($requiredCommandLines | Where-Object { $_.StartsWith($repositoryHealthCommandPrefix, [System.StringComparison]::Ordinal) })
$expectedRepositoryHealthCommand = 'pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path . -RepositoryOwnerType User'
if ($repositoryHealthCommands.Count -eq 1 -and $repositoryHealthCommands[0] -ceq $expectedRepositoryHealthCommand) {
    Add-Result Passed 'Required repository-health command declares the verified User owner type exactly once.' 'AGENTS.md'
}
else {
    Add-Result Failed 'Required repository-health command must declare exactly one -RepositoryOwnerType User argument with exact casing and no conflicting invocation.' 'AGENTS.md'
}

$placeholderPattern = '(?i)\b(TODO|TBD|REPLACE-ME|placeholder-only|lorem ipsum)\b'
foreach ($doc in @(@{ path = 'agents/AGENTS_Base.md'; text = $base }, @{ path = 'AGENTS.md'; text = $rootAgents })) {
    if ($doc.text -match $placeholderPattern) {
        Add-Result Failed 'Document contains unresolved placeholder text.' $doc.path
    }
    else {
        Add-Result Passed 'Document contains no unresolved placeholder text.' $doc.path
    }
}

Test-MarkdownRelativeLinks -Text $base -FullPath $basePath
Test-MarkdownRelativeLinks -Text $rootAgents -FullPath $rootPath

$technologyStandards = @(
    'agents/AGENTS_PowerShell.md',
    'agents/AGENTS_DotNet.md',
    'agents/AGENTS_WebFrontend.md',
    'agents/AGENTS_Database.md',
    'agents/AGENTS_WorkerService.md',
    'agents/AGENTS_Integration.md',
    'agents/AGENTS_Infrastructure.md',
    'agents/AGENTS_Python.md',
    'agents/AGENTS_Bash.md'
)
foreach ($standard in $technologyStandards) {
    if ($rootAgents.Contains($standard) -and (Test-Path -LiteralPath (Join-Path $root $standard) -PathType Leaf)) {
        Add-Result Passed "Technology-specific standard is referenced: $standard" 'AGENTS.md'
    }
    else {
        Add-Result Failed "Technology-specific standard is missing or unreferenced: $standard" 'AGENTS.md'
    }
}

if ($powerShellAgents) {
    $powerShellRequiredPatterns = @(
        @{ Pattern = '\$rootBoundary\s*=\s*\$resolvedRoot\s*\+\s*\[System\.IO\.Path\]::DirectorySeparatorChar'; Message = 'PowerShell path-boundary example creates an explicit root boundary.' },
        @{ Pattern = '\[switch\]\$AllowRoot'; Message = 'PowerShell path-boundary example controls root access explicitly.' },
        @{ Pattern = 'Prefix matching without a directory boundary is unsafe'; Message = 'PowerShell path-boundary guidance explains prefix-collision risk.' },
        @{ Pattern = 'reparse points, symlinks, junctions, UNC paths, or time-of-check/time-of-use changes'; Message = 'PowerShell path-boundary guidance documents additional filesystem risks.' },
        @{ Pattern = 'README documentation MUST include every public entry-point parameter and switch'; Message = 'PowerShell standard requires README documentation for every public parameter and switch.' },
        @{ Pattern = 'default value, accepted value or `ValidateSet` choice, required or optional status'; Message = 'PowerShell standard requires complete README parameter details.' },
        @{ Pattern = 'Hidden, undocumented, or behavior-changing public switches are prohibited'; Message = 'PowerShell standard prohibits hidden behavior-changing public switches.' },
        @{ Pattern = 'README parameter documentation and comment-based help MUST remain synchronized'; Message = 'PowerShell standard requires README and comment-based help synchronization.' },
        @{ Pattern = '\$certificates\.Count -eq 0'; Message = 'PowerShell signing example fails when no certificate matches.' },
        @{ Pattern = '\$certificates\.Count -gt 1'; Message = 'PowerShell signing example fails when multiple certificates match.' },
        @{ Pattern = '\$_.HasPrivateKey'; Message = 'PowerShell signing example validates private-key availability.' },
        @{ Pattern = '\$_.NotBefore -le \$now'; Message = 'PowerShell signing example validates certificate start date.' },
        @{ Pattern = '\$_.NotAfter -gt \$now'; Message = 'PowerShell signing example validates certificate expiration.' },
        @{ Pattern = 'Certificate discovery MUST NOT silently use `Select-Object -First 1` as the only selection safeguard'; Message = 'PowerShell signing guidance prohibits first-match selection.' },
        @{ Pattern = 'Signature status MUST be validated after signing with `Get-AuthenticodeSignature`'; Message = 'PowerShell signing guidance requires post-signing validation.' }
    )
    foreach ($item in $powerShellRequiredPatterns) {
        Test-Contains $powerShellAgents $item.Pattern $item.Message 'agents/AGENTS_PowerShell.md'
    }

    if ($powerShellAgents -match '(?s)Safe path-boundary validation example:.*\.StartsWith\(\s*\$resolvedRoot\s*,') {
        Add-Result Failed 'PowerShell path-boundary example uses unsafe direct root prefix matching.' 'agents/AGENTS_PowerShell.md'
    }
    else {
        Add-Result Passed 'PowerShell path-boundary example avoids unsafe direct root prefix matching.' 'agents/AGENTS_PowerShell.md'
    }

    $signingExampleText = if ($powerShellAgents -match '(?s)Safe signing examples:(?<example>.*?)Code-signing requirements:') {
        $Matches['example']
    }
    else {
        ''
    }
    if ($signingExampleText -match 'Select-Object\s+-First\s+1') {
        Add-Result Failed 'PowerShell signing example silently selects the first matching certificate.' 'agents/AGENTS_PowerShell.md'
    }
    else {
        Add-Result Passed 'PowerShell signing example avoids silent first-match certificate selection.' 'agents/AGENTS_PowerShell.md'
    }
}

if ($webFrontendAgents) {
    Test-MinimumSemanticVersion -Text $webFrontendAgents -MinimumVersion '1.1.1' -Message 'Web Frontend standard declares a valid semantic version at least 1.1.1.' -RelativePath 'agents/AGENTS_WebFrontend.md'

    $webFrontendRequiredPatterns = @(
        @{ Pattern = 'static HTML and CSS, JavaScript, TypeScript, React, Vue, Angular, Svelte, Next\.js, Nuxt, Remix, Astro'; Message = 'Web Frontend standard declares broad framework and tooling applicability.' },
        @{ Pattern = 'ASP\.NET Core hosting.*MUST also apply \[AGENTS_DotNet\.md\]'; Message = 'Web Frontend standard hands off ASP.NET Core and backend security.' },
        @{ Pattern = 'REST, GraphQL, gRPC-web, WebSocket, SignalR.*MUST also apply \[AGENTS_Integration\.md\]'; Message = 'Web Frontend standard hands off API and integration behavior.' },
        @{ Pattern = 'CDN, reverse proxy, load balancer, TLS termination, DNS, CSP headers.*MUST also apply \[AGENTS_Infrastructure\.md\]'; Message = 'Web Frontend standard hands off hosting and infrastructure behavior.' },
        @{ Pattern = 'Job submission, job status, script catalog, cancellation, replay, report links.*MUST also apply \[AGENTS_WorkerService\.md\]'; Message = 'Web Frontend standard hands off background-processing UI behavior.' },
        @{ Pattern = 'Database details MUST NOT be exposed directly to the browser'; Message = 'Web Frontend standard prohibits direct browser database exposure.' },
        @{ Pattern = 'PowerShell-generated frontend assets.*MUST also apply \[AGENTS_PowerShell\.md\]'; Message = 'Web Frontend standard hands off PowerShell-generated frontend work.' },
        @{ Pattern = 'Before editing frontend code, agents MUST identify and record the relevant subset of runtime and exact version'; Message = 'Web Frontend standard requires frontend discovery.' },
        @{ Pattern = 'Rendering model discovery MUST explicitly identify CSR, SSR, SSG, ISR, hybrid, MPA, or PWA behavior'; Message = 'Web Frontend standard requires rendering model discovery.' },
        @{ Pattern = 'Browser code is untrusted from the server''s perspective'; Message = 'Web Frontend standard treats browser code as untrusted.' },
        @{ Pattern = 'Every frontend repository MUST define one approved package manager'; Message = 'Web Frontend standard requires approved package manager.' },
        @{ Pattern = 'frozen or immutable lockfile install in CI'; Message = 'Web Frontend standard requires reproducible frozen-lockfile installation.' },
        @{ Pattern = 'No mixed lockfiles are allowed'; Message = 'Web Frontend standard prohibits mixed lockfiles.' },
        @{ Pattern = 'No production build may use an unlocked dependency graph'; Message = 'Web Frontend standard prohibits unlocked production dependency graphs.' },
        @{ Pattern = 'New or changed dependencies MUST be reviewed for package source, publisher, maintainer health, license, vulnerability status'; Message = 'Web Frontend standard requires dependency and supply-chain review.' },
        @{ Pattern = '`npm audit fix --force` or equivalent MUST NOT be run automatically'; Message = 'Web Frontend standard prohibits automatic force audit fixes.' },
        @{ Pattern = 'Every value embedded in a browser bundle MUST be treated as public'; Message = 'Web Frontend standard warns public browser variables are public.' },
        @{ Pattern = 'Prefixes such as `NEXT_PUBLIC_`, `VITE_`, or framework equivalents do not make values secret'; Message = 'Web Frontend standard warns public prefixes do not make secrets safe.' },
        @{ Pattern = 'Browser code MUST NOT contain private keys, database credentials, client secrets, server API keys, signing keys, privileged tokens'; Message = 'Web Frontend standard prohibits browser secrets.' },
        @{ Pattern = 'Authentication MUST be enforced server-side'; Message = 'Web Frontend standard requires server-side authentication.' },
        @{ Pattern = 'Every OAuth/OIDC browser flow MUST define identity provider and client type'; Message = 'Web Frontend standard requires OAuth/OIDC browser-flow definition.' },
        @{ Pattern = 'Public browser clients MUST use Authorization Code flow with PKCE'; Message = 'Web Frontend standard requires PKCE for public browser clients.' },
        @{ Pattern = 'Implicit flow MUST NOT be used for new browser applications'; Message = 'Web Frontend standard prohibits new implicit-flow browser applications.' },
        @{ Pattern = 'Resource Owner Password Credentials flow MUST NOT be used for browser applications'; Message = 'Web Frontend standard prohibits ROPC for browser applications.' },
        @{ Pattern = 'OAuth state MUST be high entropy, transaction-bound, validated on return, and consumed once'; Message = 'Web Frontend standard requires OAuth state lifecycle controls.' },
        @{ Pattern = 'OIDC nonce MUST be generated, transaction-bound, validated, and consumed once'; Message = 'Web Frontend standard requires OIDC nonce lifecycle controls.' },
        @{ Pattern = 'Redirect URIs MUST be exact, allowlisted, environment-specific, and registered'; Message = 'Web Frontend standard requires exact allowlisted redirect URIs.' },
        @{ Pattern = 'Tokens MUST NOT appear in query strings, fragments, browser history, referrers, analytics, or logs'; Message = 'Web Frontend standard prohibits tokens in URLs and telemetry paths.' },
        @{ Pattern = 'Refresh tokens require provider support, rotation, reuse detection where available, bounded lifetime, revocation, and approved storage'; Message = 'Web Frontend standard governs refresh-token rotation and reuse detection.' },
        @{ Pattern = 'Session fixation MUST be prevented by rotating or replacing session state at login and privilege elevation'; Message = 'Web Frontend standard requires session-fixation protection.' },
        @{ Pattern = 'Account or tenant switching MUST clear prior identity, cache, and authorization state'; Message = 'Web Frontend standard requires account and tenant switch cleanup.' },
        @{ Pattern = 'Frontend route guards are UX controls only'; Message = 'Web Frontend standard limits route guards to UX.' },
        @{ Pattern = 'Hiding a button is not authorization'; Message = 'Web Frontend standard rejects hidden-button authorization.' },
        @{ Pattern = 'Disabling a control is not authorization'; Message = 'Web Frontend standard rejects disabled-control authorization.' },
        @{ Pattern = 'Admin routes MUST be server-protected and direct navigation to admin routes MUST receive server denial when unauthorized'; Message = 'Web Frontend standard requires admin direct-navigation protection.' },
        @{ Pattern = 'Sensitive session tokens SHOULD use Secure, HttpOnly cookies where architecture supports it'; Message = 'Web Frontend standard requires secure cookie/token posture.' },
        @{ Pattern = 'Privileged or long-lived tokens MUST NOT be stored in localStorage or sessionStorage unless an approved threat model and exception require it'; Message = 'Web Frontend standard restricts privileged tokens in localStorage/sessionStorage.' },
        @{ Pattern = 'Untrusted HTML MUST NOT be inserted directly'; Message = 'Web Frontend standard prohibits direct untrusted HTML insertion.' },
        @{ Pattern = 'dangerouslySetInnerHTML.*require security review and tests'; Message = 'Web Frontend standard controls framework HTML bypass APIs.' },
        @{ Pattern = 'Trusted Types SHOULD be used for applications with material DOM injection risk'; Message = 'Web Frontend standard includes Trusted Types guidance.' },
        @{ Pattern = 'CSP MUST be governed as a security control'; Message = 'Web Frontend standard governs CSP.' },
        @{ Pattern = 'CSP MUST NOT be disabled for convenience'; Message = 'Web Frontend standard prohibits convenience CSP disablement.' },
        @{ Pattern = 'Every CSP MUST define, where applicable, delivery mechanism, `default-src`, `script-src`, `script-src-elem`, `script-src-attr`'; Message = 'Web Frontend standard requires directive-level CSP definition.' },
        @{ Pattern = '`default-src` MUST be explicit for protected applications'; Message = 'Web Frontend standard requires explicit default-src.' },
        @{ Pattern = '`object-src ''none''` SHOULD be used unless a reviewed requirement exists'; Message = 'Web Frontend standard expects object-src none.' },
        @{ Pattern = '`base-uri` MUST restrict base URL manipulation'; Message = 'Web Frontend standard requires base-uri restriction.' },
        @{ Pattern = '`form-action` MUST restrict submission destinations'; Message = 'Web Frontend standard requires form-action restriction.' },
        @{ Pattern = '`frame-ancestors` MUST define clickjacking protection'; Message = 'Web Frontend standard requires frame-ancestors clickjacking protection.' },
        @{ Pattern = '`connect-src` MUST explicitly cover approved API, WebSocket, telemetry, and worker destinations'; Message = 'Web Frontend standard requires connect-src destination coverage.' },
        @{ Pattern = 'Nonces MUST be unpredictable and request-scoped'; Message = 'Web Frontend standard requires request-scoped CSP nonces.' },
        @{ Pattern = 'Static or reusable nonces are prohibited'; Message = 'Web Frontend standard prohibits static CSP nonces.' },
        @{ Pattern = 'Report-only mode MUST have an owner, review period, remediation process, and enforcement target date'; Message = 'Web Frontend standard requires CSP report-only lifecycle.' },
        @{ Pattern = 'Cookie-authenticated state-changing requests MUST have CSRF protection enforced by the server'; Message = 'Web Frontend standard requires CSRF for cookie-authenticated mutation.' },
        @{ Pattern = 'GET, HEAD, OPTIONS, and other safe methods MUST NOT perform state-changing business actions'; Message = 'Web Frontend standard prohibits state-changing safe methods.' },
        @{ Pattern = 'Login endpoints MUST address login CSRF and account-confusion risks'; Message = 'Web Frontend standard requires login CSRF controls.' },
        @{ Pattern = 'Logout endpoints MUST address logout CSRF according to the threat model'; Message = 'Web Frontend standard requires logout CSRF controls.' },
        @{ Pattern = 'Failed CSRF validation MUST fail closed'; Message = 'Web Frontend standard requires CSRF fail-closed behavior.' },
        @{ Pattern = 'Failed CSRF validation MUST NOT automatically retry the mutation'; Message = 'Web Frontend standard prohibits automatic retry after CSRF failure.' },
        @{ Pattern = 'Retry loops after antiforgery-related 400, 401, or 403 responses are prohibited'; Message = 'Web Frontend standard prohibits antiforgery retry loops.' },
        @{ Pattern = 'CORS MUST NOT be treated as authorization'; Message = 'Web Frontend standard rejects CORS as authorization.' },
        @{ Pattern = 'Dynamic origin reflection MUST use a strict allowlist'; Message = 'Web Frontend standard requires strict dynamic CORS allowlists.' },
        @{ Pattern = 'Blind Origin reflection is prohibited'; Message = 'Web Frontend standard prohibits blind Origin reflection.' },
        @{ Pattern = 'Suffix matching without a hostname boundary is prohibited'; Message = 'Web Frontend standard requires boundary-safe origin matching.' },
        @{ Pattern = 'Production allowlists MUST NOT silently include localhost, loopback, development domains, wildcard ports, preview domains, or test origins'; Message = 'Web Frontend standard separates production and development origins.' },
        @{ Pattern = 'WebSocket and SignalR endpoints MUST validate Origin'; Message = 'Web Frontend standard requires WebSocket/SignalR Origin validation.' },
        @{ Pattern = 'Unsafe public CORS proxies or ad hoc relay services are prohibited'; Message = 'Web Frontend standard prohibits unsafe CORS proxy workarounds.' },
        @{ Pattern = 'Credential mode MUST match the approved server contract'; Message = 'Web Frontend standard requires credential mode contract alignment.' },
        @{ Pattern = 'URL construction MUST use safe parsers and protocol allowlists'; Message = 'Web Frontend standard requires URL protocol allowlists.' },
        @{ Pattern = 'Open redirects are prohibited unless targets are allowlisted and validated'; Message = 'Web Frontend standard protects redirects.' },
        @{ Pattern = 'target="_blank"` MUST use safe opener protection'; Message = 'Web Frontend standard requires external-link opener protection.' },
        @{ Pattern = 'Forms MUST be accessible, labeled, keyboard operable, error-associated'; Message = 'Web Frontend standard requires accessible forms.' },
        @{ Pattern = 'Empty scope, empty target, empty filter, or missing file input MUST NOT mean all targets'; Message = 'Web Frontend standard prevents empty input broad scope.' },
        @{ Pattern = 'Browser file validation is insufficient by itself'; Message = 'Web Frontend standard requires server-side upload validation.' },
        @{ Pattern = 'Protected downloads and report links MUST require server-side access-time authorization'; Message = 'Web Frontend standard requires protected download authorization.' },
        @{ Pattern = 'User filenames MUST NOT become server filesystem paths'; Message = 'Web Frontend standard separates uploaded filenames from server paths.' },
        @{ Pattern = 'Uploaded HTML or SVG MUST NOT render inline in a privileged application origin'; Message = 'Web Frontend standard governs active HTML/SVG uploads.' },
        @{ Pattern = 'CSV exports MUST address spreadsheet formula injection'; Message = 'Web Frontend standard requires CSV formula-injection controls.' },
        @{ Pattern = 'Downloads MUST define server-authoritative Content-Type, Content-Disposition, safe filename, `X-Content-Type-Options: nosniff`'; Message = 'Web Frontend standard requires download MIME, disposition, and nosniff controls.' },
        @{ Pattern = 'Safety MUST NOT be inferred from extension alone'; Message = 'Web Frontend standard rejects extension-only content safety.' },
        @{ Pattern = 'Hash mismatch MUST fail closed where hashes are provided'; Message = 'Web Frontend standard requires hash mismatch fail-closed behavior.' },
        @{ Pattern = 'Expired, revoked, wrong-tenant, wrong-attempt, wrong-version, or mismatched artifacts MUST fail safely'; Message = 'Web Frontend standard requires artifact identity and tenant failure behavior.' },
        @{ Pattern = 'API clients MUST define API origin, contract source, generated-client ownership, schema version, timeout, cancellation, retry'; Message = 'Web Frontend standard requires API timeout, cancellation, and retry controls.' },
        @{ Pattern = 'API contracts MUST define HTTP status and business outcome'; Message = 'Web Frontend standard requires HTTP and business outcome contracts.' },
        @{ Pattern = 'HTTP 2xx MUST NOT automatically mean full business success'; Message = 'Web Frontend standard separates HTTP success from business success.' },
        @{ Pattern = 'Partial success MUST remain explicit'; Message = 'Web Frontend standard requires explicit partial success.' },
        @{ Pattern = 'Unknown enums MUST fail safely and MUST NOT map to privileged defaults'; Message = 'Web Frontend standard requires safe unknown-enum handling.' },
        @{ Pattern = 'Missing required fields and schema-version mismatches MUST fail safely'; Message = 'Web Frontend standard requires safe schema mismatch behavior.' },
        @{ Pattern = 'Nullability mismatches MUST NOT be silently coerced when meaning changes'; Message = 'Web Frontend standard requires nullability semantics.' },
        @{ Pattern = 'Date/time formats MUST be explicit and unambiguous'; Message = 'Web Frontend standard requires explicit date/time formats.' },
        @{ Pattern = 'Pagination MUST define maximum size, stable ordering, continuation behavior'; Message = 'Web Frontend standard requires pagination semantics.' },
        @{ Pattern = 'Continuation tokens are opaque'; Message = 'Web Frontend standard requires opaque continuation tokens.' },
        @{ Pattern = 'Idempotency keys MUST be unique, scoped, retained, and interpreted according to the server contract'; Message = 'Web Frontend standard requires idempotency-key semantics.' },
        @{ Pattern = 'Blind retry of non-idempotent requests is prohibited'; Message = 'Web Frontend standard prohibits blind non-idempotent retries.' },
        @{ Pattern = 'Tenant-safe cache keys are mandatory'; Message = 'Web Frontend standard requires tenant-safe cache keys.' },
        @{ Pattern = 'Logout MUST clear protected caches'; Message = 'Web Frontend standard requires logout cache cleanup.' },
        @{ Pattern = 'Service workers MUST NOT cache protected API data by default'; Message = 'Web Frontend standard protects service-worker caches.' },
        @{ Pattern = 'Third-party scripts need privacy review before use'; Message = 'Web Frontend standard requires third-party script privacy review.' },
        @{ Pattern = 'External assets for protected production paths MUST use pinned versions and Subresource Integrity where supported'; Message = 'Web Frontend standard governs SRI and external assets.' },
        @{ Pattern = 'Frontend work MUST target WCAG 2\.2 AA'; Message = 'Web Frontend standard requires WCAG 2.2 AA target.' },
        @{ Pattern = 'keyboard navigation, visible focus, logical focus order'; Message = 'Web Frontend standard requires keyboard and focus controls.' },
        @{ Pattern = 'performance budgets for bundle size, route chunks, image size, font loading, hydration'; Message = 'Web Frontend standard requires performance budgets.' },
        @{ Pattern = 'User workflows MUST define loading, empty, error, partial success, retry, cancellation'; Message = 'Web Frontend standard requires reliability states.' },
        @{ Pattern = 'Job polling MUST define initial, normal, and maximum intervals, backoff and jitter'; Message = 'Web Frontend standard requires job polling bounds and jitter.' },
        @{ Pattern = 'Poll intervals MUST be bounded'; Message = 'Web Frontend standard requires bounded polling.' },
        @{ Pattern = 'Tight or zero-delay loops are prohibited'; Message = 'Web Frontend standard prohibits tight polling loops.' },
        @{ Pattern = 'Polling MUST stop on terminal states'; Message = 'Web Frontend standard requires terminal-state polling stop.' },
        @{ Pattern = 'Polling MUST cancel on navigation, logout, account switch, component disposal, or lost authorization'; Message = 'Web Frontend standard requires polling cancellation on lifecycle changes.' },
        @{ Pattern = 'Visibility changes MUST NOT create duplicate loops'; Message = 'Web Frontend standard prevents duplicate visibility polling loops.' },
        @{ Pattern = 'A cancellation request MUST NOT be displayed as completed until the server confirms terminal cancellation'; Message = 'Web Frontend standard requires server-confirmed cancellation.' },
        @{ Pattern = 'A job MUST NOT be shown completed until the server reports terminal completion'; Message = 'Web Frontend standard requires server-confirmed completion.' },
        @{ Pattern = 'Stale responses from prior attempts MUST NOT overwrite current state'; Message = 'Web Frontend standard rejects stale polling responses.' },
        @{ Pattern = 'Out-of-order responses MUST NOT regress terminal state'; Message = 'Web Frontend standard rejects out-of-order terminal regression.' },
        @{ Pattern = 'Client telemetry MUST define events, owner, purpose, sampling, consent, redaction'; Message = 'Web Frontend standard governs client telemetry redaction.' },
        @{ Pattern = 'Service-worker work MUST define script identity, scope, registration path, allowed scope'; Message = 'Web Frontend standard requires service-worker identity and scope controls.' },
        @{ Pattern = 'Scope MUST be no broader than required'; Message = 'Web Frontend standard requires minimal service-worker scope.' },
        @{ Pattern = 'Workers MUST NOT bypass auth, authorization, CSP, Trusted Types, or server controls'; Message = 'Web Frontend standard prohibits service-worker security bypasses.' },
        @{ Pattern = 'Cached executable assets MUST match the approved release identity'; Message = 'Web Frontend standard requires release-bound cached executable assets.' },
        @{ Pattern = 'Opaque cross-origin responses require review before caching'; Message = 'Web Frontend standard requires opaque response cache review.' },
        @{ Pattern = 'Cache poisoning through URLs, query strings, redirects, headers, or compromised upstream content MUST be considered'; Message = 'Web Frontend standard requires cache-poisoning analysis.' },
        @{ Pattern = 'Authentication pages, logout responses, antiforgery responses, token endpoints, and protected API responses MUST NOT be cached without an approved design'; Message = 'Web Frontend standard prohibits unapproved protected endpoint caching.' },
        @{ Pattern = 'Faulty active workers require documented recovery'; Message = 'Web Frontend standard requires faulty service-worker recovery.' },
        @{ Pattern = 'Update failures MUST be observable'; Message = 'Web Frontend standard requires service-worker update observability.' },
        @{ Pattern = 'Telemetry failure MUST NOT break core UI'; Message = 'Web Frontend standard isolates telemetry failure from core UI.' },
        @{ Pattern = 'Console logs MUST NOT contain secrets, tokens, passwords, authorization headers, private keys'; Message = 'Web Frontend standard prohibits sensitive console logs.' },
        @{ Pattern = 'Debug logging MUST be disabled in protected production builds unless approved'; Message = 'Web Frontend standard disables protected production debug logging.' },
        @{ Pattern = 'Correlation IDs MUST be opaque, safe, and non-secret'; Message = 'Web Frontend standard requires safe correlation IDs.' },
        @{ Pattern = 'Events MUST identify frontend release and environment'; Message = 'Web Frontend standard requires telemetry release and environment identity.' },
        @{ Pattern = 'Every production source map MUST associate with the exact source revision, release identifier, bundle filename, and content hash'; Message = 'Web Frontend standard requires exact source-map release association.' },
        @{ Pattern = 'Maps and bundles MUST be secret-scanned before publication or upload'; Message = 'Web Frontend standard requires source-map and bundle secret scanning.' },
        @{ Pattern = 'Upload success MUST be verified independently from deployment success'; Message = 'Web Frontend standard requires independent source-map upload verification.' },
        @{ Pattern = 'Provider upload MUST NOT make maps publicly reachable'; Message = 'Web Frontend standard requires protected source-map provider upload.' },
        @{ Pattern = 'Mismatched maps MUST fail deployment verification or be reported as a defect'; Message = 'Web Frontend standard requires mismatched map failure handling.' },
        @{ Pattern = 'Production source maps MUST NOT be public without review and approval'; Message = 'Web Frontend standard protects production source maps.' },
        @{ Pattern = 'Browser automation MUST define approved tool such as Playwright, Selenium, Cypress, WebdriverIO'; Message = 'Web Frontend standard requires browser/E2E automation controls.' },
        @{ Pattern = 'Validation Commands'; Message = 'Web Frontend standard includes validation commands section.' },
        @{ Pattern = 'npm ci'; Message = 'Web Frontend standard includes npm reproducible install example.' },
        @{ Pattern = 'pnpm install --frozen-lockfile'; Message = 'Web Frontend standard includes pnpm frozen install example.' },
        @{ Pattern = 'yarn install --immutable'; Message = 'Web Frontend standard includes Yarn immutable install example.' },
        @{ Pattern = 'Build success does not prove browser behavior'; Message = 'Web Frontend standard rejects build success as browser proof.' },
        @{ Pattern = 'Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`'; Message = 'Web Frontend standard declares honest completion statuses.' },
        @{ Pattern = 'Unexecuted browser, accessibility, performance, security-policy, deployment, or production validation MUST NOT be labeled `Passed`'; Message = 'Web Frontend standard prohibits false frontend evidence.' }
    )
    foreach ($item in $webFrontendRequiredPatterns) {
        Test-Contains $webFrontendAgents $item.Pattern $item.Message 'agents/AGENTS_WebFrontend.md'
    }

    $webFrontendProhibitedWeakeningPatterns = @(
        @{ Pattern = 'Browser code may contain server secrets'; Message = 'Web Frontend standard does not allow browser server secrets.' },
        @{ Pattern = 'Client-side route guards are sufficient authorization'; Message = 'Web Frontend standard does not allow route guards as authorization.' },
        @{ Pattern = 'Hidden buttons enforce authorization'; Message = 'Web Frontend standard does not allow hidden-button authorization.' },
        @{ Pattern = 'Privileged tokens should be stored in localStorage'; Message = 'Web Frontend standard does not prefer privileged tokens in localStorage.' },
        @{ Pattern = 'Untrusted HTML may be inserted directly'; Message = 'Web Frontend standard does not allow direct untrusted HTML insertion.' },
        @{ Pattern = 'dangerouslySetInnerHTML requires no review'; Message = 'Web Frontend standard requires review for dangerous HTML bypasses.' },
        @{ Pattern = 'javascript URLs are acceptable'; Message = 'Web Frontend standard rejects unsafe javascript URLs.' },
        @{ Pattern = 'CSP may be disabled for convenience'; Message = 'Web Frontend standard does not allow convenience CSP disablement.' },
        @{ Pattern = 'Cookie-authenticated POST requests need no CSRF protection'; Message = 'Web Frontend standard requires CSRF review.' },
        @{ Pattern = 'CORS proves authorization'; Message = 'Web Frontend standard does not treat CORS as authorization.' },
        @{ Pattern = 'Open redirects are acceptable'; Message = 'Web Frontend standard does not allow open redirects.' },
        @{ Pattern = 'target blank needs no opener protection'; Message = 'Web Frontend standard requires opener protection.' },
        @{ Pattern = 'Empty input means all targets'; Message = 'Web Frontend standard does not allow empty input to mean all targets.' },
        @{ Pattern = 'Browser file validation is sufficient'; Message = 'Web Frontend standard requires server-side upload validation.' },
        @{ Pattern = 'Public report URLs are acceptable for protected data'; Message = 'Web Frontend standard protects report URLs.' },
        @{ Pattern = 'Cache keys need no tenant scope'; Message = 'Web Frontend standard requires tenant-safe cache keys.' },
        @{ Pattern = 'Logout does not need to clear caches'; Message = 'Web Frontend standard requires logout cache cleanup.' },
        @{ Pattern = 'Service workers may cache protected API data by default'; Message = 'Web Frontend standard does not allow protected API caching by default.' },
        @{ Pattern = 'Third-party scripts need no privacy review'; Message = 'Web Frontend standard requires third-party privacy review.' },
        @{ Pattern = 'Accessibility is optional'; Message = 'Web Frontend standard does not treat accessibility as optional.' },
        @{ Pattern = 'Build success proves browser behavior'; Message = 'Web Frontend standard does not equate build success with browser behavior.' },
        @{ Pattern = 'Production source maps should always be public'; Message = 'Web Frontend standard protects production source maps.' },
        @{ Pattern = 'Production may be used when test environments are unavailable'; Message = 'Web Frontend standard does not allow production as default test target.' },
        @{ Pattern = 'npm audit fix force may be run automatically'; Message = 'Web Frontend standard does not allow automatic force audit fixes.' },
        @{ Pattern = 'Missing frontend validation may be marked Passed'; Message = 'Web Frontend standard does not allow missing frontend validation to be marked Passed.' },
        @{ Pattern = 'Browser OAuth clients may use implicit flow'; Message = 'Web Frontend standard does not allow new implicit-flow browser clients.' },
        @{ Pattern = 'PKCE is optional for public browser clients'; Message = 'Web Frontend standard requires PKCE for public browser clients.' },
        @{ Pattern = 'OAuth state or OIDC nonce needs no validation'; Message = 'Web Frontend standard requires state and nonce validation.' },
        @{ Pattern = 'Wildcard redirect URIs are acceptable'; Message = 'Web Frontend standard prohibits wildcard redirect URIs for protected production clients.' },
        @{ Pattern = 'Tokens may appear in URLs'; Message = 'Web Frontend standard prohibits tokens in URLs.' },
        @{ Pattern = 'Refresh-token reuse may be ignored'; Message = 'Web Frontend standard requires refresh-token reuse handling.' },
        @{ Pattern = 'Static CSP nonces are acceptable'; Message = 'Web Frontend standard prohibits static CSP nonces.' },
        @{ Pattern = 'CSP report-only may remain permanent'; Message = 'Web Frontend standard requires report-only enforcement lifecycle.' },
        @{ Pattern = 'GET requests may change state'; Message = 'Web Frontend standard prohibits state-changing GET requests.' },
        @{ Pattern = 'CSRF failures may be retried automatically'; Message = 'Web Frontend standard prohibits automatic CSRF retries.' },
        @{ Pattern = 'Login/logout CSRF does not matter'; Message = 'Web Frontend standard requires login/logout CSRF review.' },
        @{ Pattern = 'Dynamic CORS origins may be reflected blindly'; Message = 'Web Frontend standard prohibits blind dynamic CORS reflection.' },
        @{ Pattern = 'Development origins may remain in production'; Message = 'Web Frontend standard separates development and production origins.' },
        @{ Pattern = 'WebSocket origins need no validation'; Message = 'Web Frontend standard requires WebSocket Origin validation.' },
        @{ Pattern = 'Public CORS proxies are acceptable'; Message = 'Web Frontend standard prohibits public CORS proxies.' },
        @{ Pattern = 'User filenames may be server paths'; Message = 'Web Frontend standard separates user filenames from server paths.' },
        @{ Pattern = 'HTML/SVG downloads are always passive'; Message = 'Web Frontend standard treats HTML/SVG downloads as active content.' },
        @{ Pattern = 'Spreadsheet formula injection does not matter'; Message = 'Web Frontend standard requires spreadsheet formula injection handling.' },
        @{ Pattern = 'Content type may be inferred only from extension'; Message = 'Web Frontend standard rejects extension-only content type.' },
        @{ Pattern = 'HTTP 200 always means business success'; Message = 'Web Frontend standard separates HTTP and business success.' },
        @{ Pattern = 'Unknown enums may map to administrator'; Message = 'Web Frontend standard rejects privileged unknown-enum defaults.' },
        @{ Pattern = 'Schema mismatches may be ignored'; Message = 'Web Frontend standard requires safe schema mismatch handling.' },
        @{ Pattern = 'Non-idempotent requests may be retried blindly'; Message = 'Web Frontend standard prohibits blind non-idempotent retries.' },
        @{ Pattern = 'Polling may run without delay'; Message = 'Web Frontend standard prohibits zero-delay polling.' },
        @{ Pattern = 'Cancellation/completion may display before server confirmation'; Message = 'Web Frontend standard requires server-confirmed cancellation/completion.' },
        @{ Pattern = 'Stale poll responses may overwrite current state'; Message = 'Web Frontend standard rejects stale poll overwrite.' },
        @{ Pattern = 'Service workers may use broad scope by default or bypass CSP'; Message = 'Web Frontend standard limits service-worker scope and security controls.' },
        @{ Pattern = 'Opaque responses may always be cached'; Message = 'Web Frontend standard requires opaque response cache review.' },
        @{ Pattern = 'Cache poisoning needs no review'; Message = 'Web Frontend standard requires cache poisoning review.' },
        @{ Pattern = 'Telemetry failures may break the UI'; Message = 'Web Frontend standard isolates telemetry failures.' },
        @{ Pattern = 'Production console logs may contain tokens'; Message = 'Web Frontend standard prohibits token logging.' },
        @{ Pattern = 'Production debug logging may remain enabled'; Message = 'Web Frontend standard disables protected production debug logging.' },
        @{ Pattern = 'Source maps need not match the deployed release or be secret-scanned'; Message = 'Web Frontend standard requires source-map release match and secret scanning.' },
        @{ Pattern = 'Missing Web Frontend 1.1.1 validation may be marked Passed'; Message = 'Web Frontend standard does not allow missing Web Frontend 1.1.1 validation to be marked Passed.' }
    )
    foreach ($item in $webFrontendProhibitedWeakeningPatterns) {
        if ($webFrontendAgents -match $item.Pattern) {
            Add-Result Failed $item.Message 'agents/AGENTS_WebFrontend.md'
        }
        else {
            Add-Result Passed $item.Message 'agents/AGENTS_WebFrontend.md'
        }
    }
}

if ($dotNetAgents) {
    Test-MinimumSemanticVersion -Text $dotNetAgents -MinimumVersion '1.1.1' -Message '.NET standard declares a valid semantic version at least 1.1.1.' -RelativePath 'agents/AGENTS_DotNet.md'

    $dotNetRequiredPatterns = @(
        @{ Pattern = 'Target framework monikers'; Message = '.NET standard requires target framework monikers.' },
        @{ Pattern = 'Supported runtime versions'; Message = '.NET standard requires supported runtime versions.' },
        @{ Pattern = 'rollForward'; Message = '.NET standard requires documented SDK/runtime rollForward behavior.' },
        @{ Pattern = 'global\.json'; Message = '.NET standard covers global.json SDK selection.' },
        @{ Pattern = 'No silent framework retargeting|MUST NOT silently retarget frameworks'; Message = '.NET standard prohibits silent framework retargeting.' },
        @{ Pattern = 'end-of-support frameworks'; Message = '.NET standard prohibits or escalates unsupported frameworks.' },
        @{ Pattern = 'ValidateOnStart'; Message = '.NET standard requires startup options validation.' },
        @{ Pattern = 'IValidateOptions<T>'; Message = '.NET standard covers IValidateOptions based validation.' },
        @{ Pattern = 'dotnet user-secrets'; Message = '.NET standard limits dotnet user-secrets to local development.' },
        @{ Pattern = 'IHttpClientFactory'; Message = '.NET standard requires IHttpClientFactory or approved equivalent.' },
        @{ Pattern = 'ProblemDetails'; Message = '.NET standard requires stable API error contracts.' },
        @{ Pattern = '(?is)Protected resources\s+MUST\s+enforce server-side authorization.*Protected resources\s+MUST\s+be deny-by-default'; Message = '.NET standard makes server-side deny-by-default authorization mandatory.' },
        @{ Pattern = 'Anonymous or unauthenticated access MUST be explicitly declared'; Message = '.NET standard requires anonymous access to be declared.' },
        @{ Pattern = 'Public endpoints MUST be intentionally marked and reviewed'; Message = '.NET standard requires public endpoints to be marked and reviewed.' },
        @{ Pattern = 'New endpoints inherit protection unless explicitly documented as public'; Message = '.NET standard requires new endpoints to inherit protection.' },
        @{ Pattern = 'Authorization MUST be evaluated before access to protected data or side effects'; Message = '.NET standard requires authorization before protected data or side effects.' },
        @{ Pattern = 'Authorization policies MUST NOT be weakened for test convenience'; Message = '.NET standard prohibits weakening authorization for tests.' },
        @{ Pattern = 'New or materially changed configuration contracts MUST use strongly typed options.*approved equivalent'; Message = '.NET standard requires strongly typed options or approved equivalent.' },
        @{ Pattern = 'Startup validation MUST be used for critical configuration'; Message = '.NET standard requires startup validation for critical configuration.' },
        @{ Pattern = 'Raw `IConfiguration` lookups scattered through business code are prohibited'; Message = '.NET standard prohibits scattered raw IConfiguration lookups where options fit.' },
        @{ Pattern = 'Managed outbound HTTP clients MUST use `IHttpClientFactory`.*approved equivalent ownership model'; Message = '.NET standard requires governed outbound HTTP client ownership.' },
        @{ Pattern = 'Direct `HttpClient` construction is allowed only when lifetime, disposal, DNS refresh, handler ownership, and testability are explicitly controlled and documented'; Message = '.NET standard restricts direct HttpClient construction.' },
        @{ Pattern = 'invalid signature, issuer, audience, expiration'; Message = '.NET standard requires JWT negative tests.' },
        @{ Pattern = 'wildcard-with-credentials'; Message = '.NET standard prohibits wildcard CORS with credentials.' },
        @{ Pattern = 'Path normalization and approved-root boundary checks'; Message = '.NET standard requires upload/download path-boundary checks.' },
        @{ Pattern = 'Serialization And Deserialization Safety'; Message = '.NET standard includes serialization and deserialization safety.' },
        @{ Pattern = 'BinaryFormatter'; Message = '.NET standard covers BinaryFormatter prohibition for untrusted data.' },
        @{ Pattern = 'TypeNameHandling|arbitrary runtime type resolution'; Message = '.NET standard controls unsafe type resolution.' },
        @{ Pattern = 'XML parsers MUST disable external entity resolution'; Message = '.NET standard requires XML external entity protection.' },
        @{ Pattern = 'Data Protection'; Message = '.NET standard covers ASP.NET Core Data Protection.' },
        @{ Pattern = 'Scoped DbContext|DbContext.*scoped'; Message = '.NET standard requires scoped DbContext lifetime.' },
        @{ Pattern = 'Automatic production migration-on-startup is prohibited'; Message = '.NET standard prohibits unapproved production migration-on-startup.' },
        @{ Pattern = 'AGENTS_WorkerService\.md'; Message = '.NET standard hands off worker behavior to Worker Service standard.' },
        @{ Pattern = 'OpenTelemetry'; Message = '.NET standard covers telemetry expectations.' },
        @{ Pattern = 'Native Process And Command Execution'; Message = '.NET standard includes native process and command execution safety.' },
        @{ Pattern = 'ProcessStartInfo\.ArgumentList|safe argument model'; Message = '.NET standard requires safe process argument separation.' },
        @{ Pattern = 'secrets MUST NOT be passed in visible command-line arguments'; Message = '.NET standard prohibits secrets in command-line arguments.' },
        @{ Pattern = 'validate exit codes against defined accepted exit codes'; Message = '.NET standard requires process exit-code validation.' },
        @{ Pattern = 'timeouts and cancellation'; Message = '.NET standard requires timeout and cancellation controls.' },
        @{ Pattern = 'liveness and readiness'; Message = '.NET standard requires distinct health-check semantics.' },
        @{ Pattern = 'AGENTS_Integration\.md'; Message = '.NET standard hands off integrations to Integration standard.' },
        @{ Pattern = 'Outbound Request And SSRF Safety'; Message = '.NET standard includes outbound request and SSRF safety.' },
        @{ Pattern = 'cloud metadata'; Message = '.NET standard requires cloud metadata destination protection.' },
        @{ Pattern = 'validate every redirect target'; Message = '.NET standard requires redirect target revalidation.' },
        @{ Pattern = 'loopback, private, link-local'; Message = '.NET standard controls loopback, private, and link-local destinations.' },
        @{ Pattern = 'AGENTS_WebFrontend\.md'; Message = '.NET standard hands off static frontend work to Web Frontend standard.' },
        @{ Pattern = 'IIS-hosted'; Message = '.NET standard covers IIS hosting.' },
        @{ Pattern = 'No `latest` production tags|no `latest` production tags'; Message = '.NET standard prohibits latest container production tags.' },
        @{ Pattern = 'Playwright'; Message = '.NET standard requires browser E2E guidance.' },
        @{ Pattern = 'NuGet package source mapping'; Message = '.NET standard covers NuGet source mapping.' },
        @{ Pattern = 'Validation Commands'; Message = '.NET standard includes validation commands section.' },
        @{ Pattern = 'dotnet --info'; Message = '.NET standard requires dotnet --info evidence or reason.' },
        @{ Pattern = 'dotnet restore'; Message = '.NET standard includes restore validation command.' },
        @{ Pattern = 'dotnet build --no-restore --configuration Release'; Message = '.NET standard includes build validation command.' },
        @{ Pattern = 'dotnet test --no-build --configuration Release'; Message = '.NET standard includes test validation command.' },
        @{ Pattern = 'dotnet list package --vulnerable'; Message = '.NET standard includes vulnerability audit command.' },
        @{ Pattern = 'Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`'; Message = '.NET standard declares evidence statuses.' },
        @{ Pattern = 'AGENTS_Database\.md'; Message = '.NET standard hands off data work to Database standard.' },
        @{ Pattern = 'New \.NET projects MUST enable nullable reference types unless a documented compatibility constraint exists'; Message = '.NET standard requires nullable reference types for new projects.' },
        @{ Pattern = 'Existing projects that disable nullable reference types MUST record the gap'; Message = '.NET standard requires nullable gaps to be recorded.' },
        @{ Pattern = 'CI MUST treat the repository''s governed warning set as errors'; Message = '.NET standard requires governed warnings as errors in CI.' },
        @{ Pattern = 'Governed \.NET projects MUST use Roslyn analyzers and `\.editorconfig` or a repository-approved equivalent'; Message = '.NET standard requires analyzers and editorconfig or approved equivalent.' },
        @{ Pattern = 'Persisted and cross-system timestamps MUST use UTC or another explicitly documented interoperable contract'; Message = '.NET standard requires governed UTC/time handling.' }
    )
    foreach ($item in $dotNetRequiredPatterns) {
        Test-Contains $dotNetAgents $item.Pattern $item.Message 'agents/AGENTS_DotNet.md'
    }

    $dotNetProhibitedWeakeningPatterns = @(
        @{ Pattern = 'SHOULD be deny-by-default'; Message = '.NET standard does not weaken deny-by-default to SHOULD.' },
        @{ Pattern = 'validate issuer and audience only when convenient'; Message = '.NET standard does not weaken JWT issuer/audience validation.' },
        @{ Pattern = 'issuer/audience validation may be skipped for convenience'; Message = '.NET standard does not allow issuer/audience validation skips for convenience.' },
        @{ Pattern = 'production migration-on-startup is allowed by default'; Message = '.NET standard does not allow production migration-on-startup by default.' },
        @{ Pattern = 'IIS validation may be assumed'; Message = '.NET standard does not allow assumed IIS validation.' },
        @{ Pattern = 'direct shell command construction from untrusted input is acceptable'; Message = '.NET standard does not allow untrusted shell command construction.' },
        @{ Pattern = 'BinaryFormatter is allowed for untrusted input'; Message = '.NET standard does not allow BinaryFormatter for untrusted input.' },
        @{ Pattern = 'metadata endpoints are allowed without validation'; Message = '.NET standard does not allow metadata endpoints without validation.' }
    )
    foreach ($item in $dotNetProhibitedWeakeningPatterns) {
        if ($dotNetAgents -match $item.Pattern) {
            Add-Result Failed $item.Message 'agents/AGENTS_DotNet.md'
        }
        else {
            Add-Result Passed $item.Message 'agents/AGENTS_DotNet.md'
        }
    }
}

if ($databaseAgents) {
    Test-MinimumSemanticVersion -Text $databaseAgents -MinimumVersion '1.1.1' -Message 'Database standard declares a valid semantic version at least 1.1.1.' -RelativePath 'agents/AGENTS_Database.md'

    $databaseRequiredPatterns = @(
        @{ Pattern = 'SQL Server.*Azure SQL Database.*Azure SQL Managed Instance.*PostgreSQL.*MySQL.*MariaDB.*Oracle Database.*SQLite'; Message = 'Database standard declares supported engine coverage.' },
        @{ Pattern = 'Supported Database Engines And Versions'; Message = 'Database standard includes supported engine and version policy.' },
        @{ Pattern = 'Compatibility levels, dialects, required extensions'; Message = 'Database standard requires compatibility and dialect discovery.' },
        @{ Pattern = 'authoritative schema model'; Message = 'Database standard requires one authoritative schema source of truth.' },
        @{ Pattern = 'Migration-first'; Message = 'Database standard covers migration-first development.' },
        @{ Pattern = 'State-based database project'; Message = 'Database standard covers state-based database projects.' },
        @{ Pattern = 'already-applied immutable migrations'; Message = 'Database standard protects already-applied migrations.' },
        @{ Pattern = 'Expand-And-Contract And Rolling Deployment Compatibility'; Message = 'Database standard includes expand-and-contract rollout controls.' },
        @{ Pattern = 'Automatic production migration-on-startup is prohibited'; Message = 'Database standard prohibits unapproved production migration-on-startup.' },
        @{ Pattern = 'Destructive Operations'; Message = 'Database standard includes destructive operation controls.' },
        @{ Pattern = 'preview or `DryRun`'; Message = 'Database standard requires preview or DryRun for destructive/data changes.' },
        @{ Pattern = 'maximum affected-row threshold'; Message = 'Database standard requires maximum affected-row thresholds.' },
        @{ Pattern = 'Empty input MUST NOT mean all rows'; Message = 'Database standard prevents empty input from meaning all rows.' },
        @{ Pattern = 'parameterized queries, bound parameters'; Message = 'Database standard requires parameterized SQL.' },
        @{ Pattern = 'identifier allowlists'; Message = 'Database standard requires dynamic identifier allowlists.' },
        @{ Pattern = 'SELECT \*` MUST NOT be introduced into stable production contracts'; Message = 'Database standard restricts SELECT * in stable contracts.' },
        @{ Pattern = 'execution-plan review'; Message = 'Database standard requires query-plan review for high-impact queries.' },
        @{ Pattern = 'NOLOCK` MUST NOT be used as a generic performance fix'; Message = 'Database standard rejects NOLOCK as a generic fix.' },
        @{ Pattern = 'Every new index requires a query or use-case justification'; Message = 'Database standard requires index justification.' },
        @{ Pattern = 'transaction boundaries'; Message = 'Database standard requires transaction-boundary definition.' },
        @{ Pattern = 'isolation level, lock duration, lock escalation, blocking chains, deadlock risk'; Message = 'Database standard covers isolation, locking, blocking, and deadlocks.' },
        @{ Pattern = 'idempotency'; Message = 'Database standard covers idempotency.' },
        @{ Pattern = '(?is)`MERGE` and equivalent upsert constructs MUST receive engine- and version-specific correctness and concurrency review'; Message = 'Database standard requires engine/version-specific MERGE and upsert review.' },
        @{ Pattern = '(?is)duplicate source-row behavior.*concurrent writer behavior'; Message = 'Database standard requires duplicate source-row and concurrent-writer behavior for upserts.' },
        @{ Pattern = '(?is)Upsert tests MUST cover.*concurrent insert attempts.*concurrent update attempts.*duplicate source rows.*retry after partial failure'; Message = 'Database standard requires upsert concurrency, duplicate, and retry tests.' },
        @{ Pattern = 'Triggers.*MUST handle multi-row operations'; Message = 'Database standard requires multi-row-safe triggers.' },
        @{ Pattern = 'Transactions MUST use the smallest practical scope'; Message = 'Database standard requires smallest practical transaction scope.' },
        @{ Pattern = 'Remote API, SMTP, file-transfer, queue, or other external calls MUST NOT occur inside a database transaction unless explicitly justified and protected by an approved pattern'; Message = 'Database standard prohibits external calls inside transactions without an approved pattern.' },
        @{ Pattern = 'When commit outcome is uncertain, callers MUST NOT blindly retry non-idempotent operations'; Message = 'Database standard prohibits blind retry after uncertain commit.' },
        @{ Pattern = 'Transactional DDL support MUST be verified for the declared engine before rollback claims are made'; Message = 'Database standard requires transactional DDL support verification before rollback claims.' },
        @{ Pattern = '(?is)Stored procedures MUST define.*explicit parameter types.*explicit string or binary lengths'; Message = 'Database standard requires stored procedure parameter types and lengths.' },
        @{ Pattern = '(?is)Stored procedures MUST define.*stable result-set contracts'; Message = 'Database standard requires stable stored procedure result contracts.' },
        @{ Pattern = '(?is)Functions MUST document determinism assumptions.*Scalar function performance impact MUST be reviewed'; Message = 'Database standard requires function determinism and scalar-function performance review.' },
        @{ Pattern = 'Views MUST use explicit column lists and MUST avoid `SELECT \*`'; Message = 'Database standard requires explicit view columns and prohibits SELECT *.' },
        @{ Pattern = 'Accidental cross joins are prohibited'; Message = 'Database standard prohibits accidental cross joins.' },
        @{ Pattern = 'Cursor, loop, and row-by-row processing MUST be justified'; Message = 'Database standard requires cursor and row-by-row justification.' },
        @{ Pattern = 'Recursive queries MUST define termination condition, maximum depth'; Message = 'Database standard requires recursive-query termination and maximum depth controls.' },
        @{ Pattern = 'least privilege'; Message = 'Database standard requires least privilege.' },
        @{ Pattern = 'Application accounts MUST NOT use `sysadmin`, `dbo`-equivalent, `superuser`'; Message = 'Database standard prohibits privileged application accounts.' },
        @{ Pattern = 'Public, Internal, Confidential, Regulated, or Secret/Restricted'; Message = 'Database standard requires data classification.' },
        @{ Pattern = 'TLS.*Certificate validation MUST NOT be bypassed'; Message = 'Database standard requires TLS and certificate validation controls.' },
        @{ Pattern = 'Backup, Restore, And Recovery'; Message = 'Database standard includes backup, restore, and recovery.' },
        @{ Pattern = 'restore test status'; Message = 'Database standard requires restore-test status.' },
        @{ Pattern = 'Before destructive production work.*verify backup status through an authoritative mechanism'; Message = 'Database standard requires authoritative backup verification.' },
        @{ Pattern = 'Replication, High Availability, And Disaster Recovery'; Message = 'Database standard includes replication and HA review.' },
        @{ Pattern = 'Validation Commands'; Message = 'Database standard includes validation commands section.' },
        @{ Pattern = 'sqlcmd -S "<server>" -d "<database>" -E -b -i'; Message = 'Database standard includes SQL Server validation example.' },
        @{ Pattern = 'sqlpackage /Action:Script'; Message = 'Database standard includes DACPAC validation example.' },
        @{ Pattern = 'Secret-bearing connection strings MUST NOT be placed directly in process arguments'; Message = 'Database standard prohibits secret-bearing connection strings in process arguments.' },
        @{ Pattern = 'integrated authentication, managed identity, workload identity, certificate authentication'; Message = 'Database standard includes approved non-secret sqlpackage authentication guidance.' },
        @{ Pattern = '(?is)/TargetServerName:"<server>".*/TargetDatabaseName:"<database>".*/TargetTrustServerCertificate:False'; Message = 'Database standard includes safer sqlpackage placeholder example.' },
        @{ Pattern = 'dotnet ef migrations list'; Message = 'Database standard includes EF Core validation example.' },
        @{ Pattern = 'flyway validate'; Message = 'Database standard includes Flyway validation example.' },
        @{ Pattern = 'liquibase validate'; Message = 'Database standard includes Liquibase validation example.' },
        @{ Pattern = 'psql --set ON_ERROR_STOP=on'; Message = 'Database standard includes PostgreSQL validation example.' },
        @{ Pattern = 'CI MUST NOT use fake commands that only print success'; Message = 'Database standard prohibits fake validation commands.' },
        @{ Pattern = 'ephemeral or isolated databases'; Message = 'Database standard requires ephemeral or isolated database testing where feasible.' },
        @{ Pattern = 'Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`'; Message = 'Database standard declares completion statuses.' },
        @{ Pattern = 'AGENTS_DotNet\.md'; Message = 'Database standard hands off application data access to .NET standard.' },
        @{ Pattern = 'AGENTS_PowerShell\.md'; Message = 'Database standard hands off PowerShell automation to PowerShell standard.' },
        @{ Pattern = 'AGENTS_WorkerService\.md'; Message = 'Database standard hands off workers to Worker Service standard.' },
        @{ Pattern = 'AGENTS_Integration\.md'; Message = 'Database standard hands off integrations to Integration standard.' },
        @{ Pattern = 'AGENTS_Infrastructure\.md'; Message = 'Database standard hands off hosting and managed services to Infrastructure standard.' }
    )
    foreach ($item in $databaseRequiredPatterns) {
        Test-Contains $databaseAgents $item.Pattern $item.Message 'agents/AGENTS_Database.md'
    }

    $databaseProhibitedWeakeningPatterns = @(
        @{ Pattern = 'Production migration-on-startup is allowed by default'; Message = 'Database standard does not allow production migration-on-startup by default.' },
        @{ Pattern = 'DELETE without a predicate is acceptable'; Message = 'Database standard does not allow DELETE without a predicate.' },
        @{ Pattern = 'Empty input means all rows'; Message = 'Database standard does not allow empty input to mean all rows.' },
        @{ Pattern = 'SELECT \* is preferred'; Message = 'Database standard does not prefer SELECT *.' },
        @{ Pattern = 'NOLOCK should be used to solve blocking generally'; Message = 'Database standard does not use NOLOCK as a general blocking fix.' },
        @{ Pattern = 'Backup existence may be assumed'; Message = 'Database standard does not allow assumed backup evidence.' },
        @{ Pattern = 'Production data may be copied into tests'; Message = 'Database standard does not allow production data in tests.' },
        @{ Pattern = 'Application accounts may use sysadmin'; Message = 'Database standard does not allow application sysadmin accounts.' },
        @{ Pattern = 'Dynamic table names may come directly from users'; Message = 'Database standard does not allow direct user-provided dynamic table names.' },
        @{ Pattern = 'Constraints may be disabled for convenience'; Message = 'Database standard does not allow disabling constraints for convenience.' },
        @{ Pattern = 'Missing database validation may be marked Passed'; Message = 'Database standard does not allow missing database validation to be marked Passed.' },
        @{ Pattern = 'MERGE is always safe'; Message = 'Database standard does not claim MERGE is always safe.' },
        @{ Pattern = 'Upserts require no concurrency testing'; Message = 'Database standard does not waive upsert concurrency testing.' },
        @{ Pattern = 'Remote calls inside transactions are acceptable by default'; Message = 'Database standard does not allow remote calls inside transactions by default.' },
        @{ Pattern = 'A lost connection during commit means the transaction definitely failed'; Message = 'Database standard does not misstate uncertain commit outcome.' },
        @{ Pattern = 'Blind retry after uncertain commit is safe'; Message = 'Database standard does not allow blind retry after uncertain commit.' },
        @{ Pattern = 'Procedure parameters may omit lengths'; Message = 'Database standard does not allow procedure parameters to omit lengths.' },
        @{ Pattern = 'Functions need no performance review'; Message = 'Database standard does not waive function performance review.' },
        @{ Pattern = 'Views may use SELECT \* by default'; Message = 'Database standard does not allow view SELECT * by default.' },
        @{ Pattern = 'Cross joins require no review'; Message = 'Database standard does not allow cross joins without review.' },
        @{ Pattern = 'Cursors are preferred for bulk processing'; Message = 'Database standard does not prefer cursors for bulk processing.' },
        @{ Pattern = 'Recursive queries need no depth limit'; Message = 'Database standard requires recursive query depth limits.' },
        @{ Pattern = 'Plaintext connection strings may be passed to sqlpackage'; Message = 'Database standard does not allow plaintext sqlpackage connection strings.' },
        @{ Pattern = 'Command-line secrets are acceptable in CI'; Message = 'Database standard does not allow command-line secrets in CI.' },
        @{ Pattern = 'Transactional DDL support may be assumed'; Message = 'Database standard does not allow assumed transactional DDL support.' }
    )
    foreach ($item in $databaseProhibitedWeakeningPatterns) {
        if ($databaseAgents -match $item.Pattern) {
            Add-Result Failed $item.Message 'agents/AGENTS_Database.md'
        }
        else {
            Add-Result Passed $item.Message 'agents/AGENTS_Database.md'
        }
    }
}

if ($workerAgents) {
    Test-MinimumSemanticVersion -Text $workerAgents -MinimumVersion '1.1.1' -Message 'Worker Service standard declares a valid semantic version at least 1.1.1.' -RelativePath 'agents/AGENTS_WorkerService.md'

    $workerRequiredPatterns = @(
        @{ Pattern = '(?is)Polling worker.*Push or queue consumer.*Scheduled worker.*Event-driven worker.*File-watcher worker.*Batch worker.*Script-runner worker.*Orchestrator.*Hybrid'; Message = 'Worker Service standard declares worker execution models.' },
        @{ Pattern = 'Every durable worker MUST define a documented state machine'; Message = 'Worker Service standard requires documented state machines.' },
        @{ Pattern = '(?is)Every progress, heartbeat, completion, failure, retry scheduling, cancellation, timeout, dead-letter, skip, and partial-success transition MUST verify.*current worker or lease owner.*current state version or concurrency token'; Message = 'Worker Service standard requires owner and concurrency-token checks for progress and final state mutation.' },
        @{ Pattern = 'State transitions MUST use compare-and-swap, optimistic concurrency, an atomic predicate, queue-native ownership semantics, or an equivalent protected mechanism'; Message = 'Worker Service standard requires protected state-transition mechanisms.' },
        @{ Pattern = 'A worker that has lost ownership MUST NOT update progress, mark success, mark failure, schedule retry, complete or acknowledge the message, publish final artifacts, dead-letter the work, or mutate terminal state'; Message = 'Worker Service standard prohibits stale owner mutation and finalization.' },
        @{ Pattern = 'Zero rows affected by an ownership-protected update MUST be treated as ownership loss or stale state, not success'; Message = 'Worker Service standard rejects zero-row protected updates as success.' },
        @{ Pattern = 'For SQL-polled workers, claiming MUST be atomic'; Message = 'Worker Service standard requires atomic SQL worker claiming.' },
        @{ Pattern = 'lease owner.*lease expiration|claim or lease owner.*lease expiration'; Message = 'Worker Service standard requires lease owner and expiration.' },
        @{ Pattern = 'A worker MUST stop or fail safely if it loses ownership'; Message = 'Worker Service standard requires safe stop on lease loss.' },
        @{ Pattern = 'Queue completion or acknowledgement MUST verify that the current receiver still owns the lock, lease, receipt handle'; Message = 'Worker Service standard requires queue lock or receipt-handle verification before acknowledgement.' },
        @{ Pattern = 'Reclaimed work MUST generate a new ownership context or attempt identity'; Message = 'Worker Service standard requires new ownership context for reclaimed work.' },
        @{ Pattern = 'At-least-once delivery MUST assume duplicate messages'; Message = 'Worker Service standard requires duplicate assumptions for at-least-once delivery.' },
        @{ Pattern = 'Exactly-once delivery is prohibited as a claim unless proven end-to-end'; Message = 'Worker Service standard prohibits unproven exactly-once claims.' },
        @{ Pattern = 'durable idempotency key'; Message = 'Worker Service standard requires durable idempotency.' },
        @{ Pattern = 'Empty input MUST NOT mean all jobs'; Message = 'Worker Service standard prevents empty input or replay from meaning all work.' },
        @{ Pattern = 'Unbounded concurrency is prohibited'; Message = 'Worker Service standard requires bounded concurrency.' },
        @{ Pattern = '(?is)Empty polls MUST delay.*Failure loops MUST back off'; Message = 'Worker Service standard requires polling delay and backoff.' },
        @{ Pattern = 'Overlap MUST be explicitly allowed or prevented'; Message = 'Worker Service standard requires schedule overlap policy.' },
        @{ Pattern = '(?is)daylight saving time skipped-time behavior.*repeated-time behavior.*ambiguous local-time behavior'; Message = 'Worker Service standard requires DST behavior.' },
        @{ Pattern = 'retryable and nonretryable categories'; Message = 'Worker Service standard requires retry classification.' },
        @{ Pattern = '(?is)maximum attempt count.*exponential backoff and jitter'; Message = 'Worker Service standard requires bounded retries and jitter.' },
        @{ Pattern = 'Dead-letter storage MUST be durable'; Message = 'Worker Service standard requires durable dead-letter storage.' },
        @{ Pattern = '(?is)Replay and manual retry MUST define authorization.*maximum job count'; Message = 'Worker Service standard requires replay authorization and limits.' },
        @{ Pattern = 'Cancellation tokens or equivalent cancellation signals MUST propagate'; Message = 'Worker Service standard requires cancellation propagation.' },
        @{ Pattern = 'Graceful shutdown MUST define drain behavior'; Message = 'Worker Service standard requires graceful shutdown.' },
        @{ Pattern = 'Child processes MUST have timeouts'; Message = 'Worker Service standard requires process timeouts.' },
        @{ Pattern = 'When database state and external side effects must remain coordinated, workers MUST use outbox, inbox, durable queue handoff, idempotent reconciliation, saga or orchestration state, or another approved durable pattern'; Message = 'Worker Service standard requires mandatory durable handoff for coordinated cross-system effects.' },
        @{ Pattern = 'Queue acknowledgement MUST NOT occur before the approved durable completion point'; Message = 'Worker Service standard requires acknowledgement after durable completion.' },
        @{ Pattern = 'Script-runner workers MUST use an approved script or job catalog'; Message = 'Worker Service standard requires approved script catalogs.' },
        @{ Pattern = 'The approved catalog MUST define and verify an immutable executable identity before execution'; Message = 'Worker Service standard requires immutable script and executable identity.' },
        @{ Pattern = 'The worker MUST verify the executable, script, module, package, hash, signature, signer, or container digest immediately before execution'; Message = 'Worker Service standard requires immediate pre-execution identity verification.' },
        @{ Pattern = 'A valid signature from an unapproved signer is insufficient'; Message = 'Worker Service standard requires approved Authenticode signer validation.' },
        @{ Pattern = 'Arbitrary scripts, paths, commands, shell snippets, or user command text MUST NOT be executed'; Message = 'Worker Service standard prohibits arbitrary script, command, and path execution.' },
        @{ Pattern = 'Secrets MUST NOT be passed in visible command-line arguments'; Message = 'Worker Service standard prohibits command-line secrets.' },
        @{ Pattern = 'Accepted exit codes MUST be explicit'; Message = 'Worker Service standard requires process exit-code validation.' },
        @{ Pattern = 'The worker MUST intentionally capture the success/output stream, error stream, warning stream, verbose stream, debug stream, and information stream'; Message = 'Worker Service standard requires PowerShell stream capture.' },
        @{ Pattern = 'The worker MUST distinguish terminating and nonterminating errors'; Message = 'Worker Service standard requires PowerShell terminating and nonterminating error handling.' },
        @{ Pattern = 'Process exit code alone MUST NOT be treated as complete proof of PowerShell success'; Message = 'Worker Service standard says PowerShell exit code alone is insufficient.' },
        @{ Pattern = 'A stable structured result contract MUST be preferred for governed scripts'; Message = 'Worker Service standard requires stable structured PowerShell result contracts.' },
        @{ Pattern = 'Job input MUST become immutable, versioned, or content-addressed after durable submission'; Message = 'Worker Service standard requires immutable job input.' },
        @{ Pattern = 'immutable payload snapshot or immutable object reference, content hash'; Message = 'Worker Service standard requires input snapshot or version and hash.' },
        @{ Pattern = 'The worker MUST verify content hash before execution'; Message = 'Worker Service standard requires input hash verification before execution.' },
        @{ Pattern = 'Uploaded CSV or input files MUST NOT be replaceable after approval'; Message = 'Worker Service standard prohibits silent approved input replacement.' },
        @{ Pattern = 'Worker artifacts and reports MUST be associated with job ID, attempt number, correlation ID'; Message = 'Worker Service standard requires artifact metadata.' },
        @{ Pattern = 'content hash, classification, retention, and authorization boundary'; Message = 'Worker Service standard requires artifact content hash and governance metadata.' },
        @{ Pattern = 'Artifact publication MUST use an atomic publish model'; Message = 'Worker Service standard requires atomic artifact publication.' },
        @{ Pattern = 'Partial artifacts MUST NOT be presented as final'; Message = 'Worker Service standard prohibits exposing partial artifacts.' },
        @{ Pattern = 'A job MUST NOT be marked fully successful when a required artifact failed to publish'; Message = 'Worker Service standard requires artifact failure to affect job outcome.' },
        @{ Pattern = 'approved roots, safe file names, traversal protection'; Message = 'Worker Service standard requires artifact path controls.' },
        @{ Pattern = 'Workers MUST run with least privilege'; Message = 'Worker Service standard requires least privilege.' },
        @{ Pattern = 'Secrets MUST come from approved secret stores'; Message = 'Worker Service standard requires approved secret stores.' },
        @{ Pattern = 'Structured logs MUST include'; Message = 'Worker Service standard requires structured logging.' },
        @{ Pattern = 'Logs MUST NOT include secrets'; Message = 'Worker Service standard requires redaction.' },
        @{ Pattern = 'queue depth, oldest work age'; Message = 'Worker Service standard requires queue depth and oldest-age metrics.' },
        @{ Pattern = 'A worker MUST NOT claim jobs before startup validation completes'; Message = 'Worker Service standard requires readiness before claiming.' },
        @{ Pattern = 'backpressure'; Message = 'Worker Service standard requires backpressure controls.' },
        @{ Pattern = 'old/new worker compatibility'; Message = 'Worker Service standard requires rolling compatibility.' },
        @{ Pattern = 'Validation Commands'; Message = 'Worker Service standard includes validation commands section.' },
        @{ Pattern = 'Normal worker execution MUST NOT be launched merely as a smoke test'; Message = 'Worker Service standard prohibits unsafe normal worker container smoke tests.' },
        @{ Pattern = 'Production credentials MUST NOT be mounted'; Message = 'Worker Service standard prohibits production credentials for container validation.' },
        @{ Pattern = '--validate-configuration'; Message = 'Worker Service standard includes safe container validation or no-work mode guidance.' },
        @{ Pattern = 'Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`'; Message = 'Worker Service standard declares completion statuses.' },
        @{ Pattern = 'AGENTS_DotNet\.md'; Message = 'Worker Service standard hands off .NET worker work.' },
        @{ Pattern = 'AGENTS_Database\.md'; Message = 'Worker Service standard hands off database worker work.' },
        @{ Pattern = 'AGENTS_PowerShell\.md'; Message = 'Worker Service standard hands off PowerShell worker work.' },
        @{ Pattern = 'AGENTS_Integration\.md'; Message = 'Worker Service standard hands off integration worker work.' },
        @{ Pattern = 'AGENTS_Infrastructure\.md'; Message = 'Worker Service standard hands off infrastructure worker work.' }
    )
    foreach ($item in $workerRequiredPatterns) {
        Test-Contains $workerAgents $item.Pattern $item.Message 'agents/AGENTS_WorkerService.md'
    }

    $workerProhibitedWeakeningPatterns = @(
        @{ Pattern = 'Exactly-once delivery is automatic'; Message = 'Worker Service standard does not allow automatic exactly-once claims.' },
        @{ Pattern = 'Empty input means all jobs'; Message = 'Worker Service standard does not allow empty input to mean all jobs.' },
        @{ Pattern = 'Any script path may be executed'; Message = 'Worker Service standard does not allow arbitrary script paths.' },
        @{ Pattern = 'User command text may be passed to a shell'; Message = 'Worker Service standard does not allow user shell command text.' },
        @{ Pattern = 'Queue messages may be acknowledged before durable completion'; Message = 'Worker Service standard does not allow early queue acknowledgement.' },
        @{ Pattern = 'Leases may be overwritten by another worker'; Message = 'Worker Service standard does not allow active lease overwrite.' },
        @{ Pattern = 'Lost lease may be ignored'; Message = 'Worker Service standard does not allow lease loss to be ignored.' },
        @{ Pattern = 'Infinite retries are acceptable'; Message = 'Worker Service standard does not allow infinite retries.' },
        @{ Pattern = 'Poison jobs may be discarded'; Message = 'Worker Service standard does not allow discarded poison jobs.' },
        @{ Pattern = 'Dead-letter replay needs no approval'; Message = 'Worker Service standard requires replay approval.' },
        @{ Pattern = 'Cancellation may be ignored'; Message = 'Worker Service standard does not allow ignored cancellation.' },
        @{ Pattern = 'Process launch means success'; Message = 'Worker Service standard does not equate process launch with success.' },
        @{ Pattern = 'Secrets may be passed on command lines'; Message = 'Worker Service standard does not allow command-line secrets.' },
        @{ Pattern = 'Busy polling is acceptable'; Message = 'Worker Service standard does not allow busy polling.' },
        @{ Pattern = 'Unlimited concurrency is preferred'; Message = 'Worker Service standard does not prefer unlimited concurrency.' },
        @{ Pattern = 'Local time schedules need no DST handling'; Message = 'Worker Service standard requires DST handling.' },
        @{ Pattern = 'Missing worker validation may be marked Passed'; Message = 'Worker Service standard does not allow missing validation to be marked Passed.' },
        @{ Pattern = 'A stale worker may complete the job'; Message = 'Worker Service standard does not allow stale worker completion.' },
        @{ Pattern = 'Lease ownership only matters during claim'; Message = 'Worker Service standard does not limit ownership checks to claim time.' },
        @{ Pattern = 'Zero rows affected may still be treated as success'; Message = 'Worker Service standard does not allow zero-row protected updates as success.' },
        @{ Pattern = 'Script version strings are sufficient integrity'; Message = 'Worker Service standard does not allow version strings as sufficient integrity.' },
        @{ Pattern = 'Script hashes do not need verification'; Message = 'Worker Service standard requires script hash verification where hashes are used.' },
        @{ Pattern = 'Any valid signer is acceptable'; Message = 'Worker Service standard requires approved signer validation.' },
        @{ Pattern = 'PowerShell exit code zero always means success'; Message = 'Worker Service standard does not equate PowerShell exit code zero with success.' },
        @{ Pattern = 'Nonterminating PowerShell errors may be ignored'; Message = 'Worker Service standard does not allow ignored nonterminating PowerShell errors.' },
        @{ Pattern = 'Job input files may be replaced after approval'; Message = 'Worker Service standard does not allow approved input replacement.' },
        @{ Pattern = 'File paths are sufficient input identity'; Message = 'Worker Service standard does not allow paths as sufficient input identity.' },
        @{ Pattern = 'Partial reports may be published as final'; Message = 'Worker Service standard does not allow partial reports as final.' },
        @{ Pattern = 'Artifacts may be overwritten during retry'; Message = 'Worker Service standard does not allow retry artifact overwrite.' },
        @{ Pattern = 'Artifact hashes are optional'; Message = 'Worker Service standard requires artifact hashes where applicable.' },
        @{ Pattern = 'Outbox or durable handoff is optional for coordinated side effects'; Message = 'Worker Service standard requires durable handoff for coordinated side effects.' },
        @{ Pattern = 'A worker may acknowledge before durable completion'; Message = 'Worker Service standard does not allow acknowledgement before durable completion.' },
        @{ Pattern = 'Normal worker startup is a safe container smoke test'; Message = 'Worker Service standard does not allow normal worker startup as safe smoke test.' },
        @{ Pattern = 'Production credentials may be used for container validation'; Message = 'Worker Service standard does not allow production credentials for container validation.' },
        @{ Pattern = 'Missing Worker Service validation may be marked Passed'; Message = 'Worker Service standard does not allow missing Worker Service validation to be marked Passed.' }
    )
    foreach ($item in $workerProhibitedWeakeningPatterns) {
        if ($workerAgents -match $item.Pattern) {
            Add-Result Failed $item.Message 'agents/AGENTS_WorkerService.md'
        }
        else {
            Add-Result Passed $item.Message 'agents/AGENTS_WorkerService.md'
        }
    }
}

if ($integrationAgents) {
    Test-MinimumSemanticVersion -Text $integrationAgents -MinimumVersion '1.1.0' -Message 'Integration standard declares a valid semantic version at least 1.1.0.' -RelativePath 'agents/AGENTS_Integration.md'

    $integrationRequiredPatterns = @(
        @{ Pattern = 'REST, GraphQL, SOAP, gRPC, WebSocket, SignalR-style integrations, webhooks, message brokers, event streams, SFTP, managed file transfer, batch feeds, vendor SDKs, API gateways'; Message = 'Integration standard declares broad integration applicability.' },
        @{ Pattern = 'Before editing integration code.*agents MUST identify and record'; Message = 'Integration standard requires discovery before editing.' },
        @{ Pattern = 'Every governed integration MUST define explicit API versions, schema versions, message versions, event versions, file layout versions, or vendor SDK versions'; Message = 'Integration standard requires explicit API and schema versions.' },
        @{ Pattern = 'Integrations MUST use least-privilege credentials separated by environment, tenant, account, and purpose'; Message = 'Integration standard requires least-privilege separated credentials.' },
        @{ Pattern = 'Client secrets, API keys, webhook secrets, private keys, certificates, tokens.*MUST NOT be committed'; Message = 'Integration standard prohibits committed plaintext secrets.' },
        @{ Pattern = 'Tenant, account, partner, and subscription boundaries MUST be enforced on every request, callback, message, file, and batch'; Message = 'Integration standard requires tenant and account boundaries.' },
        @{ Pattern = 'Every integration MUST define timeouts and cancellation behavior'; Message = 'Integration standard requires timeouts and cancellation.' },
        @{ Pattern = 'Retries MUST classify retryable and nonretryable failures'; Message = 'Integration standard requires retryable and nonretryable classification.' },
        @{ Pattern = 'Retries MUST be bounded, use exponential backoff and jitter, respect `Retry-After`'; Message = 'Integration standard requires bounded retries, backoff, jitter, and Retry-After.' },
        @{ Pattern = 'Non-idempotent operations MUST use idempotency keys, deduplication, outbox/inbox, durable coordination'; Message = 'Integration standard requires idempotency and deduplication for non-idempotent retries.' },
        @{ Pattern = 'Continuation tokens MUST be treated as opaque'; Message = 'Integration standard requires opaque continuation tokens.' },
        @{ Pattern = 'HTTP 2xx, transport success, queue acknowledgement, file transfer success, or SDK call success MUST NOT automatically mean business success'; Message = 'Integration standard separates transport success from business success.' },
        @{ Pattern = 'Webhook handlers MUST validate signatures or event authenticity'; Message = 'Integration standard requires webhook signature or authenticity validation.' },
        @{ Pattern = 'Timestamp, nonce, event ID, delivery ID, digest, or equivalent replay protection MUST be enforced'; Message = 'Integration standard requires webhook replay protection.' },
        @{ Pattern = 'Queue, topic, stream, and broker integrations MUST define delivery semantics'; Message = 'Integration standard requires queue and broker delivery semantics.' },
        @{ Pattern = 'Poison messages MUST have dead-letter handling or an approved equivalent remediation path'; Message = 'Integration standard requires poison and dead-letter handling.' },
        @{ Pattern = 'outbox, inbox, durable queue handoff, saga/orchestration state, idempotent reconciliation'; Message = 'Integration standard requires durable coordination patterns.' },
        @{ Pattern = 'SFTP and managed-file-transfer integrations MUST validate host keys'; Message = 'Integration standard requires SFTP host-key validation.' },
        @{ Pattern = 'File hashes are required where a provider supplies them'; Message = 'Integration standard requires file integrity checks where available.' },
        @{ Pattern = 'Publication MUST use an atomic rename, manifest marker, immutable object version, or equivalent completion signal'; Message = 'Integration standard requires atomic file publication.' },
        @{ Pattern = 'Payloads MUST be validated against schemas before trusted processing'; Message = 'Integration standard requires schema validation for payloads.' },
        @{ Pattern = 'PII, PHI, regulated data, credentials, tokens, private keys.*MUST be redacted'; Message = 'Integration standard requires sensitive data protection and redaction.' },
        @{ Pattern = 'Correlation IDs MUST be non-secret, bounded, propagated consistently, and safe for logs'; Message = 'Integration standard requires safe correlation IDs.' },
        @{ Pattern = 'Contract tests or schema validation for requests, responses, events, and files'; Message = 'Integration standard requires contract and schema tests.' },
        @{ Pattern = 'sandbox, provider endpoint, credential, broker, certificate authority, file-transfer endpoint, or network route is unavailable, record `NotRun` or `Blocked`'; Message = 'Integration standard requires honest NotRun or Blocked statuses.' },
        @{ Pattern = 'Production MUST NOT be used merely because nonproduction is unavailable'; Message = 'Integration standard prohibits production as a test substitute.' },
        @{ Pattern = 'Unexecuted integration validation.*MUST NOT be labeled `Passed`'; Message = 'Integration standard prohibits false integration evidence.' },
        @{ Pattern = 'Agents MUST NOT fabricate commands, exit codes, workflow runs, provider responses, webhook deliveries, queue messages, file hashes, approvals'; Message = 'Integration standard prohibits fabricated integration evidence.' },
        @{ Pattern = 'Exceptions MUST follow \[../governance/EXCEPTION_PROCESS\.md\]'; Message = 'Integration standard references the exception process.' },
        @{ Pattern = '(?s)AGENTS_DotNet\.md.*AGENTS_PowerShell\.md.*AGENTS_Database\.md.*AGENTS_WorkerService\.md.*AGENTS_Infrastructure\.md.*AGENTS_WebFrontend\.md'; Message = 'Integration standard includes cross-standard handoffs.' }
    )
    foreach ($item in $integrationRequiredPatterns) {
        Test-Contains $integrationAgents $item.Pattern $item.Message 'agents/AGENTS_Integration.md'
    }

    $integrationProhibitedWeakeningPatterns = @(
        @{ Pattern = 'Webhook signatures may be ignored'; Message = 'Integration standard does not allow ignored webhook signatures.' },
        @{ Pattern = 'Retries may be unbounded'; Message = 'Integration standard does not allow unbounded retries.' },
        @{ Pattern = 'Every error is retryable'; Message = 'Integration standard does not treat every error as retryable.' },
        @{ Pattern = 'Retry loops need no jitter'; Message = 'Integration standard requires jitter.' },
        @{ Pattern = 'Continuation tokens may be modified'; Message = 'Integration standard keeps continuation tokens opaque.' },
        @{ Pattern = 'HTTP success always means business success'; Message = 'Integration standard separates HTTP success from business success.' },
        @{ Pattern = 'Client secrets may be committed'; Message = 'Integration standard prohibits committed client secrets.' },
        @{ Pattern = 'Certificate validation may be disabled'; Message = 'Integration standard prohibits certificate-validation bypass.' },
        @{ Pattern = 'Queue delivery is exactly once automatically'; Message = 'Integration standard does not claim automatic exactly-once queue delivery.' },
        @{ Pattern = 'Duplicate events may be ignored'; Message = 'Integration standard requires duplicate handling.' },
        @{ Pattern = 'Dead letters are optional for poison messages'; Message = 'Integration standard requires poison-message remediation.' },
        @{ Pattern = 'External calls may occur inside database transactions by default'; Message = 'Integration standard does not allow external calls inside database transactions by default.' },
        @{ Pattern = 'Partial success may be displayed as full success'; Message = 'Integration standard prohibits partial success as full success.' },
        @{ Pattern = 'SFTP host keys need no validation'; Message = 'Integration standard requires SFTP host-key validation.' },
        @{ Pattern = 'File hashes are unnecessary'; Message = 'Integration standard requires file hashes where available.' },
        @{ Pattern = 'Untrusted payloads may bypass schema validation'; Message = 'Integration standard prohibits schema-validation bypass.' },
        @{ Pattern = 'Production may be used when sandbox access is unavailable'; Message = 'Integration standard prohibits production as sandbox fallback.' },
        @{ Pattern = 'Missing Integration validation may be marked Passed'; Message = 'Integration standard prohibits missing Integration validation as Passed.' }
    )
    foreach ($item in $integrationProhibitedWeakeningPatterns) {
        if ($integrationAgents -match $item.Pattern) {
            Add-Result Failed $item.Message 'agents/AGENTS_Integration.md'
        }
        else {
            Add-Result Passed $item.Message 'agents/AGENTS_Integration.md'
        }
    }
}

if ($infrastructureAgents) {
    Test-MinimumSemanticVersion -Text $infrastructureAgents -MinimumVersion '1.1.1' -Message 'Infrastructure standard declares a valid semantic version at least 1.1.1.' -RelativePath 'agents/AGENTS_Infrastructure.md'

    $infrastructureRequiredPatterns = @(
        @{ Pattern = '(?is)Terraform.*OpenTofu.*Bicep.*CloudFormation.*Pulumi.*Kubernetes.*Helm.*Kustomize'; Message = 'Infrastructure standard declares broad infrastructure tooling applicability.' },
        @{ Pattern = 'PowerShell infrastructure automation.*MUST also apply \[AGENTS_PowerShell\.md\]'; Message = 'Infrastructure standard hands off PowerShell infrastructure automation.' },
        @{ Pattern = '\.NET deployment tools.*MUST also apply \[AGENTS_DotNet\.md\]'; Message = 'Infrastructure standard hands off .NET deployment work.' },
        @{ Pattern = 'Database provisioning.*MUST also apply \[AGENTS_Database\.md\]'; Message = 'Infrastructure standard hands off database infrastructure work.' },
        @{ Pattern = 'Worker services.*MUST also apply \[AGENTS_WorkerService\.md\]'; Message = 'Infrastructure standard hands off worker infrastructure work.' },
        @{ Pattern = 'Vendor APIs.*DNS/IPAM APIs.*MUST also apply \[AGENTS_Integration\.md\]'; Message = 'Infrastructure standard hands off integration provisioning work.' },
        @{ Pattern = 'Web ingress.*MUST also apply \[AGENTS_WebFrontend\.md\]'; Message = 'Infrastructure standard hands off frontend delivery infrastructure.' },
        @{ Pattern = '(?is)Before editing infrastructure, agents MUST inspect and record.*Infrastructure tool and exact version.*State backend.*Existing user changes from `git status --short`'; Message = 'Infrastructure standard requires infrastructure discovery.' },
        @{ Pattern = 'Guessing target environment from directory name, current CLI context, shell profile, default subscription, default region, default kubeconfig context, or cached credentials is prohibited'; Message = 'Infrastructure standard prohibits guessed or cached targeting.' },
        @{ Pattern = 'The default mode for AI-generated infrastructure work MUST be non-mutating'; Message = 'Infrastructure standard requires non-mutating default mode.' },
        @{ Pattern = 'Agents MUST NOT apply, deploy, destroy, import, move, force-unlock, rotate, revoke, purge, or mutate state unless explicitly requested and authorized'; Message = 'Infrastructure standard blocks unauthorized mutation.' },
        @{ Pattern = 'Every governed resource MUST have one declared source of truth'; Message = 'Infrastructure standard requires source-of-truth ownership.' },
        @{ Pattern = 'Every mutating command MUST make the following explicit'; Message = 'Infrastructure standard requires explicit target context for mutation.' },
        @{ Pattern = 'Empty target MUST NOT mean all environments or all resources'; Message = 'Infrastructure standard prevents empty target broad scope.' },
        @{ Pattern = 'Cached CLI context alone is insufficient for production mutation'; Message = 'Infrastructure standard rejects cached CLI context for production.' },
        @{ Pattern = 'Infrastructure changes MUST use plan-before-apply, preview, what-if, diff, or equivalent review output'; Message = 'Infrastructure standard requires plan-before-apply.' },
        @{ Pattern = 'Apply MUST use the reviewed saved plan artifact where the tool supports saved plans'; Message = 'Infrastructure standard binds apply to reviewed plan artifacts.' },
        @{ Pattern = 'A plan generated from one commit, variable set, state, provider set, credential, policy set, or environment MUST NOT authorize a different apply'; Message = 'Infrastructure standard prevents stale or mismatched plan apply.' },
        @{ Pattern = 'Production environment protections MUST be used where available'; Message = 'Infrastructure standard requires production approval controls.' },
        @{ Pattern = 'Critical changes MUST NOT be self-approved unless an approved emergency process applies'; Message = 'Infrastructure standard requires separation of duties for Critical changes.' },
        @{ Pattern = 'Shared or production state MUST use a remote protected backend where supported'; Message = 'Infrastructure standard requires protected remote state.' },
        @{ Pattern = 'State files MUST NOT be committed'; Message = 'Infrastructure standard prohibits committed state files.' },
        @{ Pattern = 'State backend outage is `Blocked` for apply, not a reason to bypass locking'; Message = 'Infrastructure standard prevents lock bypass on backend outage.' },
        @{ Pattern = 'Force-unlock requires proof that no active operation owns the lock'; Message = 'Infrastructure standard governs force-unlock.' },
        @{ Pattern = 'State import, move, migration, backend migration, repair, `state rm`, `state mv`, moved blocks, and manual state surgery require phased controls'; Message = 'Infrastructure standard governs state migration and repair.' },
        @{ Pattern = 'Manual state editing is prohibited unless an approved emergency procedure requires it'; Message = 'Infrastructure standard prohibits routine manual state editing.' },
        @{ Pattern = 'Infrastructure CLI versions MUST be pinned or constrained'; Message = 'Infrastructure standard requires infrastructure CLI version constraints.' },
        @{ Pattern = 'GitHub Actions MUST be pinned to immutable commit SHAs'; Message = 'Infrastructure standard requires immutable GitHub Action SHA pinning.' },
        @{ Pattern = 'Production dependencies MUST NOT use floating `latest`, `main`, `master`, mutable branch names, mutable tags, or unbounded version ranges'; Message = 'Infrastructure standard prohibits floating production dependencies.' },
        @{ Pattern = 'Dynamically downloaded scripts MUST NOT be immediately executed without integrity controls'; Message = 'Infrastructure standard prohibits unverified download-and-execute behavior.' },
        @{ Pattern = 'Protected production container and Kubernetes deployment paths MUST pin images by immutable digest'; Message = 'Infrastructure standard requires protected production image digest pinning.' },
        @{ Pattern = 'Tags MAY remain as human-readable metadata but MUST NOT be the only production identity'; Message = 'Infrastructure standard rejects tags as the only production image identity.' },
        @{ Pattern = 'Rollback MUST identify the exact prior digest'; Message = 'Infrastructure standard requires exact prior image digest for rollback.' },
        @{ Pattern = 'Image policy MUST reject unapproved digest substitution'; Message = 'Infrastructure standard requires image policy to reject unapproved digest substitution.' },
        @{ Pattern = 'Destroy, replacement, deletion, purge, resource rename, recreation, force replacement, broad refactoring, and lifecycle changes'; Message = 'Infrastructure standard controls destructive and replacement changes.' },
        @{ Pattern = 'Snapshot existence does not prove restore capability'; Message = 'Infrastructure standard distinguishes snapshots from restore proof.' },
        @{ Pattern = 'Backup configured does not prove restore tested'; Message = 'Infrastructure standard distinguishes backup configuration from restore proof.' },
        @{ Pattern = 'Networking MUST be private by default and deny by default'; Message = 'Infrastructure standard requires private-by-default networking.' },
        @{ Pattern = 'Broad ingress, wildcard source ranges, unrestricted egress'; Message = 'Infrastructure standard requires broad ingress and egress review.' },
        @{ Pattern = 'Every temporary network or firewall rule MUST define rule ID or name, owner, requestor, business reason, source, destination, protocol, port, environment, creation time, expiration time, change or ticket reference, monitoring, cleanup owner, and removal verification'; Message = 'Infrastructure standard requires temporary network rule lifecycle metadata.' },
        @{ Pattern = 'Temporary rules MUST have an explicit expiration'; Message = 'Infrastructure standard requires temporary rule expiration.' },
        @{ Pattern = 'Temporary rules MUST be removed automatically where the platform supports it, or have a documented manual removal task and owner'; Message = 'Infrastructure standard requires temporary rule cleanup ownership.' },
        @{ Pattern = 'Expired rules MUST NOT remain active silently'; Message = 'Infrastructure standard rejects silently active expired network rules.' },
        @{ Pattern = 'Removal MUST be verified'; Message = 'Infrastructure standard requires firewall rule removal verification.' },
        @{ Pattern = 'Administrative interfaces such as SSH, RDP, WinRM, vCenter, hypervisor management, Kubernetes API, database administration, storage administration, and PKI administration MUST NOT be exposed publicly without Critical approval and compensating controls'; Message = 'Infrastructure standard prohibits public administrative interfaces without Critical approval.' },
        @{ Pattern = 'Emergency access requires break-glass controls, short expiration, audit, and removal verification'; Message = 'Infrastructure standard requires emergency network access lifecycle controls.' },
        @{ Pattern = 'Every DNS or IPAM change MUST define environment, DNS server or provider, zone, view or split-horizon scope, record name, record type, existing value'; Message = 'Infrastructure standard requires DNS/IPAM record discovery and target detail.' },
        @{ Pattern = 'Existing records MUST be read and recorded before replacement or deletion'; Message = 'Infrastructure standard requires existing DNS record capture.' },
        @{ Pattern = 'Forward and reverse or PTR records MUST be considered together where reverse DNS is relevant'; Message = 'Infrastructure standard requires PTR/reverse record consideration.' },
        @{ Pattern = 'Split-horizon DNS views MUST be explicit'; Message = 'Infrastructure standard requires explicit split-horizon DNS scope.' },
        @{ Pattern = 'DNSSEC changes MUST define key, signer, chain-of-trust, rollover, and rollback review'; Message = 'Infrastructure standard requires DNSSEC rollover and rollback review.' },
        @{ Pattern = 'Certificate SANs and service hostnames MUST align before traffic cutover'; Message = 'Infrastructure standard requires certificate SAN alignment before DNS cutover.' },
        @{ Pattern = 'TTL reduction for planned cutover MUST occur early enough to become effective before the change window'; Message = 'Infrastructure standard requires early DNS TTL reduction.' },
        @{ Pattern = 'Validation SHOULD query multiple authoritative or recursive resolvers appropriate to the environment'; Message = 'Infrastructure standard requires multi-resolver DNS validation guidance.' },
        @{ Pattern = 'Rollback MUST identify the exact prior record values'; Message = 'Infrastructure standard requires exact DNS rollback values.' },
        @{ Pattern = 'DNS rollback MUST account for TTL and caches'; Message = 'Infrastructure standard governs DNS rollback.' },
        @{ Pattern = 'Infrastructure identity MUST follow least privilege'; Message = 'Infrastructure standard requires least-privilege IAM and RBAC.' },
        @{ Pattern = 'Wildcard IAM, broad administrator access, cluster-admin'; Message = 'Infrastructure standard controls privileged IAM and RBAC.' },
        @{ Pattern = 'Every service or workload identity MUST define identity type, owner, purpose, environment, scope, permissions, trust relationship, authentication mechanism, credential source, rotation, expiration'; Message = 'Infrastructure standard requires service/workload identity lifecycle detail.' },
        @{ Pattern = 'Managed identity, workload identity, federated identity, gMSA, virtual account, or equivalent short-lived mechanism MUST be preferred where supported'; Message = 'Infrastructure standard prefers workload identity and short-lived mechanisms.' },
        @{ Pattern = 'Long-lived static credentials MUST NOT be used where a supported workload identity can meet the requirement'; Message = 'Infrastructure standard prohibits unnecessary long-lived service-account credentials.' },
        @{ Pattern = 'Interactive login MUST be disabled for service accounts unless explicitly required and approved'; Message = 'Infrastructure standard restricts service-account interactive login.' },
        @{ Pattern = 'Credentials MUST have defined rotation and expiration'; Message = 'Infrastructure standard requires service-account credential rotation and expiration.' },
        @{ Pattern = 'Kubernetes service accounts MUST define token mounting, audience, expiration, projected-token behavior, and RBAC'; Message = 'Infrastructure standard requires Kubernetes service-account token controls.' },
        @{ Pattern = 'IAM policy simulation, access review, or equivalent negative-permission testing SHOULD be used where supported'; Message = 'Infrastructure standard requires IAM simulation or access review guidance.' },
        @{ Pattern = 'Removing access requires administrator and workload lockout analysis'; Message = 'Infrastructure standard requires service-account lockout analysis.' },
        @{ Pattern = 'Privilege escalation paths through pass-role, impersonation, assume-role, token creation, group nesting, or delegated administration MUST be reviewed'; Message = 'Infrastructure standard requires privilege-escalation path review.' },
        @{ Pattern = 'Secrets, private keys, certificates, kubeconfigs, SSH keys, tokens, service-principal secrets, signing keys, and state containing sensitive values MUST be stored in approved secret stores'; Message = 'Infrastructure standard requires approved secret storage.' },
        @{ Pattern = 'Certificate validation MUST NOT be bypassed'; Message = 'Infrastructure standard prohibits certificate-validation bypass.' },
        @{ Pattern = 'Certificate and PKI changes MUST define subject, SANs, issuer, chain, trust store'; Message = 'Infrastructure standard requires PKI and certificate lifecycle controls.' },
        @{ Pattern = 'Every IIS infrastructure change MUST define site name, application name where applicable, application pool name, application pool identity'; Message = 'Infrastructure standard requires IIS site and app-pool definition.' },
        @{ Pattern = 'IIS sites and applications MUST NOT use broad filesystem permissions such as Everyone, Users, Authenticated Users'; Message = 'Infrastructure standard prohibits broad IIS filesystem permissions.' },
        @{ Pattern = 'Application pool identities MUST receive only the minimum path, certificate, registry, network, and service permissions required'; Message = 'Infrastructure standard requires app-pool least privilege.' },
        @{ Pattern = 'Production bindings MUST explicitly identify hostname, port, protocol, SNI, and certificate'; Message = 'Infrastructure standard requires explicit IIS production bindings.' },
        @{ Pattern = 'Wildcard bindings require High or Critical review'; Message = 'Infrastructure standard requires wildcard IIS binding review.' },
        @{ Pattern = '`web\.config` and deployment logs MUST NOT contain plaintext secrets'; Message = 'Infrastructure standard prohibits plaintext secrets in web.config and deployment logs.' },
        @{ Pattern = 'Successful file copy or site start MUST NOT be treated as application readiness'; Message = 'Infrastructure standard rejects IIS site-start as readiness proof.' },
        @{ Pattern = 'Hosting bundle/runtime compatibility MUST be validated for hosted \.NET applications under \[AGENTS_DotNet\.md\]'; Message = 'Infrastructure standard requires IIS .NET hosting-bundle validation.' },
        @{ Pattern = 'Every Windows Service infrastructure change MUST define service name, display name, description, binary path, binary arguments, quoted path behavior'; Message = 'Infrastructure standard requires Windows Service definition detail.' },
        @{ Pattern = 'Service binary paths containing spaces MUST be safely quoted'; Message = 'Infrastructure standard requires safely quoted Windows Service binary paths.' },
        @{ Pattern = 'Unquoted service paths are prohibited'; Message = 'Infrastructure standard prohibits unquoted Windows Service paths.' },
        @{ Pattern = 'Service executable, configuration, and working directories MUST NOT be writable by untrusted or ordinary users'; Message = 'Infrastructure standard protects Windows Service directories.' },
        @{ Pattern = 'Service Control Manager ACLs MUST prevent unauthorized reconfiguration, start, stop, delete, or binary-path changes'; Message = 'Infrastructure standard requires Windows Service ACL controls.' },
        @{ Pattern = 'Secrets MUST NOT be embedded in ImagePath, command-line arguments, registry values, or logs'; Message = 'Infrastructure standard prohibits Windows Service secrets in ImagePath or arguments.' },
        @{ Pattern = 'A service being in Running state MUST NOT be treated as full application readiness'; Message = 'Infrastructure standard rejects Windows Service Running state as readiness proof.' },
        @{ Pattern = 'Every systemd service change MUST define unit name, description, User, Group'; Message = 'Infrastructure standard requires systemd unit definition detail.' },
        @{ Pattern = 'User and Group MUST be explicit'; Message = 'Infrastructure standard requires explicit systemd User and Group.' },
        @{ Pattern = 'Root execution requires High or Critical review'; Message = 'Infrastructure standard requires systemd root-execution review.' },
        @{ Pattern = 'NoNewPrivileges SHOULD be enabled where supported'; Message = 'Infrastructure standard requires NoNewPrivileges guidance.' },
        @{ Pattern = 'CapabilityBoundingSet and AmbientCapabilities MUST be minimized'; Message = 'Infrastructure standard requires systemd capability minimization.' },
        @{ Pattern = 'ProtectSystem, ProtectHome, PrivateTmp, PrivateDevices, ProtectKernelTunables, ProtectKernelModules, ProtectControlGroups, RestrictAddressFamilies, RestrictNamespaces, LockPersonality, MemoryDenyWriteExecute, and SystemCallFilter MUST be reviewed where supported'; Message = 'Infrastructure standard requires systemd filesystem and sandboxing review.' },
        @{ Pattern = 'EnvironmentFile and secret files MUST not be world-readable'; Message = 'Infrastructure standard prohibits world-readable systemd secret files.' },
        @{ Pattern = 'Active state MUST NOT be treated as full application readiness'; Message = 'Infrastructure standard rejects systemd active state as readiness proof.' },
        @{ Pattern = 'Kubernetes workloads MUST run non-root where feasible'; Message = 'Infrastructure standard requires Kubernetes non-root posture where feasible.' },
        @{ Pattern = 'Privileged containers, hostPath mounts, host networking, host PID, added Linux capabilities, cluster-admin'; Message = 'Infrastructure standard controls privileged Kubernetes and container settings.' },
        @{ Pattern = 'Container and Kubernetes work MUST define image source, tag, digest'; Message = 'Infrastructure standard requires image identity and digest review.' },
        @{ Pattern = 'Backup and disaster-recovery configuration MUST identify.*RPO.*RTO'; Message = 'Infrastructure standard requires backup, DR, RPO, and RTO controls.' },
        @{ Pattern = 'Drift MUST be detected and reviewed before applying changes to managed resources'; Message = 'Infrastructure standard requires drift detection.' },
        @{ Pattern = 'Policy failures MUST NOT be ignored, suppressed, or converted to success'; Message = 'Infrastructure standard requires policy-as-code enforcement.' },
        @{ Pattern = 'Unbounded autoscaling is prohibited'; Message = 'Infrastructure standard prohibits unbounded autoscaling.' },
        @{ Pattern = 'Infrastructure CI/CD MUST use least-privilege workflow permissions'; Message = 'Infrastructure standard requires CI/CD least privilege.' },
        @{ Pattern = 'Production mutation MUST NOT run from untrusted pull requests'; Message = 'Infrastructure standard prohibits production mutation from untrusted PRs.' },
        @{ Pattern = 'Validation Commands'; Message = 'Infrastructure standard includes validation commands section.' },
        @{ Pattern = 'terraform fmt -check -recursive'; Message = 'Infrastructure standard includes Terraform/OpenTofu validation examples.' },
        @{ Pattern = 'terraform init -backend=false` is suitable only for static initialization or validation where supported'; Message = 'Infrastructure standard qualifies backendless Terraform initialization.' },
        @{ Pattern = 'A plan generated without the authoritative backend or state MUST NOT be treated as authoritative production plan evidence'; Message = 'Infrastructure standard rejects backendless plans as authoritative production evidence.' },
        @{ Pattern = 'Backendless validation MUST NOT be used to claim drift detection, replacement accuracy, destroy accuracy, or no-change status'; Message = 'Infrastructure standard restricts backendless Terraform evidence claims.' },
        @{ Pattern = 'Production plan evidence requires the approved backend, workspace, variables, credentials, state, and target context'; Message = 'Infrastructure standard requires authoritative Terraform plan context.' },
        @{ Pattern = 'az deployment group what-if'; Message = 'Infrastructure standard includes Azure what-if validation example.' },
        @{ Pattern = 'aws cloudformation validate-template'; Message = 'Infrastructure standard includes AWS CloudFormation validation example.' },
        @{ Pattern = '`aws cloudformation create-change-set` is a credentialed API mutation'; Message = 'Infrastructure standard identifies CloudFormation change-set creation as mutation.' },
        @{ Pattern = 'It MUST NOT be presented as ordinary offline static validation'; Message = 'Infrastructure standard separates CloudFormation change sets from offline validation.' },
        @{ Pattern = 'Unused change sets MUST be deleted or expired according to policy'; Message = 'Infrastructure standard requires CloudFormation change-set cleanup.' },
        @{ Pattern = 'Creation success does not prove execution success or stack readiness'; Message = 'Infrastructure standard rejects CloudFormation change-set creation as readiness proof.' },
        @{ Pattern = 'kubectl apply --dry-run=server'; Message = 'Infrastructure standard includes Kubernetes server-side dry-run example.' },
        @{ Pattern = 'helm template'; Message = 'Infrastructure standard includes Helm rendering validation example.' },
        @{ Pattern = 'Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`'; Message = 'Infrastructure standard declares honest completion statuses.' },
        @{ Pattern = 'Unexecuted plan, apply, deployment, destroy, restore, failover, DNS, firewall, certificate, cluster, service, or production validation MUST NOT be labeled `Passed`'; Message = 'Infrastructure standard prohibits false infrastructure evidence.' }
    )
    foreach ($item in $infrastructureRequiredPatterns) {
        Test-Contains $infrastructureAgents $item.Pattern $item.Message 'agents/AGENTS_Infrastructure.md'
    }

    $infrastructureProhibitedWeakeningPatterns = @(
        @{ Pattern = 'Apply may run without a plan'; Message = 'Infrastructure standard does not allow apply without a plan where supported.' },
        @{ Pattern = 'Cached CLI context is sufficient for production'; Message = 'Infrastructure standard does not allow cached CLI context as production proof.' },
        @{ Pattern = 'Empty target means all resources'; Message = 'Infrastructure standard does not allow empty target to mean all resources.' },
        @{ Pattern = 'State locking may be bypassed'; Message = 'Infrastructure standard does not allow state locking bypass.' },
        @{ Pattern = 'State files may be committed'; Message = 'Infrastructure standard does not allow committed state files.' },
        @{ Pattern = 'Force-unlock is always safe'; Message = 'Infrastructure standard does not treat force-unlock as always safe.' },
        @{ Pattern = 'Manual state editing is acceptable by default'; Message = 'Infrastructure standard does not allow default manual state editing.' },
        @{ Pattern = 'Floating latest tags are preferred'; Message = 'Infrastructure standard does not prefer floating latest tags.' },
        @{ Pattern = 'GitHub Actions may use mutable tags'; Message = 'Infrastructure standard does not allow mutable GitHub Action tags.' },
        @{ Pattern = 'Destroy requires no approval'; Message = 'Infrastructure standard requires destructive approval.' },
        @{ Pattern = 'Public ingress from anywhere is safe'; Message = 'Infrastructure standard does not treat public ingress from anywhere as safe.' },
        @{ Pattern = 'Wildcard IAM is acceptable'; Message = 'Infrastructure standard does not allow wildcard IAM without review.' },
        @{ Pattern = 'Plaintext secrets may be stored in tfvars'; Message = 'Infrastructure standard does not allow plaintext secrets in tfvars.' },
        @{ Pattern = 'Certificate validation may be disabled'; Message = 'Infrastructure standard does not allow certificate-validation bypass.' },
        @{ Pattern = 'Snapshots prove restore capability'; Message = 'Infrastructure standard does not treat snapshots as restore proof.' },
        @{ Pattern = 'Production may be used when test environments are unavailable'; Message = 'Infrastructure standard does not allow production as a test substitute.' },
        @{ Pattern = 'Cluster-admin is the default'; Message = 'Infrastructure standard does not allow cluster-admin as default.' },
        @{ Pattern = 'Privileged containers are preferred'; Message = 'Infrastructure standard does not prefer privileged containers.' },
        @{ Pattern = 'Unbounded autoscaling is acceptable'; Message = 'Infrastructure standard does not allow unbounded autoscaling.' },
        @{ Pattern = 'Policy failures may be ignored'; Message = 'Infrastructure standard does not allow ignored policy failures.' },
        @{ Pattern = 'Apply success proves readiness'; Message = 'Infrastructure standard does not equate apply success with readiness.' },
        @{ Pattern = 'Missing infrastructure validation may be marked Passed'; Message = 'Infrastructure standard does not allow missing infrastructure validation to be marked Passed.' },
        @{ Pattern = 'Everyone may have write access to IIS content'; Message = 'Infrastructure standard does not allow broad write access to IIS content.' },
        @{ Pattern = 'Wildcard IIS bindings require no review'; Message = 'Infrastructure standard requires wildcard IIS binding review.' },
        @{ Pattern = 'IIS site started means application ready'; Message = 'Infrastructure standard does not equate IIS site start with readiness.' },
        @{ Pattern = 'Unquoted Windows Service paths are acceptable'; Message = 'Infrastructure standard prohibits unquoted Windows Service paths.' },
        @{ Pattern = 'Service executable directories may be user writable'; Message = 'Infrastructure standard protects Windows Service executable directories.' },
        @{ Pattern = 'Service accounts may log on interactively by default'; Message = 'Infrastructure standard restricts service-account interactive login.' },
        @{ Pattern = 'Windows Service Running state proves readiness'; Message = 'Infrastructure standard does not equate Windows Service Running state with readiness.' },
        @{ Pattern = 'systemd services should run as root by default'; Message = 'Infrastructure standard does not allow root as the default systemd identity.' },
        @{ Pattern = 'NoNewPrivileges is unnecessary'; Message = 'Infrastructure standard keeps NoNewPrivileges guidance.' },
        @{ Pattern = 'World-readable environment files may contain secrets'; Message = 'Infrastructure standard prohibits world-readable secret environment files.' },
        @{ Pattern = 'systemd active state proves readiness'; Message = 'Infrastructure standard does not equate systemd active state with readiness.' },
        @{ Pattern = 'PTR records never matter'; Message = 'Infrastructure standard requires PTR consideration where relevant.' },
        @{ Pattern = 'Split-horizon DNS does not need review'; Message = 'Infrastructure standard requires split-horizon DNS scope.' },
        @{ Pattern = 'DNSSEC changes require no rollover plan'; Message = 'Infrastructure standard requires DNSSEC rollover planning.' },
        @{ Pattern = 'DNS TTL may be lowered at cutover time with immediate effect'; Message = 'Infrastructure standard rejects immediate TTL assumptions.' },
        @{ Pattern = 'Certificate SANs do not need to match DNS'; Message = 'Infrastructure standard requires certificate SAN and DNS alignment.' },
        @{ Pattern = 'Production image tags are sufficient without digests'; Message = 'Infrastructure standard requires production image digests.' },
        @{ Pattern = 'Latest tags are acceptable for production'; Message = 'Infrastructure standard does not accept latest tags for production identity.' },
        @{ Pattern = 'Temporary firewall rules need no expiration'; Message = 'Infrastructure standard requires temporary firewall expiration.' },
        @{ Pattern = 'Public administrative interfaces are acceptable'; Message = 'Infrastructure standard prohibits public administrative interfaces without Critical approval.' },
        @{ Pattern = 'Emergency firewall access may remain indefinitely'; Message = 'Infrastructure standard requires emergency firewall cleanup.' },
        @{ Pattern = 'Long-lived service-account credentials are preferred'; Message = 'Infrastructure standard prefers workload identity over long-lived credentials.' },
        @{ Pattern = 'Interactive login may remain enabled for service accounts'; Message = 'Infrastructure standard disables unnecessary service-account interactive login.' },
        @{ Pattern = 'Kubernetes service-account tokens need no review'; Message = 'Infrastructure standard requires Kubernetes service-account token review.' },
        @{ Pattern = 'Backendless Terraform plans are authoritative production evidence'; Message = 'Infrastructure standard rejects backendless Terraform plans as authoritative production evidence.' },
        @{ Pattern = 'CloudFormation change-set creation is offline static validation'; Message = 'Infrastructure standard identifies CloudFormation change-set creation as credentialed mutation.' },
        @{ Pattern = 'Missing Infrastructure 1.1.1 validation may be marked Passed'; Message = 'Infrastructure standard does not allow missing Infrastructure 1.1.1 validation to be marked Passed.' }
    )
    foreach ($item in $infrastructureProhibitedWeakeningPatterns) {
        if ($infrastructureAgents -match $item.Pattern) {
            Add-Result Failed $item.Message 'agents/AGENTS_Infrastructure.md'
        }
        else {
            Add-Result Passed $item.Message 'agents/AGENTS_Infrastructure.md'
        }
    }
}

if ($pythonAgents) {
    Test-MinimumSemanticVersion -Text $pythonAgents -MinimumVersion '1.0.0' -Message 'Python standard declares a valid semantic version at least 1.0.0.' -RelativePath 'agents/AGENTS_Python.md'
    foreach ($heading in @('Purpose','Applicability And Inheritance','Normative Terminology','Required Discovery','Risk Classification','Supported Runtime And Compatibility','Architecture And Project Structure','Dependency And Supply-Chain Controls','Configuration And Secret Handling','Type And Data Safety','Input Validation And Trust Boundaries','Error And Exception Handling','Logging And Sensitive-Data Redaction','Filesystem And Path Safety','External Process And Command Execution','Network And Integration Behavior','Async And Concurrency','Testing Requirements','Static-Analysis Requirements','Packaging And Distribution','Deployment And Operational Requirements','Validation Commands','Evidence Requirements','Rollback Requirements','Exceptions','Cross-Standard Handoffs','Related Documents','Revision History')) {
        Test-Contains $pythonAgents "(?im)^## $([regex]::Escape($heading))\s*$" "Python standard includes required section '$heading'." 'agents/AGENTS_Python.md'
    }
    $pythonRequiredPatterns = @(
        @{ Pattern='inherits \[AGENTS_Base\.md\]'; Message='Python standard inherits the base standard.' },
        @{ Pattern='supported CPython version matrix'; Message='Python standard requires a supported CPython runtime matrix.' },
        @{ Pattern='Dependency resolution MUST be reproducible'; Message='Python standard requires reproducible dependency resolution.' },
        @{ Pattern='External commands MUST prefer argument arrays'; Message='Python standard requires safe subprocess argument boundaries.' },
        @{ Pattern='Unsafe shell interpolation.*prohibited'; Message='Python standard prohibits unsafe shell interpolation.' },
        @{ Pattern='`shell=True` MUST NOT be used with untrusted or concatenated input'; Message='Python standard prohibits unsafe shell=True use.' },
        @{ Pattern='Untrusted data MUST NOT be loaded with unsafe pickle, marshal'; Message='Python standard prohibits unsafe deserialization.' },
        @{ Pattern='Network clients MUST.*explicit connection and operation timeouts'; Message='Python standard requires network timeouts.' },
        @{ Pattern='Secrets MUST NOT be committed, embedded in artifacts, placed in URLs, exposed in logs or exceptions'; Message='Python standard protects secrets.' },
        @{ Pattern='MUST include positive, negative, boundary, failure-path, and security cases'; Message='Python standard mandates negative-path testing.' },
        @{ Pattern='Missing tools or environments MUST be reported as `NotRun` or `Blocked`'; Message='Python standard preserves missing-tool status semantics.' },
        @{ Pattern='AGENTS_WebFrontend\.md'; Message='Python standard hands off frontend work.' },
        @{ Pattern='AGENTS_Database\.md'; Message='Python standard hands off database work.' },
        @{ Pattern='AGENTS_WorkerService\.md'; Message='Python standard hands off worker work.' },
        @{ Pattern='AGENTS_Integration\.md'; Message='Python standard hands off integration work.' },
        @{ Pattern='AGENTS_Infrastructure\.md'; Message='Python standard hands off infrastructure work.' },
        @{ Pattern='AGENTS_PowerShell\.md'; Message='Python standard hands off PowerShell work.' },
        @{ Pattern='AGENTS_DotNet\.md'; Message='Python standard hands off .NET work.' },
        @{ Pattern='Agents MUST NOT fabricate interpreter coverage, tests, builds, scans, workflow runs, or approvals'; Message='Python standard prohibits fabricated evidence.' },
        @{ Pattern='EXCEPTION_PROCESS\.md'; Message='Python standard references the exception process.' },
        @{ Pattern='COMPLETION_EVIDENCE\.md'; Message='Python standard references completion evidence.' }
    )
    foreach ($item in $pythonRequiredPatterns) { Test-Contains $pythonAgents $item.Pattern $item.Message 'agents/AGENTS_Python.md' }
    Test-MarkdownRelativeLinks -Text $pythonAgents -FullPath $pythonPath
}

if ($bashAgents) {
    Test-MinimumSemanticVersion -Text $bashAgents -MinimumVersion '1.0.0' -Message 'Bash standard declares a valid semantic version at least 1.0.0.' -RelativePath 'agents/AGENTS_Bash.md'
    foreach ($heading in @('Purpose','Applicability And Inheritance','Normative Terminology','Required Discovery','Risk Classification','Shell Identity And Compatibility','Architecture And Script Structure','Strict And Failure Behavior','Quoting And Expansion','Configuration And Secret Handling','Input Validation And Trust Boundaries','Error Handling And Logging','Command Execution','Filesystem And Destructive Operations','Temporary Resources And Cleanup','Downloads And Supply Chain','Network And Integration Behavior','Concurrency And Lifecycle','Testing Requirements','Static-Analysis Requirements','Packaging And Distribution','Deployment And Operational Requirements','Validation Commands','Evidence Requirements','Rollback Requirements','Exceptions','Cross-Standard Handoffs','Related Documents','Revision History')) {
        Test-Contains $bashAgents "(?im)^## $([regex]::Escape($heading))\s*$" "Bash standard includes required section '$heading'." 'agents/AGENTS_Bash.md'
    }
    $bashRequiredPatterns = @(
        @{ Pattern='inherits \[AGENTS_Base\.md\]'; Message='Bash standard inherits the base standard.' },
        @{ Pattern='declare whether it requires Bash or portable POSIX `sh`'; Message='Bash standard distinguishes Bash from POSIX sh.' },
        @{ Pattern='Variable expansions MUST be quoted'; Message='Bash standard requires safe quoting.' },
        @{ Pattern='reject empty, root, home, wildcard, traversal, or unbounded destructive targets'; Message='Bash standard rejects unsafe destructive targets.' },
        @{ Pattern='Unsafe `eval` is prohibited'; Message='Bash standard prohibits unsafe eval.' },
        @{ Pattern='Temporary files and directories MUST use `mktemp`'; Message='Bash standard requires safe temporary resources.' },
        @{ Pattern='Unverified `curl \| bash`, `wget \| sh`.*prohibited'; Message='Bash standard prohibits unverified download execution.' },
        @{ Pattern='Secrets MUST NOT be exposed through `set -x`'; Message='Bash standard protects secrets from tracing.' },
        @{ Pattern='MUST preserve command and pipeline failure exit codes'; Message='Bash standard preserves failure propagation.' },
        @{ Pattern='MUST cover syntax, positive, negative, boundary, destructive-target, quoting, signal, cleanup, pipeline, command-failure, and failure-path behavior'; Message='Bash standard mandates negative-path testing.' },
        @{ Pattern='Missing tools or environments MUST be reported as `NotRun` or `Blocked`'; Message='Bash standard preserves missing-tool status semantics.' },
        @{ Pattern='AGENTS_Infrastructure\.md'; Message='Bash standard hands off infrastructure work.' },
        @{ Pattern='AGENTS_Integration\.md'; Message='Bash standard hands off integration work.' },
        @{ Pattern='AGENTS_WorkerService\.md'; Message='Bash standard hands off worker work.' },
        @{ Pattern='AGENTS_Database\.md'; Message='Bash standard hands off database work.' },
        @{ Pattern='AGENTS_PowerShell\.md'; Message='Bash standard hands off PowerShell work.' },
        @{ Pattern='AGENTS_WebFrontend\.md'; Message='Bash standard hands off frontend work.' },
        @{ Pattern='AGENTS_DotNet\.md'; Message='Bash standard hands off .NET work.' },
        @{ Pattern='AGENTS_Python\.md'; Message='Bash standard hands off Python work.' },
        @{ Pattern='Agents MUST NOT fabricate shell compatibility, analysis, tests, workflow runs, approvals, or production behavior'; Message='Bash standard prohibits fabricated evidence.' },
        @{ Pattern='EXCEPTION_PROCESS\.md'; Message='Bash standard references the exception process.' },
        @{ Pattern='COMPLETION_EVIDENCE\.md'; Message='Bash standard references completion evidence.' }
    )
    foreach ($item in $bashRequiredPatterns) { Test-Contains $bashAgents $item.Pattern $item.Message 'agents/AGENTS_Bash.md' }
    Test-MarkdownRelativeLinks -Text $bashAgents -FullPath $bashPath
}

$baseWordCount = Get-WordCount -Text $base
$rootWordCount = Get-WordCount -Text $rootAgents
if ($rootWordCount -lt [math]::Floor($baseWordCount * 0.85)) {
    Add-Result Passed 'Root AGENTS.md does not duplicate the full base standard.' 'AGENTS.md'
}
else {
    Add-Result Failed 'Root AGENTS.md is too similar in size to the base standard and may duplicate it.' 'AGENTS.md'
}

if (-not @($results | Where-Object status -eq 'Failed')) {
    Add-Result Passed 'Agent standards validation completed.' '.'
}

$report = New-ValidationReport -Results @($results)
Write-ValidationReport -Report $report -OutputJson $OutputJson
if ($report.failed -gt 0) { exit 1 }
exit 0
