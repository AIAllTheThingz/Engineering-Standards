# Risk Classification

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.0.0 |
| Owner role | Risk Review Maintainers |
| Last reviewed | 2026-06-19 |
| Changelog | See [CHANGELOG.md](../CHANGELOG.md) unless this file is at repository root. |

## Normative Terminology

`MUST` and `MUST NOT` define mandatory requirements. `SHOULD` and `SHOULD NOT` define expected practices that require a documented reason when not followed. `MAY` defines optional behavior. Every mandatory statement is intended to be testable by automation, review, or recorded evidence.

## Purpose

Provide a repeatable way to classify engineering changes so review, testing, approval, rollback, and evidence scale with potential impact.

## Scope

Applies to source code, automation, infrastructure, data, dependencies, workflows, generated code, and documentation that changes operational behavior.

## Risk Dimensions

| Dimension | Low | Moderate | High | Critical |
| --- | --- | --- | --- | --- |
| Production impact | None | Limited or reversible | Direct production path | Broad outage or irreversible |
| Security impact | None | Defense-in-depth | Auth, secrets, privileged path | Identity, crypto, regulated data |
| Data sensitivity | Public | Internal | Confidential | Regulated or safety-impacting |
| Destructive capability | None | Local nonproduction | Scoped production | Broad or wildcard production |
| Recovery complexity | Trivial | Documented rollback | Coordinated rollback | Tested disaster recovery |

## Scoring Method

Assign 0-3 points per dimension. Highest single dimension may set the minimum classification. Totals 0-3 are Low, 4-7 Moderate, 8-11 High, and 12 or any automatic escalation factor is Critical.

## Automatic Escalation Factors

- Production destructive changes.
- Authentication, authorization, cryptography, or privileged identity changes.
- Regulated data migrations.
- Broad wildcard infrastructure targeting.
- Human safety, major financial impact, or legal obligation.

## Decision Matrix

| Risk | Review | Approval | Testing | Evidence | Rollback | Automation |
| --- | --- | --- | --- | --- | --- | --- |
| Low | One reviewer | Standard | Targeted | Commands and result | Optional | Allowed |
| Moderate | Code owner | Code owner | Build/unit/relevant integration | Test and scan evidence | Documented | Allowed with safe defaults |
| High | Code owner plus security/platform | Explicit owner | Full relevant suite and negative tests | Full completion evidence | Required | Controlled execution |
| Critical | Segregated owner, security, accountable approver | Written approval | Full suite plus recovery validation | Release-grade evidence | Tested recovery | Explicit confirmation only |

## Worksheet

1. List affected systems.
2. Score each dimension.
3. Identify automatic escalation factors.
4. Select required reviewers.
5. List required tests and evidence.
6. Document rollback.
7. Record exceptions if any.

## Examples

- PowerShell: adding `SupportsShouldProcess` to a reporting script is Low; remote deletion automation is High or Critical.
- .NET: adding health checks is Moderate; changing authorization policy is High.
- Web frontend: CSS-only change is Low; token storage change is High.
- Database: additive nullable column is Moderate; destructive migration is Critical.
- Infrastructure: plan-only validation is Moderate; firewall or identity changes are High.
- Worker service: retry tuning is Moderate; duplicate job prevention in billing is High.
- Integration: vendor timeout change is Moderate; credential flow change is High.

## Common Mistakes

Teams often underestimate data sensitivity, ignore rollback complexity, classify generated workflow changes as documentation, or treat nonproduction testing as proof of production safety.

## Related Documents

- `governance/ORGANIZATION_CONTRACT.md`
- `governance/COMPLETION_EVIDENCE.md`
- `docs/BRANCH_PROTECTION.md`
