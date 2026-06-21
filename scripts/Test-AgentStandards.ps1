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
        [ValidateSet('Passed','Failed','Warning','NotRun','Blocked')][string]$Status,
        [string]$Message,
        [string]$RelativePath
    )
    $results.Add((New-ValidationResult -Status $Status -Message $Message -Path $RelativePath))
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
$databasePath = Join-Path $root 'agents/AGENTS_Database.md'
$workerPath = Join-Path $root 'agents/AGENTS_WorkerService.md'

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
$databaseAgents = if (Test-Path -LiteralPath $databasePath -PathType Leaf) { Get-Content -LiteralPath $databasePath -Raw } else { '' }
$workerAgents = if (Test-Path -LiteralPath $workerPath -PathType Leaf) { Get-Content -LiteralPath $workerPath -Raw } else { '' }

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
    'pwsh -NoProfile -File scripts/Test-AgentStandards.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-YamlSyntax.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-GitHubWorkflowArchitecture.ps1 -Path . -DefaultBranch master',
    'pwsh -NoProfile -File scripts/Test-JsonSchemas.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-MarkdownLinks.ps1 -Path .',
    'pwsh -NoProfile -File scripts/Test-DocumentationCompleteness.ps1 -Path .',
    'pwsh -NoProfile -File actions/validate-contract/Invoke-ContractValidation.ps1 -Path .',
    'pwsh -NoProfile -File actions/forbidden-pattern-scan/Invoke-ForbiddenPatternScan.ps1 -Path . -OutputJson evidence/forbidden-patterns.json',
    'pwsh -NoProfile -File actions/repository-health/Invoke-RepositoryHealth.ps1 -Path .',
    'Invoke-Pester -Path tests -Output Detailed',
    'Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error',
    'git status --short',
    'git diff --check',
    'git diff',
    'git ls-files'
)
foreach ($command in $requiredCommands) {
    if ($rootAgents.Contains($command)) {
        Add-Result Passed "Required repository validation command is present: $command" 'AGENTS.md'
    }
    else {
        Add-Result Failed "Required repository validation command is missing: $command" 'AGENTS.md'
    }
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
    'agents/AGENTS_Infrastructure.md'
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
