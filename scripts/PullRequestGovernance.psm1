Set-StrictMode -Version Latest

$script:RequiredHeadings = @('Summary','Change Type','Risk Classification','Security Impact','Data Impact','Testing Performed','Tests Not Performed','Evidence','Rollback Plan','Governance Exceptions')
$script:ChangeTypes = @('Documentation-only','Patch fix','Backward-compatible governance addition','Breaking governance change','Security fix','Emergency change')
$script:Messages = @{
    PRG001='Include exactly one occurrence of every required governance heading.'; PRG002='Replace empty, placeholder, or untouched template content with substantive governance information.'
    PRG003='Select exactly one canonical change type and include each option once.'; PRG004='Provide exactly one canonical risk value and a substantive rationale.'
    PRG005='Provide a substantive security-impact assessment; None requires explicit review and no security-sensitive changed paths.'; PRG006='Record classification, privacy, logging, retention, and production/customer-data impact with reasons.'
    PRG007='Record testing performed with command or validation name, working directory, outcome, and limitations.'; PRG008='Use NotRun, Blocked, or NotApplicable for omitted tests and provide a reason.'
    PRG009='Provide at least one concrete evidence reference and any required reason.'; PRG010='Provide a substantive rollback or recovery plan appropriate to the selected change type.'
    PRG011='Declare None or valid active GOV-* exceptions that map to the affected controls.'; PRG012='Replace noncanonical governance status aliases with Passed, Failed, NotRun, Blocked, or NotApplicable.'
    PRG013='Security impact cannot be None because security-sensitive changed-path categories were detected.'; PRG014='Documentation-only conflicts with non-documentation changed-path categories.'
    PRG015='Automation actors must provide the same complete canonical governance record as human actors.'; PRG016='Pull-request metadata is missing, invalid, oversized, or incomplete; validation cannot pass.'
}

function New-PrFinding {
    param([string]$RuleId,[string]$Section,[string]$Status='Failed',[object]$Data=$null)
    [ordered]@{ ruleId=$RuleId; status=$Status; severity='error'; section=$Section; message="$RuleId`: $($script:Messages[$RuleId])"; data=$Data }
}

function ConvertFrom-PrBodySections {
    param([string]$Body)
    $sections=@{}; $counts=@{}; $current=$null; $inFence=$false; $inComment=$false
    foreach($line in [regex]::Split($Body,"\r?\n")) {
        $remaining=$line
        if($inComment){ if($remaining -match '-->'){ $remaining=$remaining.Substring($remaining.IndexOf('-->')+3); $inComment=$false } else { continue } }
        while($remaining -match '<!--'){
            $start=$remaining.IndexOf('<!--'); $end=$remaining.IndexOf('-->',$start+4)
            if($end -lt 0){ $remaining=$remaining.Substring(0,$start); $inComment=$true; break }
            $remaining=$remaining.Remove($start,$end+3-$start)
        }
        if($remaining -match '^\s*(```|~~~)'){ $inFence=-not $inFence; continue }
        if($inFence -or $remaining -match '^\s*>'){ continue }
        if($remaining -match '^##\s+(.+?)\s*$'){
            $heading=$Matches[1]
            if($heading -in $script:RequiredHeadings){
                if(-not $counts.ContainsKey($heading)){$counts[$heading]=0}; $counts[$heading]++
                if(-not $sections.ContainsKey($heading)){$sections[$heading]=[System.Collections.Generic.List[string]]::new()}
                $current=$heading
            } else { $current=$null }
            continue
        }
        if($current){$sections[$current].Add($remaining)}
    }
    [pscustomobject]@{Sections=$sections;Counts=$counts}
}

function Get-PrPathCategories {
    param([string[]]$ChangedFiles)
    $security=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase); $nonDocs=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($raw in $ChangedFiles){
        $path=([string]$raw).Replace('\','/')
        $category=$null
        if($path -match '^\.github/workflows/'){$category='workflow'} elseif($path -match '^actions/'){$category='action'} elseif($path -match '^scripts/'){$category='operational-script'} elseif($path -match '^governance/'){$category='governance-policy'} elseif($path -match '^schemas/'){$category='schema'} elseif($path -match '(^|/)(SECURITY\.md|CODEOWNERS)$'){$category='security-ownership'} elseif($path -match '(^|/)(governance\.config\.json|project-manifest\.json)$'){$category='governance-configuration'} elseif($path -match '(auth|secret|depend|scanner|infrastructure|terraform|docker|kubernetes|\.csproj$|\.sln$|package-lock\.json$)'){$category='security-or-build-definition'}
        if($category){$null=$security.Add($category);$null=$nonDocs.Add($category)}
        if($path -match '\.(ps1|psm1|psd1|cs|fs|vb|js|jsx|ts|tsx|py|sh|sql)$' -or $path -match '\.(csproj|fsproj|vbproj|sln|props|targets)$'){$null=$nonDocs.Add('executable-or-build')}
        if($path -match '\.(ya?ml)$' -and $path -match '(^\.github/workflows/|^actions/)'){$null=$nonDocs.Add('workflow-or-action')}
    }
    [pscustomobject]@{Security=@($security);NonDocumentation=@($nonDocs)}
}

function Test-PullRequestGovernanceRecord {
    <#.SYNOPSIS Validates a pull-request governance record without executing untrusted input. #>
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Body,[AllowNull()][string[]]$ChangedFiles,[AllowNull()][string]$Actor,[AllowNull()][string]$Repository,
        [int]$PullRequestNumber,[AllowNull()]$GovernanceConfig,[bool]$ChangedFilesComplete=$true
    )
    $findings=[System.Collections.Generic.List[object]]::new(); $bodyHash=$null
    if($null -ne $Body){$bodyHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Body))).ToLowerInvariant()}
    if([string]::IsNullOrWhiteSpace($Body) -or $Body.Length -gt 65536 -or [string]::IsNullOrWhiteSpace($Actor) -or $Repository -notmatch '^[^/\s]+/[^/\s]+$' -or $PullRequestNumber -lt 1 -or $null -eq $ChangedFiles -or -not $ChangedFilesComplete){
        $status=if(-not $ChangedFilesComplete -or $null -eq $ChangedFiles){'Blocked'}else{'Failed'}
        $findings.Add((New-PrFinding PRG016 InputIntegrity $status ([ordered]@{changedFilesComplete=$ChangedFilesComplete})))
        return [ordered]@{schemaVersion='1.0.0';status=$status;repository=$Repository;pullRequestNumber=$PullRequestNumber;actor=$Actor;bodySha256=$bodyHash;findings=@($findings);changedPathCategories=@()}
    }
    $parsed=ConvertFrom-PrBodySections $Body
    foreach($heading in $script:RequiredHeadings){if(-not $parsed.Counts.ContainsKey($heading) -or $parsed.Counts[$heading] -ne 1){$findings.Add((New-PrFinding PRG001 $heading))}}
    $content=@{}; foreach($heading in $script:RequiredHeadings){$content[$heading]=if($parsed.Sections.ContainsKey($heading)){($parsed.Sections[$heading] -join "`n").Trim()}else{''}}
    $placeholder='(?im)(?<![\p{L}\p{N}])(TODO|TBD|Placeholder|Describe what changed(?: and why it is needed)?|State\s+`?Low`?,?\s*`?Moderate`?,?\s*`?High`?,?\s*(?:or\s*)?`?Critical`?)(?![\p{L}\p{N}])'
    if(@($content.Values | Where-Object {[string]::IsNullOrWhiteSpace($_) -or $_ -match $placeholder}).Count -gt 0){$findings.Add((New-PrFinding PRG002 Template))}
    $change=$content['Change Type']; $optionLines=@($change -split "`n" | Where-Object {$_ -match '^\s*-\s*\[([ xX])\]\s*(.+?)\s*$'})
    $names=@($optionLines | ForEach-Object {if($_ -match '^\s*-\s*\[([ xX])\]\s*(.+?)\s*$'){$Matches[2]}}); $checked=@($optionLines | Where-Object {$_ -match '^\s*-\s*\[[xX]\]'}); $unknown=@($names|Where-Object{$_ -notin $script:ChangeTypes}); $duplicates=@($names|Group-Object|Where-Object Count -gt 1)
    if($checked.Count -ne 1 -or $unknown.Count -gt 0 -or $duplicates.Count -gt 0){$findings.Add((New-PrFinding PRG003 'Change Type'))}
    $selected=if($checked.Count -eq 1 -and $checked[0] -match '^\s*-\s*\[[xX]\]\s*(.+?)\s*$'){$Matches[1]}else{''}
    $risk=$content['Risk Classification']; if($risk -notmatch '(?m)^Risk:\s*(Low|Moderate|High|Critical)\s*$' -or $risk -notmatch '(?m)^Rationale:\s*\S.{9,}$'){$findings.Add((New-PrFinding PRG004 'Risk Classification'))}
    $categories=Get-PrPathCategories $ChangedFiles; $security=$content['Security Impact']; $securityNone=$security -match '(?im)^Status:\s*None\s*$'
    if($security -notmatch '(?im)^Status:\s*(Reviewed|None)\s*$' -or $security -notmatch '(?im)^Details:\s*\S.{9,}$' -or ($securityNone -and $security -notmatch '(?i)review')){$findings.Add((New-PrFinding PRG005 'Security Impact'))}
    if($securityNone -and $categories.Security.Count -gt 0){$findings.Add((New-PrFinding -RuleId PRG013 -Section 'Security Impact' -Data ([ordered]@{categories=$categories.Security})))}
    $data=$content['Data Impact']; $dataFields=@('Classification','Privacy','Logging','Retention','Production or customer data'); if(@($dataFields|Where-Object{$data -notmatch "(?im)^$([regex]::Escape($_)):\s*\S"}).Count -gt 0){$findings.Add((New-PrFinding PRG006 'Data Impact'))}
    $testing=$content['Testing Performed']; if($testing -notmatch '(?im)^(Command|Validation):\s*\S' -or $testing -notmatch '(?im)^Working directory:\s*\S' -or $testing -notmatch '(?im)^(Exit code|Outcome):\s*\S' -or $testing -notmatch '(?im)^(Warning|Limitation):\s*\S'){$findings.Add((New-PrFinding PRG007 'Testing Performed'))}
    $notPerformed=$content['Tests Not Performed']; if($notPerformed -notmatch '(?im)^Status:\s*(NotRun|Blocked|NotApplicable)\s*$' -or $notPerformed -notmatch '(?im)^Reason:\s*\S.{9,}$'){$findings.Add((New-PrFinding PRG008 'Tests Not Performed'))}
    if($notPerformed -match '(?im)^Status:\s*(Skipped|Success|N/A)\s*$' -or $testing -match '(?im)^Outcome:\s*(Skipped|Success|N/A)\s*$'){$findings.Add((New-PrFinding PRG012 Status))}
    $evidence=$content['Evidence']; if($evidence -notmatch '(?im)(Path:\s*[\w./-]+|Run(?: ID)?:\s*\d+|Artifact(?: ID)?:\s*[\w.-]+|Commit(?: SHA)?:\s*[0-9a-f]{7,40}|Review:\s*\S|Screenshot:\s*\S)'){$findings.Add((New-PrFinding PRG009 Evidence))}
    $rollback=$content['Rollback Plan']; if($selected -eq 'Documentation-only'){if($rollback -notmatch '(?i)(revert|restore).{10,}' -or $rollback -notmatch '(?i)(verify|validation)'){$findings.Add((New-PrFinding PRG010 'Rollback Plan'))}}else{$rollbackFields=@('Revert target','Preconditions','Execution steps','Verification','Irreversible effects','Authorized owner');if(@($rollbackFields|Where-Object{$rollback -notmatch "(?im)^$([regex]::Escape($_)):\s*\S"}).Count -gt 0){$findings.Add((New-PrFinding PRG010 'Rollback Plan'))}}
    $exceptionText=$content['Governance Exceptions'].Trim(); if($exceptionText -ne 'None'){
        $ids=@([regex]::Matches($exceptionText,'(?<![\p{L}\p{N}-])GOV-[0-9]{4}-[0-9]{3,}(?![\p{L}\p{N}-])')|ForEach-Object Value)
        $configured=@(); if($GovernanceConfig -and $GovernanceConfig.PSObject.Properties.Name -contains 'exceptions'){$configured=@($GovernanceConfig.exceptions|ForEach-Object{if($_ -is [string]){$_}elseif($_.PSObject.Properties.Name -contains 'id'){$_.id}})}
        if($ids.Count -eq 0 -or @($ids|Where-Object{$_ -notin $configured}).Count -gt 0){$findings.Add((New-PrFinding PRG011 'Governance Exceptions'))}
    }
    if($selected -eq 'Documentation-only' -and $categories.NonDocumentation.Count -gt 0){$findings.Add((New-PrFinding -RuleId PRG014 -Section 'Change Type' -Data ([ordered]@{categories=$categories.NonDocumentation})))}
    if($Actor -match '(?i)(\[bot\]$|dependabot|automation)' -and $findings.Count -gt 0){$findings.Add((New-PrFinding PRG015 Automation))}
    [ordered]@{schemaVersion='1.0.0';status=$(if($findings.Count){if(@($findings|Where-Object status -eq Blocked).Count){'Blocked'}else{'Failed'}}else{'Passed'});repository=$Repository;pullRequestNumber=$PullRequestNumber;actor=$Actor;bodySha256=$bodyHash;findings=@($findings);changedPathCategories=@($categories.Security+$categories.NonDocumentation|Sort-Object -Unique)}
}

Export-ModuleMember -Function Test-PullRequestGovernanceRecord
