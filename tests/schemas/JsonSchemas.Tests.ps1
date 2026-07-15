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
                'standards-consistency' = @('1.0.0')
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
        }
    }
}
