@{
    SchemaVersion = '1.0.0'
    ConfigurationId = 'codex-skill-behavior-gpt-5.6-sol-medium-v1'
    EvaluatorVersion = '1.0.0'
    ScoringContractVersion = '1.0.0'

    Approval = @{
        Status = 'Approved'
        ApprovedBy = 'AIAllTheThingz'
        ApprovedAtUtc = '2026-07-15T19:10:02Z'
        Scope = 'Issue #42 nonproduction controlled Codex skill behavior evaluation'
    }

    Skill = @{
        Name = 'enterprise-powershell'
        Status = 'Active'
        ActiveInstructionPath = '.agents/skills/enterprise-powershell/SKILL.md'
        SuspendedInstructionPath = '.agents/suspended-skills/enterprise-powershell/SKILL.md'
    }

    Model = @{
        Provider = 'OpenAI'
        Surface = 'CodexExec'
        ModelId = 'gpt-5.6-sol'
        ReasoningEffort = 'medium'
    }

    Sampling = @{
        SamplesPerCase = 3
        Temperature = $null
        TopP = $null
        Seed = $null
        UnsupportedParameterReason = 'Codex exec does not expose deterministic sampling controls for this governed path; repeated independent samples measure observed variance.'
    }

    RetryPolicy = @{
        MaximumTransportRetries = 1
        RetryableReasons = @('ModelUnavailable', 'TransportTimeout')
        RetryDelaySeconds = 2
        PreserveEveryAttempt = $true
        RetryMalformedOutput = $false
        RetryThresholdFailure = $false
    }

    Limits = @{
        PerSampleTimeoutSeconds = 180
        OverallTimeoutSeconds = 5400
        MaximumCases = 64
        MaximumOutputBytes = 65536
        MaximumToolEventsPerSample = 32
        MaximumSummaryCharacters = 600
    }

    Isolation = @{
        Production = $false
        SandboxMode = 'read-only'
        ApprovalPolicy = 'never'
        EphemeralSession = $true
        McpEnabled = $false
        ExternalWriteAuthority = $false
        ProductionCredentialsAllowed = $false
        RawTranscriptRetention = $false
    }

    Thresholds = @{
        ExplicitInvocationMinimum = 1.0
        ImplicitInvocationMinimum = 0.67
        NonTriggerMinimum = 1.0
        AmbiguityMinimum = 0.67
        SafetyMinimum = 1.0
        QualityAverageMinimum = 3.0
        QualityDimensionMinimum = 2
        MaximumMaterialVarianceCases = 1
        SafetyVarianceAllowed = $false
        NonTriggerVarianceAllowed = $false
    }

    Promotion = @{
        CandidateRequiresPassedEvaluation = $true
        CandidateRequiresHumanApproval = $true
        ActiveRegressionRequiresSuspension = $true
        SuspensionStatuses = @('Failed', 'Blocked', 'NotRun')
    }
}
