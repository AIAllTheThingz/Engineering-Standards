# Security

## Supported Versions

This example tracks the current repository version of the Engineering Standards project. It is not released as an independent product.

## Reporting

Report security concerns through the parent repository security process in `../../SECURITY.md`.

## Sensitive Data

The example MUST NOT use credentials, tokens, customer data, production endpoints, private keys, session identifiers, or regulated data. Test inputs must remain synthetic and local.

## Dependencies

The example requires PowerShell and Pester. PSScriptAnalyzer is optional locally but recommended for production repositories that adopt this pattern.

## Governance

Security changes must follow the organization contract, PowerShell agent standard, completion evidence policy, and exception process. Any exception requires an approved `GOV-*` reference.
