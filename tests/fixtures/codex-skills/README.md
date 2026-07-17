# Codex Skill Fixtures

The committed prompt-behavior corpus covers the active `enterprise-powershell` skill. `tests/scripts/CodexSkills.Tests.ps1` materializes small isolated valid and invalid fixture repositories in Pester's temporary `TestDrive` from synthetic content.

Dynamic materialization is intentional: Git cannot represent an empty directory, linked or junction fixtures are platform-specific, and oversized inputs should not bloat source control. The suite covers the current skill, minimal and metadata-bearing active skills, explicit-only policy, safe references, inert optional scripts, lifecycle metadata, all required behavior categories, and each invalid class required by SKL001 through SKL019. Skill scripts contain a terminating sentinel and validation succeeds only when they remain unexecuted.

All fixture content is synthetic. It contains no production identifier, credential, or live dependency.
