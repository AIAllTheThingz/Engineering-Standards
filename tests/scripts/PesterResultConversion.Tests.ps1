Describe 'Pester result conversion' {
    BeforeAll {
        $script:tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pester-conversion-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:tempRoot -Force | Out-Null
        $script:converter = Resolve-Path "$PSScriptRoot/../../scripts/Convert-PesterResultToSanitizedJson.ps1"
    }

    AfterAll {
        if ($script:tempRoot -and (Test-Path -LiteralPath $script:tempRoot)) {
            Remove-Item -LiteralPath $script:tempRoot -Recurse -Force
        }
    }

    It 'converts passing, failing, and skipped tests while sanitizing paths and secret-like output' {
        $secretLine = ('tok' + 'en') + ' = super-secret-value'
        $xml = @'
<test-results>
  <test-suite>
    <results>
      <test-case name="Outer.Context.passes" result="Success" time="0.1" />
      <test-case name="Outer.Context.fails" result="Failure" time="0.2">
        <failure>
          <message>Failed at C:\Users\Name\repo\tests\Test.ps1 with __SECRET_LINE__</message>
          <stack-trace>at /home/runner/work/Engineering-Standards/Engineering-Standards/tests/Test.ps1:10</stack-trace>
        </failure>
      </test-case>
      <test-case name="Outer.Context.skips" result="Skipped" time="0" />
    </results>
  </test-suite>
</test-results>
'@
        $xml = $xml.Replace('__SECRET_LINE__', $secretLine)
        New-Item -ItemType Directory -Path (Join-Path $script:tempRoot '.tmp'),(Join-Path $script:tempRoot 'evidence') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:tempRoot '.tmp/pester.xml') -Value $xml
        & pwsh -NoProfile -File $script:converter -RepositoryPath $script:tempRoot -InputPath '.tmp/pester.xml' -OutputPath 'evidence/pester-details.json'
        $LASTEXITCODE | Should -Be 0
        $result = Get-Content -LiteralPath (Join-Path $script:tempRoot 'evidence/pester-details.json') -Raw | ConvertFrom-Json
        $result.total | Should -Be 3
        ($result | ConvertTo-Json -Depth 20) | Should -Not -Match 'C:\\Users'
        ($result | ConvertTo-Json -Depth 20) | Should -Not -Match '/home/runner'
        ($result | ConvertTo-Json -Depth 20) | Should -Not -Match 'super-secret-value'
    }

    It 'fails missing and malformed XML' {
        & pwsh -NoProfile -File $script:converter -RepositoryPath $script:tempRoot -InputPath '.tmp/missing.xml' -OutputPath 'evidence/out.json' 2>$null
        $LASTEXITCODE | Should -Not -Be 0
        New-Item -ItemType Directory -Path (Join-Path $script:tempRoot '.tmp') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:tempRoot '.tmp/bad.xml') -Value '<not-closed>'
        & pwsh -NoProfile -File $script:converter -RepositoryPath $script:tempRoot -InputPath '.tmp/bad.xml' -OutputPath 'evidence/out.json' 2>$null
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'allows an isolated evidence root without widening repository access' {
        $repositoryRoot = Join-Path $script:tempRoot 'repository'
        $evidenceRoot = Join-Path $script:tempRoot 'external-evidence'
        New-Item -ItemType Directory -Path $repositoryRoot,$evidenceRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $evidenceRoot 'pester.xml') -Value '<test-results><test-suite><results><test-case name="Outer.passes" result="Success" time="0.1" /></results></test-suite></test-results>'

        & pwsh -NoProfile -File $script:converter -RepositoryPath $repositoryRoot -EvidenceRoot $evidenceRoot -InputPath (Join-Path $evidenceRoot 'pester.xml') -OutputPath (Join-Path $evidenceRoot 'pester-details.json')
        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath (Join-Path $evidenceRoot 'pester-details.json') -PathType Leaf | Should -BeTrue

        & pwsh -NoProfile -File $script:converter -RepositoryPath $repositoryRoot -EvidenceRoot $evidenceRoot -InputPath (Join-Path $evidenceRoot 'pester.xml') -OutputPath (Join-Path $repositoryRoot 'outside.json') 2>$null
        $LASTEXITCODE | Should -Not -Be 0
    }
}
