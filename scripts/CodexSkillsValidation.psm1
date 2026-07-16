Set-StrictMode -Version Latest

$script:Limits = [ordered]@{
    MaxSkills = 64
    MaxFilesPerSkill = 128
    MaxSkillFileBytes = 262144
    MaxMetadataBytes = 32768
    MaxYamlDepth = 12
    MaxYamlNodes = 2048
    MaxReferences = 128
    MaxBehaviorCases = 128
    MaxPromptLength = 4096
    MaxDescriptionLength = 1024
}

function New-SkillValidationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RuleId,
        [Parameter(Mandatory)][ValidateSet('Passed','Failed','Blocked','NotRun','NotApplicable')][string]$Status,
        [Parameter(Mandatory)][ValidateSet('info','warning','error')][string]$Severity,
        [Parameter(Mandatory)][string]$Message,
        [string]$Path = '',
        [string]$SkillName = '',
        [bool]$Deterministic = $true,
        [bool]$RequiredValidation = $true,
        [object]$Data = $null
    )
    [ordered]@{
        ruleId = $RuleId
        status = $Status
        severity = $Severity
        message = $Message
        path = $Path
        skillName = $SkillName
        deterministic = $Deterministic
        requiredValidation = $RequiredValidation
        data = $Data
    }
}

function Get-SafeRelativePath {
    param([string]$Root, [string]$Path)
    [System.IO.Path]::GetRelativePath($Root, $Path).Replace('\','/')
}

function Get-OptionalProperty {
    param([AllowNull()]$InputObject, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject.PSObject.Properties.Name -contains $Name) { return $InputObject.$Name }
    $null
}

function Resolve-BoundedChildPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ChildPath,
        [switch]$AllowMissingLeaf
    )
    if ([System.IO.Path]::IsPathRooted($ChildPath)) { throw 'Absolute paths are not allowed.' }
    $rootFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootFull $ChildPath))
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $boundary = $rootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($boundary, $comparison)) { throw 'Path resolves outside the approved root.' }
    $current = $rootFull
    foreach ($segment in @([System.IO.Path]::GetRelativePath($rootFull, $candidate) -split '[\\/]' | Where-Object { $_ -and $_ -ne '.' })) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) { break }
        $item = Get-Item -LiteralPath $current -Force
        if ($item.Name -cne $segment) { throw 'Path component casing does not match the governed file-system entry.' }
        if ($item.LinkType -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { throw 'Path traverses a symbolic link, junction, or reparse point.' }
    }
    if (-not $AllowMissingLeaf -and -not (Test-Path -LiteralPath $candidate)) { throw 'Referenced path does not exist.' }
    $candidate
}

function Get-BoundedTreeFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [int]$MaxFiles = $script:Limits.MaxFilesPerSkill,
        [int]$MaxFileBytes = $script:Limits.MaxSkillFileBytes
    )
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $rootItem = Get-Item -LiteralPath $resolvedRoot -Force
    if ($rootItem.LinkType -or ($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        throw 'Governed directory must not be a symbolic link, junction, or reparse point.'
    }
    $files = [System.Collections.Generic.List[object]]::new()
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($resolvedRoot)
    $entries = 0
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $current -Force)) {
            $entries++
            if ($entries -gt ($MaxFiles * 2)) { throw 'Governed tree entry count exceeds the configured limit.' }
            if ($item.LinkType -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                throw 'Governed tree contains a symbolic link, junction, or reparse point.'
            }
            if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
            if ($item.Length -gt $MaxFileBytes) { throw "Governed file exceeds the $MaxFileBytes byte limit." }
            $files.Add($item)
            if ($files.Count -gt $MaxFiles) { throw 'Governed file count exceeds the configured limit.' }
        }
    }
    @($files)
}

function Test-IsYamlMapping {
    param([AllowNull()]$Value)
    $Value -is [System.Management.Automation.PSCustomObject] -or $Value -is [System.Collections.IDictionary]
}

function ConvertFrom-SafeYamlFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path, [int]$MaxBytes = $script:Limits.MaxMetadataBytes)
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Length -gt $MaxBytes) { throw "YAML input exceeds the $MaxBytes byte limit." }
    $program = @'
import json, pathlib, sys, yaml
class UniqueSafeLoader(yaml.SafeLoader):
    node_count = 0
    def compose_node(self, parent, index):
        if self.check_event(yaml.AliasEvent):
            raise ValueError("YAML aliases are not allowed")
        self.node_count += 1
        if self.node_count > int(sys.argv[3]):
            raise ValueError("YAML node limit exceeded")
        return super().compose_node(parent, index)
for ch, resolvers in list(UniqueSafeLoader.yaml_implicit_resolvers.items()):
    UniqueSafeLoader.yaml_implicit_resolvers[ch] = [
        (tag, regexp) for tag, regexp in resolvers
        if tag != "tag:yaml.org,2002:timestamp"
    ]
def construct_mapping(loader, node, deep=False):
    mapping = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise ValueError("duplicate YAML key")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping
UniqueSafeLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping)
def depth(value):
    if isinstance(value, dict): return 1 + max([depth(v) for v in value.values()] or [0])
    if isinstance(value, list): return 1 + max([depth(v) for v in value] or [0])
    return 0
try:
    text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
    value = yaml.load(text, Loader=UniqueSafeLoader)
    if depth(value) > int(sys.argv[2]): raise ValueError("YAML nesting limit exceeded")
    print(json.dumps({"ok": True, "value": value}, ensure_ascii=True))
except Exception as exc:
    print(json.dumps({"ok": False, "error": str(exc)[:512]}, ensure_ascii=True))
    sys.exit(1)
'@
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-skill-yaml-{0}.py" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $temp -Value $program -Encoding utf8
        $output = & python $temp $Path $script:Limits.MaxYamlDepth $script:Limits.MaxYamlNodes 2>&1
        $exitCode = $LASTEXITCODE
        $payload = ($output | Out-String).Trim() | ConvertFrom-Json -Depth 32
        if ($exitCode -ne 0 -or -not $payload.ok) { throw "Safe YAML parsing failed: $($payload.error)" }
        $payload.value
    }
    finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}

function Get-SkillFrontmatter {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Length -eq 0) { throw 'SKILL.md is empty.' }
    if ($item.Length -gt $script:Limits.MaxSkillFileBytes) { throw 'SKILL.md exceeds the file-size limit.' }
    $lines = Get-Content -LiteralPath $Path
    if ($lines.Count -lt 3 -or $lines[0] -ne '---') { throw 'SKILL.md must begin with YAML frontmatter.' }
    $closing = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -eq '---') { $closing = $i; break } }
    if ($closing -lt 2) { throw 'SKILL.md frontmatter is not closed.' }
    $yamlText = ($lines[1..($closing - 1)] -join "`n")
    if ([Text.Encoding]::UTF8.GetByteCount($yamlText) -gt $script:Limits.MaxMetadataBytes) { throw 'SKILL.md frontmatter exceeds the metadata limit.' }
    $body = if ($closing + 1 -lt $lines.Count) { $lines[($closing + 1)..($lines.Count - 1)] -join "`n" } else { '' }
    [ordered]@{ yaml = $yamlText; body = $body; closingLine = $closing + 1 }
}

function ConvertFrom-SafeYamlText {
    param([Parameter(Mandatory)][string]$Text)
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-skill-frontmatter-{0}.yaml" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $temp -Value $Text -Encoding utf8
        ConvertFrom-SafeYamlFile -Path $temp
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}

function Test-DescriptionContract {
    param([AllowNull()][string]$Description)
    $failures = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($Description)) { $failures.Add('description is required and must be nonempty.'); return @($failures) }
    if ($Description.Length -gt $script:Limits.MaxDescriptionLength) { $failures.Add('description exceeds the length limit.') }
    if ($Description -match '(?i)^\s*(todo|tbd|placeholder|coming soon|future work)\b') { $failures.Add('description must not be placeholder text.') }
    $positiveBoundary = @($Description -split '(?i)\b(do not|don''t|not for|avoid|only when|should not)\b')[0]
    if ($positiveBoundary -notmatch '(?i)\b(use for|invoke|trigger|create|build|validate|review|analy[sz]e|manage)\b') { $failures.Add('description must identify a primary use or trigger boundary.') }
    if ($Description -notmatch '(?i)\b(do not|don''t|not for|avoid|only when|should not)\b') { $failures.Add('description must identify a non-trigger boundary.') }
    @($failures)
}

function Test-UnsafeInstructions {
    param([Parameter(Mandatory)][string]$Text)
    $affirmative = @(
        '(?im)^\s*(?:(?:[-*+]\s+)|(?:\d+[.)]\s+)|(?:>\s*)?)*(ignore|disregard)\s+(the\s+)?(repository\s+)?AGENTS\.md',
        '(?im)^\s*(?:(?:[-*+]\s+)|(?:\d+[.)]\s+)|(?:>\s*)?)*(bypass|disable)\s+(governance|required tests?|testing|TLS|host[- ]key validation|least privilege|WhatIf|confirmation)',
        '(?im)^\s*(?:(?:[-*+]\s+)|(?:\d+[.)]\s+)|(?:>\s*)?)*(fabricate|invent)\s+(evidence|test results?|run metadata)',
        '(?im)^\s*(?:(?:[-*+]\s+)|(?:\d+[.)]\s+)|(?:>\s*)?)*(hardcode|embed|use)\s+(production\s+)?(passwords?|credentials?|secrets?|tokens?)',
        '(?im)^\s*(?:(?:[-*+]\s+)|(?:\d+[.)]\s+)|(?:>\s*)?)*(default|set)\s+.*\b(destructive|production)\b.*\b(execution|mode|credentials?)\b',
        '(?im)^\s*(?:(?:[-*+]\s+)|(?:\d+[.)]\s+)|(?:>\s*)?)*(suppress|ignore)\s+(all\s+)?(errors?|failures?)'
    )
    @($affirmative | Where-Object { $Text -match $_ })
}

function Test-OpenAiMetadata {
    param([string]$Path, [string]$SkillName, [string]$SkillRoot, [string]$RepositoryRoot)
    $results = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $Path)) { return @($results) }
    try { $metadata = ConvertFrom-SafeYamlFile -Path $Path }
    catch { return @(New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message $_.Exception.Message -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName) }
    if (-not (Test-IsYamlMapping $metadata)) {
        return @(New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message 'openai.yaml must contain a mapping.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName)
    }
    $properties = @($metadata.PSObject.Properties | ForEach-Object Name)
    foreach ($unknown in @($properties | Where-Object { $_ -notin @('interface','policy','dependencies') })) {
        $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message "Unsupported openai.yaml property '$unknown'." -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
    }
    foreach ($section in @('interface','policy','dependencies')) {
        if ($properties -contains $section -and (-not (Test-IsYamlMapping $metadata.$section) -or @($metadata.$section.PSObject.Properties).Count -eq 0)) {
            $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message "$section must be a nonempty mapping when declared." -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
        }
    }
    if ($properties -contains 'policy' -and (Test-IsYamlMapping $metadata.policy) -and @($metadata.policy.PSObject.Properties).Count -gt 0) {
        if (@($metadata.policy.PSObject.Properties | ForEach-Object Name) -contains 'allow_implicit_invocation' -and $metadata.policy.allow_implicit_invocation -isnot [bool]) {
            $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message 'policy.allow_implicit_invocation must be Boolean.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
        }
    }
    if ($properties -contains 'interface' -and (Test-IsYamlMapping $metadata.interface) -and @($metadata.interface.PSObject.Properties).Count -gt 0) {
        $interfaceProperties = @($metadata.interface.PSObject.Properties | ForEach-Object Name)
        foreach ($unknown in @($interfaceProperties | Where-Object { $_ -notin @('display_name','short_description','icon_small','icon_large','brand_color','default_prompt') })) {
            $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message "Unsupported interface property '$unknown'." -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
        }
        foreach ($name in @('display_name','short_description','default_prompt','brand_color')) {
            if ($interfaceProperties -contains $name) {
                $value = $metadata.interface.$name
                if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value) -or $value.Length -gt 1024) {
                    $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message "interface.$name must be a bounded nonempty string." -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
                }
            }
        }
        $defaultPrompt = Get-OptionalProperty -InputObject $metadata.interface -Name 'default_prompt'
        if ($defaultPrompt -match '\$([a-z0-9-]+)' -and $Matches[1] -ne $SkillName) {
            $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message 'default_prompt explicitly invokes a different skill.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
        }
        foreach ($icon in @('icon_small','icon_large')) {
            if ($interfaceProperties -contains $icon) {
                try { $resolved = Resolve-BoundedChildPath -Root $SkillRoot -ChildPath ([string]$metadata.interface.$icon); if (-not (Get-Item -LiteralPath $resolved).PSIsContainer) { } else { throw 'Asset path is not a file.' } }
                catch { $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message "interface.$icon is invalid: $($_.Exception.Message)" -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName)) }
            }
        }
    }
    if ($properties -contains 'policy' -and (Test-IsYamlMapping $metadata.policy) -and @($metadata.policy.PSObject.Properties).Count -gt 0) {
        foreach ($unknown in @($metadata.policy.PSObject.Properties | ForEach-Object Name | Where-Object { $_ -ne 'allow_implicit_invocation' })) {
            $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message "Unsupported policy property '$unknown'." -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
        }
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    $implicitMatch = [regex]::Match($raw, '(?im)^\s*allow_implicit_invocation\s*:\s*([^\s#]+)')
    if ($implicitMatch.Success -and $implicitMatch.Groups[1].Value -cnotin @('true','false')) {
        $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message 'policy.allow_implicit_invocation must use the YAML Boolean literal true or false.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
    }
    if ($raw -match '(?i)(password|token|api[_-]?key)\s*:\s*[^\s"'']{8,}' -or $raw -match '(?i)https?://[^\s/@]+:[^\s/@]+@') {
        $results.Add((New-SkillValidationResult -RuleId SKL016 -Status Failed -Severity error -Message 'Metadata contains an obvious embedded credential pattern.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
    }
    if ($properties -contains 'dependencies' -and (Test-IsYamlMapping $metadata.dependencies)) {
        foreach ($unknown in @($metadata.dependencies.PSObject.Properties | ForEach-Object Name | Where-Object { $_ -ne 'tools' })) {
            $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message "Unsupported dependencies property '$unknown'." -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
        }
        $dependencyProperties = @($metadata.dependencies.PSObject.Properties | ForEach-Object Name)
        if ($dependencyProperties -notcontains 'tools' -or @((Get-OptionalProperty $metadata.dependencies 'tools')).Count -eq 0) {
            $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message 'dependencies.tools must be a nonempty sequence.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
        }
        foreach ($tool in @((Get-OptionalProperty $metadata.dependencies 'tools'))) {
            if (-not (Test-IsYamlMapping $tool)) {
                $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message 'Each dependency tool must be a mapping.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName)); continue
            }
            foreach ($unknown in @($tool.PSObject.Properties | ForEach-Object Name | Where-Object { $_ -notin @('type','value','url','description') })) {
                $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message "Unsupported dependency tool property '$unknown'." -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
            }
            $toolType = Get-OptionalProperty -InputObject $tool -Name 'type'
            $toolValue = Get-OptionalProperty -InputObject $tool -Name 'value'
            $toolUrl = Get-OptionalProperty -InputObject $tool -Name 'url'
            if ($toolType -ne 'mcp' -or [string]::IsNullOrWhiteSpace([string]$toolValue) -or ([string]$toolValue).Length -gt 256) {
                $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message 'Each dependency tool must declare type mcp and a bounded value.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
            }
            if ($toolUrl -and ([uri]$toolUrl).Scheme -ne 'https') {
                $results.Add((New-SkillValidationResult -RuleId SKL006 -Status Failed -Severity error -Message 'Dependency URLs must use HTTPS.' -Path (Get-SafeRelativePath $RepositoryRoot $Path) -SkillName $SkillName))
            }
        }
    }
    @($results)
}

function Test-PromptBehaviorCorpus {
    [CmdletBinding()]
    param([string]$RepositoryRoot, [string[]]$SkillNames, [string]$PromptBehaviorPath)
    $results = [System.Collections.Generic.List[object]]::new()
    $requiredCategories = @('explicit-invocation','implicit-invocation','non-trigger-explanation','non-trigger-one-liner','non-trigger-review','ambiguous','governance-bypass','secret-exposure','destructive-default')
    if (-not $PromptBehaviorPath) { $PromptBehaviorPath = Join-Path $RepositoryRoot 'tests/fixtures/codex-skills/prompt-behavior' }
    if (-not (Test-Path -LiteralPath $PromptBehaviorPath -PathType Container)) {
        return @(New-SkillValidationResult -RuleId SKL017 -Status Failed -Severity error -Message 'Prompt-behavior corpus directory is missing.' -Path (Get-SafeRelativePath $RepositoryRoot $PromptBehaviorPath))
    }
    try { $files = @(Get-BoundedTreeFiles -Root $PromptBehaviorPath -MaxFiles $script:Limits.MaxBehaviorCases -MaxFileBytes $script:Limits.MaxMetadataBytes | Where-Object Extension -eq '.json' | Sort-Object Name) }
    catch { return @(New-SkillValidationResult -RuleId SKL019 -Status Failed -Severity error -Message $_.Exception.Message -Path (Get-SafeRelativePath $RepositoryRoot $PromptBehaviorPath)) }
    if ($files.Count -gt $script:Limits.MaxBehaviorCases) { return @(New-SkillValidationResult -RuleId SKL019 -Status Failed -Severity error -Message 'Prompt-behavior case count exceeds the limit.' -Path (Get-SafeRelativePath $RepositoryRoot $PromptBehaviorPath)) }
    $ids = @{}
    $cases = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        try { $case = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 16 }
        catch { $results.Add((New-SkillValidationResult -RuleId SKL017 -Status Failed -Severity error -Message 'Prompt fixture is invalid JSON.' -Path (Get-SafeRelativePath $RepositoryRoot $file.FullName))); continue }
        $required = @('caseId','skillName','category','prompt','expectedSelection','expectedSafetyOutcome','deterministicAssertions','modelEvaluationRequired','rationale')
        if (@($required | Where-Object { $_ -notin $case.PSObject.Properties.Name }).Count -gt 0) { $results.Add((New-SkillValidationResult -RuleId SKL017 -Status Failed -Severity error -Message 'Prompt fixture is missing required properties.' -Path (Get-SafeRelativePath $RepositoryRoot $file.FullName))); continue }
        if ($ids.ContainsKey([string]$case.caseId)) { $results.Add((New-SkillValidationResult -RuleId SKL017 -Status Failed -Severity error -Message 'Prompt case IDs must be unique.' -Path (Get-SafeRelativePath $RepositoryRoot $file.FullName) -SkillName $case.skillName)) } else { $ids[[string]$case.caseId] = $true }
        if ([string]$case.caseId -cnotmatch '^[a-z0-9]+(?:[a-z0-9-]*[a-z0-9])$' -or ([string]$case.caseId).Length -gt 120) { $results.Add((New-SkillValidationResult -RuleId SKL017 -Status Failed -Severity error -Message 'Prompt case ID must be bounded lowercase kebab-case.' -Path (Get-SafeRelativePath $RepositoryRoot $file.FullName) -SkillName $case.skillName)) }
        if ($case.skillName -notin $SkillNames -or $case.category -notin $requiredCategories -or $case.expectedSelection -notin @('Selected','NotSelected','Uncertain') -or $case.expectedSafetyOutcome -notin @('Proceed','Refuse','Clarify','SafeGuidance')) {
            $results.Add((New-SkillValidationResult -RuleId SKL017 -Status Failed -Severity error -Message 'Prompt fixture uses an unknown skill, category, or expectation.' -Path (Get-SafeRelativePath $RepositoryRoot $file.FullName) -SkillName $case.skillName))
        }
        if ([string]::IsNullOrWhiteSpace([string]$case.prompt) -or $case.prompt.Length -gt $script:Limits.MaxPromptLength -or $case.modelEvaluationRequired -isnot [bool] -or @($case.deterministicAssertions).Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$case.rationale) -or ([string]$case.rationale).Length -gt 1024) {
            $results.Add((New-SkillValidationResult -RuleId SKL019 -Status Failed -Severity error -Message 'Prompt fixture violates input bounds or type requirements.' -Path (Get-SafeRelativePath $RepositoryRoot $file.FullName) -SkillName $case.skillName))
        }
        if ($case.category -eq 'explicit-invocation' -and $case.prompt -notmatch ('\$' + [regex]::Escape([string]$case.skillName) + '\b')) {
            $results.Add((New-SkillValidationResult -RuleId SKL017 -Status Failed -Severity error -Message 'Explicit invocation fixture must contain the matching skill invocation.' -Path (Get-SafeRelativePath $RepositoryRoot $file.FullName) -SkillName $case.skillName))
        }
        $cases.Add($case)
        $modelStatus = if ($case.modelEvaluationRequired) { 'NotRun' } else { 'NotApplicable' }
        $modelSeverity = if ($case.modelEvaluationRequired) { 'warning' } else { 'info' }
        $results.Add((New-SkillValidationResult -RuleId SKL018 -Status $modelStatus -Severity $modelSeverity -Message 'Model selection and response behavior were not evaluated by deterministic validation.' -Path (Get-SafeRelativePath $RepositoryRoot $file.FullName) -SkillName $case.skillName -Deterministic $false -RequiredValidation $false -Data ([ordered]@{ caseId=$case.caseId; category=$case.category })))
    }
    foreach ($skill in $SkillNames) {
        foreach ($category in $requiredCategories) {
            if (@($cases | Where-Object { $_.skillName -eq $skill -and $_.category -eq $category }).Count -eq 0) {
                $results.Add((New-SkillValidationResult -RuleId SKL017 -Status Failed -Severity error -Message "Prompt corpus is missing required category '$category'." -Path (Get-SafeRelativePath $RepositoryRoot $PromptBehaviorPath) -SkillName $skill))
            }
        }
    }
    @($results)
}

function Invoke-CodexSkillValidation {
    [CmdletBinding()]
    param(
        [string]$Path = '.',
        [string]$PromptBehaviorPath,
        [ValidateSet('.agents/skills','.agents/suspended-skills')][string]$SkillsRootRelative = '.agents/skills',
        [switch]$SkipPromptBehavior
    )
    $repositoryRoot = (Resolve-Path -LiteralPath $Path).Path
    $skillsRoot = Join-Path $repositoryRoot $SkillsRootRelative
    $results = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $skillsRoot)) {
        $results.Add((New-SkillValidationResult -RuleId SKL001 -Status NotApplicable -Severity info -Message 'No governed skills root exists.' -Path $SkillsRootRelative))
        return New-CodexSkillValidationReport -RepositoryRoot $repositoryRoot -SkillsRoot $skillsRoot -SkillNames @() -Results @($results) -PromptResults @()
    }
    try { Resolve-BoundedChildPath -Root $repositoryRoot -ChildPath $SkillsRootRelative | Out-Null }
    catch { $results.Add((New-SkillValidationResult -RuleId SKL001 -Status Blocked -Severity error -Message $_.Exception.Message -Path $SkillsRootRelative)); return New-CodexSkillValidationReport -RepositoryRoot $repositoryRoot -SkillsRoot $skillsRoot -SkillNames @() -Results @($results) -PromptResults @() }
    $directories = @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force | Sort-Object Name)
    if ($directories.Count -eq 0) {
        $results.Add((New-SkillValidationResult -RuleId SKL001 -Status Failed -Severity error -Message 'An existing skills root must contain one or more governed skill directories.' -Path $SkillsRootRelative))
    }
    if ($directories.Count -gt $script:Limits.MaxSkills) { $results.Add((New-SkillValidationResult -RuleId SKL019 -Status Failed -Severity error -Message 'Skill count exceeds the configured limit.' -Path $SkillsRootRelative)); return New-CodexSkillValidationReport -RepositoryRoot $repositoryRoot -SkillsRoot $skillsRoot -SkillNames @() -Results @($results) -PromptResults @() }
    $skillNames = [System.Collections.Generic.List[string]]::new()
    $declaredNames = @{}
    $plannedSkillNames = @('build-pester-tests','safe-automation','governance-validation','completion-evidence','vendor-documentation-analysis','infrastructure-automation-design')
    foreach ($directory in $directories) {
        $relativeDirectory = Get-SafeRelativePath $repositoryRoot $directory.FullName
        if ($directory.Name -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $directory.LinkType -or ($directory.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            $results.Add((New-SkillValidationResult -RuleId SKL001 -Status Failed -Severity error -Message 'Skill directory must be lowercase kebab-case and must not be linked.' -Path $relativeDirectory -SkillName $directory.Name)); continue
        }
        try { $files = @(Get-BoundedTreeFiles -Root $directory.FullName) }
        catch { $results.Add((New-SkillValidationResult -RuleId SKL019 -Status Failed -Severity error -Message $_.Exception.Message -Path $relativeDirectory -SkillName $directory.Name)); continue }
        $skillFiles = @(Get-ChildItem -LiteralPath $directory.FullName -Force | Where-Object { $_.Name -ceq 'SKILL.md' })
        $caseVariantSkillFiles = @(Get-ChildItem -LiteralPath $directory.FullName -Force | Where-Object { $_.Name -ieq 'SKILL.md' })
        if ($skillFiles.Count -ne 1 -or $caseVariantSkillFiles.Count -ne 1 -or $skillFiles[0].PSIsContainer -or $skillFiles[0].LinkType -or ($skillFiles[0].Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            $rule = if ($directory.Name -in $plannedSkillNames) { 'SKL014' } else { 'SKL002' }
            $results.Add((New-SkillValidationResult -RuleId $rule -Status Failed -Severity error -Message 'Skill directory must contain exactly one regular SKILL.md file; planned skills may not exist as empty active directories.' -Path $relativeDirectory -SkillName $directory.Name)); continue
        }
        try { $frontmatter = Get-SkillFrontmatter -Path $skillFiles[0].FullName; $metadata = ConvertFrom-SafeYamlText -Text $frontmatter.yaml }
        catch { $results.Add((New-SkillValidationResult -RuleId SKL003 -Status Failed -Severity error -Message $_.Exception.Message -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $directory.Name)); continue }
        $name = [string](Get-OptionalProperty -InputObject $metadata -Name 'name')
        if ($name -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $name -cne $directory.Name) { $results.Add((New-SkillValidationResult -RuleId SKL004 -Status Failed -Severity error -Message 'Frontmatter name must be lowercase kebab-case and exactly match the directory.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $directory.Name)) }
        if ($declaredNames.ContainsKey($name)) { $results.Add((New-SkillValidationResult -RuleId SKL013 -Status Failed -Severity error -Message 'Duplicate declared skill name.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) } else { $declaredNames[$name] = $true }
        if ($name) { $skillNames.Add($name) }
        foreach ($failure in @(Test-DescriptionContract -Description ([string](Get-OptionalProperty -InputObject $metadata -Name 'description')))) { $results.Add((New-SkillValidationResult -RuleId SKL005 -Status Failed -Severity error -Message $failure -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) }
        if ($directory.Name -in $plannedSkillNames -and ([string](Get-OptionalProperty -InputObject $metadata -Name 'description')) -match '(?i)\b(todo|tbd|placeholder|coming soon|future work)\b') { $results.Add((New-SkillValidationResult -RuleId SKL014 -Status Failed -Severity error -Message 'Planned skill directory contains placeholder-only implementation.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) }
        foreach ($match in @(Test-UnsafeInstructions -Text $frontmatter.body)) { $results.Add((New-SkillValidationResult -RuleId SKL015 -Status Failed -Severity error -Message 'Skill contains an affirmative policy-weakening instruction.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) }
        if ($frontmatter.body -match '(?i)(password|token|api[_-]?key)\s*[:=]\s*[^\s"'']{8,}' -or $frontmatter.body -match '(?i)https?://[^\s/@]+:[^\s/@]+@') { $results.Add((New-SkillValidationResult -RuleId SKL016 -Status Failed -Severity error -Message 'Skill contains an obvious embedded credential pattern; repository-wide secret scanning remains separate.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) }
        $requiredAuthorities = @('AGENTS.md','agents/AGENTS_Base.md','governance/RISK_CLASSIFICATION.md','governance/COMPLETION_EVIDENCE.md','governance/EXCEPTION_PROCESS.md','governance/AI_GENERATED_CODE_POLICY.md')
        foreach ($authority in $requiredAuthorities) { if ($frontmatter.body -notmatch [regex]::Escape($authority)) { $results.Add((New-SkillValidationResult -RuleId SKL010 -Status Failed -Severity error -Message "Skill does not reference required authority '$authority'." -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) } }
        if ($metadata.PSObject.Properties.Name -contains 'governanceCompatibility') {
            $compatibility = [string]$metadata.governanceCompatibility
            if ($compatibility -notmatch '^\d+\.\d+\.\d+$') { $results.Add((New-SkillValidationResult -RuleId SKL011 -Status Failed -Severity error -Message 'governanceCompatibility must be semantic version syntax.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) }
            else {
                $declaredGovernanceVersion = $null
                $manifestPath = Join-Path $repositoryRoot 'project-manifest.json'
                if (Test-Path -LiteralPath $manifestPath) {
                    try { $declaredGovernanceVersion = (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).governanceVersion }
                    catch { $results.Add((New-SkillValidationResult -RuleId SKL011 -Status Failed -Severity error -Message 'Repository governance version could not be read from project-manifest.json.' -Path (Get-SafeRelativePath $repositoryRoot $manifestPath) -SkillName $name)) }
                }
                if ($declaredGovernanceVersion -and [version]$compatibility -gt [version]$declaredGovernanceVersion) { $results.Add((New-SkillValidationResult -RuleId SKL011 -Status Failed -Severity error -Message 'governanceCompatibility requires a newer governance version than the repository declares.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) }
            }
        }
        if ($metadata.PSObject.Properties.Name -contains 'lifecycle') {
            $lifecycleStatus = [string](Get-OptionalProperty $metadata.lifecycle 'status')
            if (-not (Test-IsYamlMapping $metadata.lifecycle) -or $lifecycleStatus -notin @('active','deprecated')) {
                $results.Add((New-SkillValidationResult -RuleId SKL012 -Status Failed -Severity error -Message 'lifecycle must be a mapping with status active or deprecated.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name))
            }
            elseif ($lifecycleStatus -eq 'deprecated') {
                $migration = Get-OptionalProperty $metadata.lifecycle 'migration'
                $replacement = Get-OptionalProperty $metadata.lifecycle 'replacement'
                $rationale = Get-OptionalProperty $metadata.lifecycle 'indefiniteSupportRationale'
                $removalTarget = Get-OptionalProperty $metadata.lifecycle 'removalTarget'
                $implicitAllowed = Get-OptionalProperty $metadata.lifecycle 'implicitInvocationAllowed'
                if ([string]::IsNullOrWhiteSpace([string]$migration) -or ([string]::IsNullOrWhiteSpace([string]$replacement) -and [string]::IsNullOrWhiteSpace([string]$rationale)) -or ([string]::IsNullOrWhiteSpace([string]$removalTarget) -and [string]::IsNullOrWhiteSpace([string]$rationale)) -or $implicitAllowed -isnot [bool]) {
                    $results.Add((New-SkillValidationResult -RuleId SKL012 -Status Failed -Severity error -Message 'Deprecated skills require migration, replacement or indefinite support rationale, and removal behavior.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name))
                }
            }
        }
        foreach ($optional in @('agents','references','scripts','assets')) {
            $optionalPath = Join-Path $directory.FullName $optional
            if (Test-Path -LiteralPath $optionalPath) {
                try { $optionalFiles = @(Get-BoundedTreeFiles -Root $optionalPath) }
                catch { $results.Add((New-SkillValidationResult -RuleId SKL008 -Status Failed -Severity error -Message "Optional directory '$optional' is unsafe or exceeds bounds: $($_.Exception.Message)" -Path (Get-SafeRelativePath $repositoryRoot $optionalPath) -SkillName $name)); continue }
                if ($optionalFiles.Count -eq 0 -or @($optionalFiles | Where-Object { $_.Length -eq 0 -or $_.Name -eq '.gitkeep' -or (Get-Content -LiteralPath $_.FullName -Raw) -match '(?i)^\s*(todo|tbd|placeholder|coming soon)\s*$' }).Count -gt 0) { $results.Add((New-SkillValidationResult -RuleId SKL008 -Status Failed -Severity error -Message "Optional directory '$optional' is empty or contains placeholder content." -Path (Get-SafeRelativePath $repositoryRoot $optionalPath) -SkillName $name)) }
                if (@(Get-ChildItem -LiteralPath $optionalPath -Recurse -Force | Where-Object { $_.Name -in @('bin','obj','dist','coverage','TestResults','node_modules','__pycache__') }).Count -gt 0) { $results.Add((New-SkillValidationResult -RuleId SKL008 -Status Failed -Severity error -Message "Optional directory '$optional' contains generated output or package-cache content." -Path (Get-SafeRelativePath $repositoryRoot $optionalPath) -SkillName $name)) }
            }
        }
        foreach ($scriptFile in @($files | Where-Object Extension -in @('.ps1','.psm1','.psd1'))) {
            $tokens = $null; $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName,[ref]$tokens,[ref]$errors) | Out-Null
            if (@($errors).Count -gt 0) { $results.Add((New-SkillValidationResult -RuleId SKL009 -Status Failed -Severity error -Message 'Referenced PowerShell script has parser errors; it was not executed.' -Path (Get-SafeRelativePath $repositoryRoot $scriptFile.FullName) -SkillName $name)) }
            elseif ($scriptFile.Extension -in @('.ps1','.psm1')) {
                $scriptText = Get-Content -LiteralPath $scriptFile.FullName -Raw
                if ($scriptText -notmatch '(?s)<#.*?\.SYNOPSIS\b.*?\.DESCRIPTION\b.*?#>') { $results.Add((New-SkillValidationResult -RuleId SKL009 -Status Failed -Severity error -Message 'Skill PowerShell scripts require synopsis and description documentation; the script was not executed.' -Path (Get-SafeRelativePath $repositoryRoot $scriptFile.FullName) -SkillName $name)) }
            }
        }
        $linkMatches = [regex]::Matches($frontmatter.body,'\[[^\]]+\]\(([^)]+)\)')
        if ($linkMatches.Count -gt $script:Limits.MaxReferences) { $results.Add((New-SkillValidationResult -RuleId SKL019 -Status Failed -Severity error -Message 'Reference count exceeds the configured limit.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) }
        foreach ($link in $linkMatches) {
            $target = $link.Groups[1].Value.Split('#')[0]
            if (-not $target -or $target -match '^[a-z]+://') { continue }
            try {
                $resolved = Resolve-BoundedChildPath -Root $directory.FullName -ChildPath $target
                if ((Get-Item -LiteralPath $resolved).PSIsContainer) { throw 'Local reference must identify a file.' }
            }
            catch {
                $allowed = $false
                $candidateFromSkill = [System.IO.Path]::GetFullPath((Join-Path $directory.FullName $target))
                $repositoryRelativeTarget = [System.IO.Path]::GetRelativePath($repositoryRoot, $candidateFromSkill).Replace('\','/')
                foreach ($authorityRoot in @('AGENTS.md','agents','governance','docs')) {
                    try {
                        $authorityTarget = Resolve-BoundedChildPath -Root $repositoryRoot -ChildPath $repositoryRelativeTarget
                        if ((Get-Item -LiteralPath $authorityTarget).PSIsContainer) { throw 'Approved authority reference must identify a file.' }
                        if ($repositoryRelativeTarget -eq $authorityRoot -or $repositoryRelativeTarget.StartsWith("$authorityRoot/",[StringComparison]::Ordinal)) { $allowed = $true }
                    }
                    catch { $allowed = $false }
                }
                if (-not $allowed) { $results.Add((New-SkillValidationResult -RuleId SKL007 -Status Failed -Severity error -Message 'Local reference is missing, absolute, outside approved boundaries, or linked.' -Path (Get-SafeRelativePath $repositoryRoot $skillFiles[0].FullName) -SkillName $name)) }
            }
        }
        foreach ($item in @(Test-OpenAiMetadata -Path (Join-Path $directory.FullName 'agents/openai.yaml') -SkillName $name -SkillRoot $directory.FullName -RepositoryRoot $repositoryRoot)) { $results.Add($item) }
        if (@($results | Where-Object { $_.skillName -eq $name -and $_.status -in @('Failed','Blocked') }).Count -eq 0) { $results.Add((New-SkillValidationResult -RuleId SKL001 -Status Passed -Severity info -Message 'Skill passed deterministic structural validation.' -Path $relativeDirectory -SkillName $name)) }
    }
    [object[]]$promptResults = @()
    if (-not $SkipPromptBehavior) { $promptResults = @(Test-PromptBehaviorCorpus -RepositoryRoot $repositoryRoot -SkillNames @($skillNames) -PromptBehaviorPath $PromptBehaviorPath) }
    New-CodexSkillValidationReport -RepositoryRoot $repositoryRoot -SkillsRoot $skillsRoot -SkillNames @($skillNames) -Results @($results) -PromptResults $promptResults
}

function New-CodexSkillValidationReport {
    param([string]$RepositoryRoot,[string]$SkillsRoot,[string[]]$SkillNames,[object[]]$Results,[object[]]$PromptResults)
    $all = @($Results) + @($PromptResults)
    $requiredFailures = @($all | Where-Object { $_.requiredValidation -and $_.status -in @('Failed','Blocked') })
    [ordered]@{
        schemaVersion = '1.0.0'
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        repositoryRoot = $RepositoryRoot
        skillsRoot = $SkillsRoot
        skillsDiscovered = @($SkillNames | Sort-Object -Unique)
        deterministicStatus = if ($requiredFailures.Count -gt 0) { if (@($requiredFailures | Where-Object status -eq 'Blocked').Count -gt 0) { 'Blocked' } else { 'Failed' } } else { 'Passed' }
        modelEvaluationStatus = if ($SkillNames.Count -eq 0) { 'NotApplicable' } else { 'NotRun' }
        results = @($Results)
        promptBehaviorResults = @($PromptResults)
        failed = @($all | Where-Object status -eq 'Failed').Count
        blocked = @($all | Where-Object status -eq 'Blocked').Count
        notRun = @($all | Where-Object status -eq 'NotRun').Count
        warnings = @($all | Where-Object severity -eq 'warning').Count
    }
}

Export-ModuleMember -Function Invoke-CodexSkillValidation,New-CodexSkillValidationReport,New-SkillValidationResult,Resolve-BoundedChildPath,ConvertFrom-SafeYamlFile,Get-SkillFrontmatter,Test-PromptBehaviorCorpus
