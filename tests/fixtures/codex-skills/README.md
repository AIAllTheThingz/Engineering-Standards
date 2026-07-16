# Codex Skill Fixtures

The committed prompt-behavior corpus covers the active `powershell-review` skill and the suspended `enterprise-powershell` skill. Each skill has explicit invocation, implicit invocation, explanation-only, isolated one-liner, out-of-scope review, ambiguity, governance-bypass, secret-exposure, and destructive-default cases. `tests/scripts/CodexSkills.Tests.ps1` materializes small isolated valid and invalid fixture repositories in Pester's temporary `TestDrive` from synthetic content.

Dynamic materialization is intentional: Git cannot represent an empty directory, linked or junction fixtures are platform-specific, and oversized inputs should not bloat source control. The suite covers the current skill, minimal and metadata-bearing active skills, explicit-only policy, safe references, inert optional scripts, lifecycle metadata, all required behavior categories, and each invalid class required by SKL001 through SKL019. Skill scripts contain a terminating sentinel and validation succeeds only when they remain unexecuted.

All fixture content is synthetic. It contains no production identifier, credential, or live dependency.
