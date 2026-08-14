BeforeAll {
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:matrixPath = Join-Path $script:repoRoot 'governance/downstream-compatibility.json'
    $script:schemaPath = Join-Path $script:repoRoot 'schemas/downstream-compatibility.schema.json'
}

function script:Get-CompatibilityMatrix {
    Get-Content -LiteralPath $script:matrixPath -Raw | ConvertFrom-Json
}

function script:Test-CompatibilitySchema {
    param([Parameter(Mandatory)]$Matrix)
    try {
        return [bool]($Matrix | ConvertTo-Json -Depth 30 | Test-Json -SchemaFile $script:schemaPath -ErrorAction Stop)
    }
    catch {
        return $false
    }
}

Describe 'Downstream compatibility canary state contract' {
    It 'accepts the prepared 1.2.0 document with NotRun and no canary authority' {
        $matrix = Get-CompatibilityMatrix
        $matrix.schemaVersion | Should -BeExactly '1.2.0'
        $matrix.unreleasedContract.canaryValidationStatus | Should -BeExactly 'NotRun'
        $matrix.unreleasedContract.canaryValidatedWorkflowSha | Should -BeNullOrEmpty
        (Test-CompatibilitySchema -Matrix $matrix) | Should -BeTrue
    }

    It 'rejects a missing canaryValidationStatus for schema 1.2.0' {
        $matrix = Get-CompatibilityMatrix
        $matrix.unreleasedContract.PSObject.Properties.Remove('canaryValidationStatus')
        (Test-CompatibilitySchema -Matrix $matrix) | Should -BeFalse
    }

    It 'rejects a noncanonical canaryValidationStatus for schema 1.2.0' {
        $matrix = Get-CompatibilityMatrix
        $matrix.unreleasedContract.canaryValidationStatus = 'Unknown'
        (Test-CompatibilitySchema -Matrix $matrix) | Should -BeFalse
    }

    It 'rejects a retained canary authority for a nonpassing canary state' {
        $matrix = Get-CompatibilityMatrix
        $matrix.unreleasedContract.canaryValidationStatus = 'NotRun'
        $matrix.unreleasedContract.canaryValidatedWorkflowSha = 'de32b77e2043f5336a54b92ab9ed867abe93ba7e'
        (Test-CompatibilitySchema -Matrix $matrix) | Should -BeFalse
    }

    It 'rejects Passed without an immutable canary authority' {
        $matrix = Get-CompatibilityMatrix
        $matrix.unreleasedContract.canaryValidationStatus = 'Passed'
        $matrix.unreleasedContract.canaryValidatedWorkflowSha = $null
        (Test-CompatibilitySchema -Matrix $matrix) | Should -BeFalse
    }
}
