BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../scripts/PullRequestGovernance.psm1') -Force
    $root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $valid=Get-Content -LiteralPath (Join-Path $root 'tests/fixtures/pr-governance/valid/compliant-high-risk.md') -Raw
    $documentationOnly=Get-Content -LiteralPath (Join-Path $root 'tests/fixtures/pr-governance/valid/compliant-documentation-only.md') -Raw
    $config=Get-Content -LiteralPath (Join-Path $root 'governance.config.json') -Raw|ConvertFrom-Json
    function Invoke-Record([AllowNull()][string]$Body=$valid,[string[]]$Files=@('scripts/test.ps1'),[string]$Actor='test-user',[bool]$Complete=$true){
        Test-PullRequestGovernanceRecord -Body $Body -ChangedFiles $Files -Actor $Actor -Repository 'AIAllTheThingz/Engineering-Standards' -PullRequestNumber 999 -GovernanceConfig $config -ChangedFilesComplete $Complete
    }
    function Get-RuleIds($Result){
        @($Result.findings | ForEach-Object { $_['ruleId'] })
    }
}
Describe 'Pull request governance parser' {
    It 'passes a compliant high-risk record and does not copy the body to output' { $r=Invoke-Record; $r.status|Should -Be Passed; ($r|ConvertTo-Json -Depth 8)|Should -Not -Match ([regex]::Escape($valid)) }
    It 'fails the historical PR 12 body with stable rule IDs' { $body=Get-Content -LiteralPath (Join-Path $root 'tests/fixtures/pr-governance/invalid/pr-12-untouched-template.md') -Raw;$r=Invoke-Record $body @('README.md');$r.status|Should -Be Failed; $r.findings.ruleId|Should -Contain PRG002;$r.findings.ruleId|Should -Contain PRG003;$r.findings.ruleId|Should -Contain PRG004 }
    It 'fails null and empty bodies safely' { (Invoke-Record $null).findings.ruleId|Should -Contain PRG016;(Invoke-Record '').findings.ruleId|Should -Contain PRG016 }
    It 'blocks incomplete changed-file metadata' { (Invoke-Record $valid @('scripts/test.ps1') 'test-user' $false).status|Should -Be Blocked }
    It 'ignores required headings in fences and block quotes' { $body=$valid -replace '## Evidence','```text`n## Evidence`n```';(Invoke-Record $body).findings.ruleId|Should -Contain PRG001;$body=$valid -replace '## Evidence','> ## Evidence';(Invoke-Record $body).findings.ruleId|Should -Contain PRG001 }
    It 'rejects duplicate headings' { (Invoke-Record ($valid+"`n## Summary`nagain")).findings.ruleId|Should -Contain PRG001 }
    It 'accepts LF and CRLF' { (Invoke-Record ($valid -replace "`r`n","`n")).status|Should -Be Passed;(Invoke-Record (($valid -replace "`r?`n","`n") -replace "`n","`r`n")).status|Should -Be Passed }
    It 'detects security and documentation contradictions' { $none=$valid -replace 'Status: Reviewed','Status: None';(Invoke-Record $none).findings.ruleId|Should -Contain PRG013;$doc=Get-Content -LiteralPath (Join-Path $root 'tests/fixtures/pr-governance/valid/compliant-documentation-only.md') -Raw;(Invoke-Record $doc @('scripts/run.ps1')).findings.ruleId|Should -Contain PRG014 }
    It 'does not execute body or filename text' { $marker=Join-Path $TestDrive 'executed';$body=$valid -replace 'Adds deterministic',"`$(New-Item -ItemType File -Path '$marker') Adds deterministic";$null=Invoke-Record $body @("`$(New-Item -ItemType File -Path '$marker')");Test-Path $marker|Should -BeFalse }
    It 'does not bypass incomplete automation records' { $r=Invoke-Record 'incomplete' @('README.md') 'dependabot[bot]';$r.findings.ruleId|Should -Contain PRG015 }
    It 'applies only a configured exception mapped to the affected control' { $body=$valid -replace 'Risk: High','Risk: Invalid' -replace 'None\s*$','GOV-2026-999';$exceptionConfig=[pscustomobject]@{exceptions=@('GOV-2026-999');controls=[pscustomobject]@{mandatoryControlsDisabled=@([pscustomobject]@{control='pull-request-risk';exceptionReference='GOV-2026-999'})}};$r=Test-PullRequestGovernanceRecord -Body $body -ChangedFiles @('scripts/test.ps1') -Actor test-user -Repository 'AIAllTheThingz/Engineering-Standards' -PullRequestNumber 999 -GovernanceConfig $exceptionConfig;$ruleIds=Get-RuleIds $r;$ruleIds|Should -Not -Contain PRG004;$ruleIds|Should -Not -Contain PRG011 }
    It 'rejects oversized bodies and avoids placeholder substring false positives' { Get-RuleIds (Invoke-Record ('a'*65537))|Should -Contain PRG016;$body=$valid -replace 'Adds deterministic','The todoist integration adds deterministic';Get-RuleIds (Invoke-Record $body)|Should -Not -Contain PRG002 }
    It 'classifies root package.json for security and documentation contradictions' {
        $none=$valid -replace 'Status: Reviewed','Status: None' -replace 'Details: The workflow','Details: The reviewed workflow'
        Get-RuleIds (Invoke-Record $none @('package.json'))|Should -Contain PRG013
        Get-RuleIds (Invoke-Record $documentationOnly @('package.json'))|Should -Contain PRG014
    }
    It 'classifies nested package.json for both frozen rule-matrix categories' {
        $none=$valid -replace 'Status: Reviewed','Status: None' -replace 'Details: The workflow','Details: The reviewed workflow'
        $securityResult=Invoke-Record $none @('examples/web-project/package.json')
        $documentationResult=Invoke-Record $documentationOnly @('examples/web-project/package.json')
        $securityResult.changedPathCategories|Should -Contain 'security-or-build-definition'
        Get-RuleIds $securityResult|Should -Contain PRG013
        Get-RuleIds $documentationResult|Should -Contain PRG014
    }
    It 'preserves root and nested package-lock.json classification' {
        foreach($path in @('package-lock.json','examples/web-project/package-lock.json')){
            $none=$valid -replace 'Status: Reviewed','Status: None' -replace 'Details: The workflow','Details: The reviewed workflow'
            $result=Invoke-Record $none @($path)
            $result.changedPathCategories|Should -Contain 'security-or-build-definition'
            Get-RuleIds $result|Should -Contain PRG013
            Get-RuleIds (Invoke-Record $documentationOnly @($path))|Should -Contain PRG014
        }
    }
    It 'does not classify package-manifest near misses as build definitions' {
        $nearMisses=@('package.json.md','package-json-notes.md','mypackage.json.txt','package.json.backup','package-lock.json.md')
        $none=$valid -replace 'Status: Reviewed','Status: None' -replace 'Details: The workflow','Details: The reviewed workflow'
        $securityResult=Invoke-Record $none $nearMisses
        $documentationResult=Invoke-Record $documentationOnly $nearMisses
        $securityResult.changedPathCategories|Should -Not -Contain 'security-or-build-definition'
        Get-RuleIds $securityResult|Should -Not -Contain PRG013
        Get-RuleIds $documentationResult|Should -Not -Contain PRG014
    }
}
