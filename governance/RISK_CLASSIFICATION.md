# Risk Classification

Assess production impact, security impact, data sensitivity, privilege level, destructive capability, affected systems, external integration, recovery complexity, availability, regulatory impact, human safety, and financial or operational consequence.

| Risk | Review | Testing | Approval | Rollback | Automation |
| --- | --- | --- | --- | --- | --- |
| Low | One reviewer | Targeted | Standard review | Optional | Allowed |
| Moderate | Code owner | Build/unit/relevant integration | Code owner | Documented | Allowed with safe defaults |
| High | Code owner plus security/platform | Full suite plus negative/security cases | Explicit owner approval | Required | Controlled with evidence |
| Critical | Segregated owner, security, accountable approver | Full suite plus recovery validation | Explicit written approval | Tested recovery | Explicit confirmation and segregation of duties |

Examples: documentation is Low, workflow behavior is Moderate, scanner suppression is High, destructive production data migration is Critical.
