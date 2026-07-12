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
            foreach ($name in @('project-manifest-user-owner.json', 'project-manifest.json', 'project-manifest-contact-owner.json', 'project-manifest-similar-user-owner.json', 'project-manifest-similar-team-owner.json')) {
                (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/$name" -Raw | Test-Json -SchemaFile $schema) | Should -BeTrue -Because $name
            }
        }

        It 'enforces required CODEOWNERS path structure directly in JSON Schema' {
            $schema = Resolve-Path "$PSScriptRoot/../../schemas/governance-config.schema.json"
            (Get-Content -LiteralPath "$PSScriptRoot/../fixtures/valid/governance-config-required-codeowner-paths.json" -Raw | Test-Json -SchemaFile $schema) | Should -BeTrue
            foreach ($fixture in Get-ChildItem "$PSScriptRoot/../fixtures/invalid" -Filter 'governance-config-codeowner-*.json') {
                (Get-Content -LiteralPath $fixture.FullName -Raw | Test-Json -SchemaFile $schema) | Should -BeFalse -Because $fixture.Name
            }
        }
    }
}
