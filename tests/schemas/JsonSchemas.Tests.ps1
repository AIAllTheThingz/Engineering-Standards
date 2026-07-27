Describe 'JSON schema validation' {
    Context 'fixtures' {
        It 'accepts valid fixtures and rejects invalid fixtures' {
            & pwsh -NoProfile -File "$PSScriptRoot/../../scripts/Test-JsonSchemas.ps1" -Path "$PSScriptRoot/../.."
            $LASTEXITCODE | Should -Be 0
        }

        It 'enforces project owner placeholders directly in JSON Schema' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/project-manifest.schema.json"
            foreach ($fixture in Get-ChildItem "$PSScriptRoot/../fixtures/invalid" -Filter 'project-manifest*placeholder*.json') {
                (Get-Content -LiteralPath $fixture.FullName -Raw | Test-Json -SchemaFile $schema) | Should -BeFalse -Because $fixture.Name
            }
            foreach ($name in @('project-manifest-one-character-user-owner.json', 'project-manifest-user-owner.json', 'project-manifest.json', 'project-manifest-contact-owner.json', 'project-manifest-similar-email-owner.json', 'project-manifest-similar-user-owner.json', 'project-manifest-similar-team-owner.json')) {
                (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/$name" -Raw | Test-Json -SchemaFile $schema) | Should -BeTrue -Because $name
            }
            (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/invalid/project-manifest-bare-user-owner.json" -Raw | Test-Json -SchemaFile $schema) | Should -BeFalse
        }

        It 'enforces required CODEOWNERS path structure directly in JSON Schema' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/governance-config.schema.json"
            (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/governance-config-required-codeowner-paths.json" -Raw | Test-Json -SchemaFile $schema) | Should -BeTrue
            foreach ($fixture in Get-ChildItem "$PSScriptRoot/../fixtures/invalid" -Filter 'governance-config-codeowner-*.json') {
                (Get-Content -LiteralPath $fixture.FullName -Raw | Test-Json -SchemaFile $schema) | Should -BeFalse -Because $fixture.Name
            }
        }

        It 'accepts current structured owner and workflow contracts directly in JSON Schema' {
            $manifestSchema = Resolve-Path "$PSScriptRoot/../../schemas/project-manifest.schema.json"
            $configSchema = Resolve-Path "$PSScriptRoot/../../schemas/governance-config.schema.json"
            foreach ($name in @('project-manifest-1.2.0-user.json','project-manifest-1.2.0-team.json')) {
                (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/$name" -Raw | Test-Json -SchemaFile $manifestSchema) | Should -BeTrue -Because $name
            }
            (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/governance-config-1.2.0.json" -Raw | Test-Json -SchemaFile $configSchema) | Should -BeTrue
        }

        It 'accepts Python and Bash project types and rejects unsupported values' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/project-manifest.schema.json"
            foreach ($name in @('project-manifest-1.2.0-python.json','project-manifest-1.2.0-bash.json')) {
                (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/$name" -Raw | Test-Json -SchemaFile $schema) | Should -BeTrue -Because $name
            }
            $unsupported = Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/project-manifest-1.2.0-python.json" -Raw | ConvertFrom-Json
            $unsupported.projectType = 'python-script'
            ($unsupported | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeFalse
            (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/invalid/project-manifest-unsupported-project-type.json" -Raw | Test-Json -SchemaFile $schema) | Should -BeFalse
        }

        It 'enforces the release lifecycle structure directly in JSON Schema' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/release-lifecycle.schema.json"
            (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/release-lifecycle/valid/full-lifecycle.json" -Raw | Test-Json -SchemaFile $schema) | Should -BeTrue
            (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/release-lifecycle/invalid/missing-canary.json" -Raw | Test-Json -SchemaFile $schema) | Should -BeFalse
        }

        It 'accepts the owned downstream compatibility matrix directly in JSON Schema' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/downstream-compatibility.schema.json"
            (Get-Content -LiteralPath "$PSScriptRoot/../../governance/downstream-compatibility.json" -Raw | Test-Json -SchemaFile $schema) | Should -BeTrue
        }

        It 'accepts legacy compatibility records and rejects version-shape mismatches' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/downstream-compatibility.schema.json"
            $owned = Get-Content -LiteralPath "$PSScriptRoot/../../governance/downstream-compatibility.json" -Raw | ConvertFrom-Json

            $legacy = $owned | ConvertTo-Json -Depth 30 | ConvertFrom-Json
            $legacy.schemaVersion = '1.0.0'
            $legacy.unreleasedContract.PSObject.Properties.Remove('functionalWorkflows')
            ($legacy | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeTrue

            $mislabeled = $owned | ConvertTo-Json -Depth 30 | ConvertFrom-Json
            $mislabeled.schemaVersion = '1.0.0'
            ($mislabeled | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeFalse

            $incompleteCurrent = $owned | ConvertTo-Json -Depth 30 | ConvertFrom-Json
            $incompleteCurrent.unreleasedContract.PSObject.Properties.Remove('functionalWorkflows')
            ($incompleteCurrent | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeFalse
        }

        It 'accepts GitHub-valid verified-run branches and rejects reserved or malformed names' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/verified-run.schema.json"
            $source = Get-Content -LiteralPath "$PSScriptRoot/../../evidence/latest-verified-run.json" -Raw | ConvertFrom-Json
            $unicodeBranch = (('😀' * 50) + '/' + ('😀' * 50) + '/' + ('😀' * 50))
            $longBranch = (('a' * 100) + '/' + ('b' * 100) + '/' + ('c' * 95) + '@corp')
            foreach ($branch in @('master','agent/version-consolidation-contracts','release/v1.2.0','_feature','feature@corp',$unicodeBranch,$longBranch)) {
                $record = $source | ConvertTo-Json -Depth 30 | ConvertFrom-Json
                $record.branch = $branch
                ($record | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeTrue -Because $branch
            }
            foreach ($branch in @('HEAD','refs/heads/main','agent//double','agent/bad..name','agent/.hidden','agent/name.lock','agent/name.','bad branch')) {
                $record = $source | ConvertTo-Json -Depth 30 | ConvertFrom-Json
                $record.branch = $branch
                ($record | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeFalse -Because $branch
            }
        }

        It 'accepts legacy and current standards consistency shapes by declared version' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/standards-consistency.schema.json"
            $owned = Get-Content -LiteralPath "$PSScriptRoot/../../governance/standards-consistency.json" -Raw | ConvertFrom-Json
            (Get-Content -LiteralPath "$PSScriptRoot/../../governance/standards-consistency.json" -Raw | Test-Json -SchemaFile $schema) | Should -BeTrue

            $legacy = $owned | ConvertTo-Json -Depth 30 | ConvertFrom-Json
            $legacy.schemaVersion = '1.0.0'
            $legacy.PSObject.Properties.Remove('publishedRelease')
            $legacy.PSObject.Properties.Remove('nextReleaseReadiness')
            $legacy.releaseReadiness = [pscustomobject]@{
                status = 'NotRun'
                proposedVersion = '1.1.0'
                proposedTag = 'v1.1.0'
                targetCommitSha = '2704049d7e826975d956611b194214dd79ea3686'
                releaseCreated = $true
                reason = 'Synthetic legacy contract fixture.'
            }
            ($legacy | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeTrue

            $hybrid = $owned | ConvertTo-Json -Depth 30 | ConvertFrom-Json
            $hybrid.schemaVersion = '1.0.0'
            ($hybrid | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeFalse
        }

        It 'rejects a null workflow interface version for a 1.2.0 manifest' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/project-manifest.schema.json"
            $manifest = Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/project-manifest-1.2.0-user.json" -Raw | ConvertFrom-Json
            $manifest.workflowInterfaceVersion = $null
            ($manifest | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $schema) | Should -BeFalse
        }

        It 'uses only the controlled schema identifier namespace' {
            foreach ($schemaFile in Get-ChildItem "$PSScriptRoot/../../schemas" -Filter '*.schema.json') {
                $schema = Get-Content -LiteralPath $schemaFile.FullName -Raw | ConvertFrom-Json
                $schema.'$id' | Should -Match '^urn:aiallthethingz:engineering-standards:schema:[a-z0-9-]+$' -Because $schemaFile.Name
            }
        }

        It 'uses controlled sibling schema identifiers for completion evidence references' {
            $schema = Get-Content -LiteralPath "$PSScriptRoot/../../schemas/completion-result.schema.json" -Raw | ConvertFrom-Json
            $schema.properties.tests.items.'$ref' | Should -BeExactly 'urn:aiallthethingz:engineering-standards:schema:test-evidence'
            $schema.properties.artifacts.items.'$ref' | Should -BeExactly 'urn:aiallthethingz:engineering-standards:schema:artifact-record'
        }

        It 'declares the exact supported schema versions for each governance document kind' {
            $expectedVersions = [ordered]@{
                'completion-result' = @('1.0.0', '1.1.0')
                'test-evidence' = @('1.0.0', '1.1.0')
                'artifact-record' = @('1.0.0', '1.1.0')
                'project-manifest' = @('1.0.0', '1.1.0', '1.2.0')
                'governance-config' = @('1.0.0', '1.1.0', '1.2.0')
                'verified-run' = @('1.0.0')
                'standards-consistency' = @('1.0.0', '1.1.0')
            }

            foreach ($kind in $expectedVersions.Keys) {
                $schema = Get-Content "$PSScriptRoot/../../schemas/$kind.schema.json" -Raw | ConvertFrom-Json
                $declaration = $schema.properties.schemaVersion
                if ($declaration.PSObject.Properties.Name -contains 'enum') {
                    @($declaration.enum) | Should -BeExactly $expectedVersions[$kind] -Because "$kind schemaVersion enum is part of the validation contract"
                }
                else {
                    $declaration.pattern | Should -BeExactly '^1\.0\.0$' -Because "$kind must use an exact anchored schemaVersion pattern"
                    $expectedVersions[$kind] | Should -BeExactly @('1.0.0')
                }
            }

            $compatibility = Get-Content "$PSScriptRoot/../../schemas/downstream-compatibility.schema.json" -Raw | ConvertFrom-Json
            @($compatibility.properties.schemaVersion.enum) | Should -BeExactly @('1.0.0', '1.1.0')
        }
    }
}
