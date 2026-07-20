# AGENTS Infrastructure Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.1 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-21 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enforceable enterprise requirements for AI agents creating, reviewing, or modifying infrastructure, deployment configuration, platform automation, cloud resources, identity, network, DNS, certificates, storage, observability infrastructure, configuration management, and infrastructure CI/CD.

It inherits [AGENTS_Base.md](AGENTS_Base.md), the repository-root [../AGENTS.md](../AGENTS.md), and all governance documents. It does not replace application, database, worker, integration, frontend, or PowerShell standards. It adds infrastructure-specific controls for target safety, plan/apply separation, state integrity, supply chain, operational readiness, rollback, and honest evidence.

When this standard says a control is required, agents MUST implement it, prove it already exists, record a valid `NotApplicable`, `NotRun`, or `Blocked` status with reason, or reference an approved active exception.

## Applicability And Inheritance

This standard applies to:

- Terraform, OpenTofu, Bicep, ARM templates, CloudFormation, AWS CDK, Pulumi, and equivalent infrastructure-as-code systems.
- Kubernetes manifests, Helm charts, Kustomize overlays, operators, custom resources, Docker and OCI image deployment configuration, ingress controllers, and orchestration configuration.
- GitHub Actions deployment workflows, Azure DevOps, Jenkins, and other infrastructure pipelines.
- Ansible, DSC, Chef, Puppet, PowerShell deployment automation, configuration management, and bootstrap scripts.
- Windows Services, IIS, Linux services, systemd units, scheduled infrastructure jobs, and host-level middleware configuration.
- VMware vSphere, Hyper-V, Proxmox, DNS/IPAM systems, PKI, certificate stores, firewalls, load balancers, reverse proxies, routing, security groups, network ACLs, and ingress or egress policy.
- Identity, service accounts, managed identities, IAM, RBAC, privileged access, secret stores, key stores, storage, persistent volumes, backups, disaster recovery, observability, cloud resources, hybrid resources, and on-premises platform configuration.

Cross-standard handoffs are mandatory:

- PowerShell infrastructure automation, remoting, credentials, PSD1 configuration, `WhatIf`, `DryRun`, reporting, code signing, scheduled tasks, and deployment scripts MUST also apply [AGENTS_PowerShell.md](AGENTS_PowerShell.md).
- .NET deployment tools, services, APIs, configuration, secrets, native process execution, IIS hosting, containers, and health checks MUST also apply [AGENTS_DotNet.md](AGENTS_DotNet.md).
- Database provisioning, migrations, backups, replication, persistent data, stateful services, and database permissions MUST also apply [AGENTS_Database.md](AGENTS_Database.md).
- Worker services, schedulers, long-running jobs, script runners, leases, retries, and job execution infrastructure MUST also apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md).
- Vendor APIs, DNS/IPAM APIs, cloud APIs, certificate APIs, webhooks, message systems, and cross-system provisioning MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md).
- Web ingress, CSP-related hosting configuration, reverse proxies, static hosting, CDN, browser-facing TLS, and frontend delivery MUST also apply [AGENTS_WebFrontend.md](AGENTS_WebFrontend.md).
- Python infrastructure automation and deployment tooling MUST also apply [AGENTS_Python.md](AGENTS_Python.md).
- Bash provisioning, deployment, package, filesystem, and service automation MUST also apply [AGENTS_Bash.md](AGENTS_Bash.md).

Local instructions MAY strengthen this standard. They MUST NOT weaken root, base, security, review, validation, evidence, or exception controls.

## Normative Terminology

`MUST` and `MUST NOT` are mandatory. `SHOULD` and `SHOULD NOT` are expected controls that require recorded rationale when omitted. `MAY` is optional.

`Infrastructure` means desired-state configuration, deployment automation, platform configuration, managed services, hosts, networks, identities, certificates, storage, and operational resources. `Plan`, `preview`, `diff`, `what-if`, and `dry run` mean non-mutating review output. `Apply`, `deploy`, `destroy`, `import`, `move`, `repair`, `rotate`, `revoke`, `purge`, and `force-unlock` are mutating actions. `State` means the tool or platform record that maps desired configuration to real resources.

`NotRun` means validation did not execute. `Blocked` means validation could not complete because a credential, state backend, provider, cloud account, subscription, tenant, cluster, namespace, hypervisor, DNS platform, PKI system, secret store, policy engine, approval, or safe environment was unavailable. Agents MUST NOT convert unavailable infrastructure validation into `Passed`.

## Required Discovery

Before editing infrastructure, agents MUST inspect and record the relevant subset of:

- Infrastructure tool and exact version.
- Provider, plugin, module, chart, action, image, and dependency versions.
- Root module, child module, stack, project, workspace, environment, overlay, chart, values file, and variable structure.
- Desired-state source of truth and ownership boundary.
- State backend, lock mechanism, encryption, access controls, retention, history, backup, and recovery.
- Cloud, account, subscription, tenant, project, organization, region, zone, cluster, namespace, datacenter, vCenter, hypervisor, network, DNS/IPAM environment, and deployment environment.
- Production, nonproduction, sandbox, shared-services, disaster-recovery, and management-plane boundaries.
- Plan, preview, diff, apply, deploy, destroy, import, move, refresh, drift, approval, and rollback workflow.
- Current deployed version, current state, known manual changes, drift, resource inventory, and ownership.
- Identity and privilege used for plan and apply.
- Secrets, keys, certificates, tokens, kubeconfigs, SSH keys, service principals, managed identities, and signing material.
- Public IPs, ingress, egress, routes, DNS, IPAM, proxies, load balancers, security groups, firewalls, network ACLs, private endpoints, and trust boundaries.
- Persistent storage, databases, queues, backup targets, snapshots, replication, retention, RPO, RTO, availability, durability, and maintenance-window requirements.
- Replacement and recreation behavior, resource dependencies, failure domains, quotas, scaling constraints, cost center, budget, and capacity constraints.
- Regulatory, privacy, data residency, logging, retention, monitoring, alerting, policy-as-code, security scanning, validation workflows, deployment evidence, and existing user changes from `git status --short`.

Agents MUST inspect root and child modules, variable definitions and defaults, environment-specific values, backend configuration, provider configuration, lockfiles, CI/CD workflows, policy checks, deployment scripts, existing state-migration files, runbooks, monitoring, backup configuration, and adjacent systems affected by the change.

Guessing target environment from directory name, current CLI context, shell profile, default subscription, default region, default kubeconfig context, or cached credentials is prohibited.

## Risk Classification

Infrastructure work MUST be classified using [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md). Risk MUST be reevaluated when target environment, resource count, identity privilege, public exposure, persistent data, region, failure domain, cost, quota, production reachability, or plan output changes.

Critical by default:

- Production destroy or broad replacement.
- State deletion, state backend migration, force-unlock, or manual state surgery.
- Public exposure of private services, broad firewall allow rules, wildcard ingress from the internet, or disabling certificate validation.
- Root, owner, subscription administrator, domain administrator, cluster-admin, privileged IAM/RBAC, or equivalent access.
- Production secret, key, certificate, trust-root, signing-key, identity-federation, or administrator-lockout changes.
- Disabling encryption, logging, policy enforcement, monitoring, backup, security controls, certificate validation, or audit controls.
- Cross-environment, cross-tenant, broad production DNS cutover, backup deletion, persistent-volume deletion, database deletion, state deletion, unbounded cost exposure, regulated environment change, or healthcare/sensitive environment change without validated controls.

High by default:

- Production apply, resource replacement, network, route, DNS, firewall, ingress, egress, load balancer, proxy, IAM/RBAC, service account, certificate, storage, database, queue, cluster, namespace, service, IIS, Windows Service, compute deployment, module/provider upgrade, state import, state move, backup, recovery, autoscaling, quota, resource-limit, observability, alert-routing, or scheduled infrastructure automation changes.

Moderate examples include formatting only, documentation only, synthetic tests, nonproduction read-only inventory, and additional non-sensitive metrics with no behavior change.

Agents MUST NOT lower risk classification merely to reduce validation, approval, or evidence.

## Infrastructure Lifecycle And Execution Modes

Infrastructure work MUST follow explicit phases:

1. Discovery.
2. Static validation.
3. Plan, preview, or diff.
4. Policy and security review.
5. Approval.
6. Apply or deploy.
7. Post-deployment verification.
8. Evidence capture.
9. Rollback or recovery readiness.

The default mode for AI-generated infrastructure work MUST be non-mutating. Plan or preview does not equal apply success. Build, template compilation, or manifest rendering does not equal deployment success. Successful apply does not equal service readiness. Successful process exit does not equal infrastructure correctness.

Agents MUST NOT apply, deploy, destroy, import, move, force-unlock, rotate, revoke, purge, or mutate state unless explicitly requested and authorized for the exact target. Production mutation requires explicit environment identification, approval, and evidence. Destructive operations MUST NOT be the first implementation phase. Where preview is impossible, agents MUST document the limitation and compensating controls.

## Source Of Truth And Desired-State Ownership

Every governed resource MUST have one declared source of truth. Ownership boundaries between IaC, configuration management, operators, platform controllers, and manual administration MUST be explicit.

No two systems may manage the same resource or field without a conflict-resolution design. Manual changes to managed resources MUST be detected and reconciled. Generated configuration MUST NOT overwrite manually owned data silently. Imported resources MUST receive documented ownership before future changes. Resources outside the declared ownership boundary MUST NOT be modified merely because they are discoverable.

Shared resources require explicit owner and consumer contracts. Bootstrap resources, backend resources, shared-service resources, and management-plane resources require documented lifecycle ownership.

## Environment, Account, Subscription, Tenant, Region, Cluster, And Namespace Targeting

Every mutating command MUST make the following explicit where applicable:

- Environment.
- Account, subscription, project, tenant, or organization.
- Region, zone, datacenter, or failure domain.
- Cluster, namespace, vCenter, hypervisor, DNS/IPAM environment, or Windows domain.
- Workspace, stack, overlay, resource group, project, folder, state backend, identity, and target resource set.

Implicit production defaults are prohibited. Empty target MUST NOT mean all environments or all resources. Wildcards require explicit governance and Critical review in production. Cached CLI context alone is insufficient for production mutation. Commands MUST verify actual context before mutation. Production and nonproduction state, credentials, variables, and backends MUST be separated. Environment values from untrusted content MUST be allowlist-validated. Cross-environment references require explicit review. Shared-service changes MUST identify all consumers.

Safe context-check examples are placeholders and do not imply execution:

```powershell
az account show
aws sts get-caller-identity
gcloud config list project
kubectl config current-context
kubectl config view --minify
terraform workspace show
terraform providers
govc about
```

DNS/IPAM and Windows-domain tooling varies by platform. Equivalent checks MUST identify the environment, endpoint, identity, scope, and whether the operation is read-only.

## Plan-Before-Apply And Change Preview

Infrastructure changes MUST use plan-before-apply, preview, what-if, diff, or equivalent review output where the tool supports it. Evidence MUST include machine-readable and human-readable output where supported.

Plan or preview evidence MUST identify exact tool version, configuration revision, variable set, environment, state/backend identity, provider/module versions, timestamp, summary, create/update/replace/destroy/read/no-op counts, unknown values, deferred actions, sensitive-value redaction, policy result, approval binding, and freshness rule.

Apply MUST use the reviewed saved plan artifact where the tool supports saved plans. A plan generated from one commit, variable set, state, provider set, credential, policy set, or environment MUST NOT authorize a different apply. Production applies MUST NOT regenerate an unreviewed plan and immediately apply it. Hidden replacements and destructive lifecycle changes MUST be highlighted. Plan files may contain sensitive values and MUST be protected. Plan output MUST NOT be committed. A zero-change plan MUST NOT be fabricated by filtering output.

## Approval And Separation Of Duties

Infrastructure approval MUST identify submitter, reviewer, approver, and executor identity. Approval MUST be risk-based and bound to the exact plan, commit, environment, state backend, variable set, and artifact digest where applicable.

Production environment protections MUST be used where available. Separation of duties is REQUIRED where policy, risk, or environment requires it. Critical changes MUST NOT be self-approved unless an approved emergency process applies. Approval MUST expire and MUST be repeated after material changes. Service identities MUST NOT approve their own changes. Manual approval steps MUST NOT be bypassed by workflow edits in the same unreviewed change. Break-glass actions require documentation, time limit, audit, and post-change review.

## State Backends, Locking, And State Integrity

Shared or production state MUST use a remote protected backend where supported. State backends MUST define encryption at rest, encryption in transit, least-privilege access, state locking, versioning, history, backup, retention, recovery test, audit logging, environment isolation, output controls, backend bootstrap, and backend change approval.

State is sensitive and may contain secrets. State files MUST NOT be committed. Local state MUST NOT be used for shared production infrastructure unless explicitly approved. State backend outage is `Blocked` for apply, not a reason to bypass locking. Force-unlock requires proof that no active operation owns the lock. Lock IDs, owner details, operation age, and backend health MUST be verified before force-unlock. State corruption MUST trigger recovery procedures. State snapshots MUST be protected. State recovery MUST verify lineage, serial or version, environment, and resource identity. State output exposure MUST be minimized.

## State Migration, Import, Move, And Repair

State import, move, migration, backend migration, repair, `state rm`, `state mv`, moved blocks, and manual state surgery require phased controls:

1. Discovery.
2. Mapping.
3. Backup.
4. DryRun or preview.
5. Validation.
6. Approval.
7. State operation.
8. Plan verification.
9. Post-operation evidence.

Evidence MUST include exact resource addresses, exact remote resource IDs, source and destination state, ownership mapping, dependency mapping, backup before mutation, collision detection, approval, and rollback limitations. Broad wildcard import is prohibited. Guessing resource addresses is prohibited. Removing resources from state merely to suppress drift is prohibited. Manual state editing is prohibited unless an approved emergency procedure requires it. State repair MUST NOT create duplicate management. Import success MUST be followed by a no-unexpected-change plan. Backend migration MUST verify old and new state integrity.

## Provider, Module, Action, Image, And Toolchain Pinning

Infrastructure CLI versions MUST be pinned or constrained. Provider versions MUST be pinned or constrained. Modules MUST be pinned to immutable versions, commits, or digests. Helm charts MUST be pinned. Protected production container and Kubernetes deployment paths MUST pin images by immutable digest. Tags MAY remain as human-readable metadata but MUST NOT be the only production identity. A mutable tag such as `latest`, `stable`, `release`, `main`, `master`, or a reusable semantic tag is insufficient by itself. The resolved digest MUST be recorded in plan or deployment evidence. Registry, repository, tag, digest, signature or attestation status, scanner result, and provenance MUST be reviewed together. GitHub Actions MUST be pinned to immutable commit SHAs. Package lockfiles, Terraform or OpenTofu dependency lockfiles, and equivalent locks MUST be governed where supported.

Digest changes are deployment changes and require review. Rollback MUST identify the exact prior digest. Image policy MUST reject unapproved digest substitution. Multi-architecture manifests require platform-aware digest handling. Mirrored or promoted images MUST preserve or re-establish provenance and integrity. If digest pinning is technically unsupported, evidence MUST record the exact documented limitation, an approved active exception, an alternate immutable package or release identity, and compensating verification.

Production dependencies MUST NOT use floating `latest`, `main`, `master`, mutable branch names, mutable tags, or unbounded version ranges unless an approved exception documents compensating controls. Provenance, publisher, checksum, signature, changelog, breaking changes, transitive dependencies, private registry trust, TLS validation, and dependency update review MUST be considered. Dynamically downloaded scripts MUST NOT be immediately executed without integrity controls. Generated providers, modules, plugins, charts, or images MUST NOT be silently substituted.

## Dependency And Supply-Chain Integrity

Infrastructure supply chain review MUST include provider source, module source, registry trust, action source, image source, chart source, license, known vulnerabilities, binary artifacts, install hooks, plugin cache behavior, private feed authentication, checksums, signatures, SBOM or provenance where available, and reproducibility.

Third-party code or modules MUST not be trusted merely because a plan succeeds. New dependency execution paths, CI permission changes, action upgrades, provider upgrades, and module upgrades are High by default until reviewed.

## Resource Naming, Tagging, Ownership, And Metadata

Resources MUST follow documented naming and metadata conventions where the platform supports them. Required metadata SHOULD include environment marker, application or service, owner, cost center, data classification, lifecycle, repository, source module, managed-by marker, and support contact.

Names MUST avoid real secrets, regulated data, customer data, patient data, personal data, or internal incident details. Generated names MUST be stable enough to avoid accidental replacement where replacement has impact. Renames MUST be treated as potential replacement. Shared resources MUST identify owner and consumers.

## Destructive Operations And Replacement

Destroy, replacement, deletion, purge, resource rename, recreation, force replacement, broad refactoring, and lifecycle changes that can delete or recreate resources MUST include exact targets, plan output, blast-radius assessment, affected consumers, persistent data impact, backup or recovery plan, rollback or mitigation, approval, and post-change verification.

Production destructive changes are Critical unless an accountable reviewer documents otherwise. Wildcard destructive operations are prohibited without Critical approval. Empty target MUST NOT mean all resources. Replacement of stateful resources MUST not proceed until data preservation, replication, backup, and recovery are addressed. `create_before_destroy`, `prevent_destroy`, retention locks, soft delete, purge protection, and lifecycle settings MUST be reviewed where supported.

## Persistent Data And Storage Protection

Persistent disks, volumes, shares, buckets, databases, queues, snapshots, backup repositories, and object stores MUST define owner, data classification, encryption, access controls, retention, lifecycle policy, replication, backup, restore, deletion protection, capacity, quotas, and recovery process.

Destroying, recreating, resizing, moving, migrating, or changing access to persistent storage is High or Critical. Snapshot existence does not prove restore capability. Backup configured does not prove restore tested. Agents MUST NOT describe a destructive storage replacement as rollback when it loses data.

## Networking And Exposure

Networking MUST be private by default and deny by default where the platform supports it. Public exposure requires explicit intent, target service, listener, protocol, port, source range, destination, TLS behavior, WAF/proxy behavior where applicable, owner, justification, approval, monitoring, and rollback.

Broad ingress, wildcard source ranges, unrestricted egress, route-table changes, NAT, VPN, peering, private endpoint, load balancer, reverse proxy, firewall, network ACL, security group, and ingress-controller changes require blast-radius review. Public ingress from anywhere is Critical or High depending on data, service, and controls. Certificate validation, host validation, and origin validation MUST NOT be disabled for convenience.

Every temporary network or firewall rule MUST define rule ID or name, owner, requestor, business reason, source, destination, protocol, port, environment, creation time, expiration time, change or ticket reference, monitoring, cleanup owner, and removal verification. Temporary rules MUST have an explicit expiration. Temporary rules MUST be removed automatically where the platform supports it, or have a documented manual removal task and owner. Expired rules MUST NOT remain active silently. Removal MUST be verified.

Administrative interfaces such as SSH, RDP, WinRM, vCenter, hypervisor management, Kubernetes API, database administration, storage administration, and PKI administration MUST NOT be exposed publicly without Critical approval and compensating controls. Broad source ranges, all ports, all protocols, wildcard destinations, or unrestricted egress require High or Critical review. Rule descriptions or comments are not enforcement. Security-group references, service tags, prefix lists, and dynamic identities MUST be reviewed for actual effective scope. Network-policy and firewall changes MUST account for stateful or stateless behavior. Emergency access requires break-glass controls, short expiration, audit, and removal verification. Firewall deletion MUST verify that required traffic still has an approved path. Rule cleanup MUST NOT delete shared rules without consumer review.

## DNS, IPAM, And Traffic Cutover

DNS, IPAM, load balancer, reverse proxy, ingress, CDN, and traffic-routing changes MUST identify zone, record, IP allocation, owner, environment, TTL, cache behavior, propagation expectations, consumer impact, rollback, monitoring, and conflict detection.

Every DNS or IPAM change MUST define environment, DNS server or provider, zone, view or split-horizon scope, record name, record type, existing value, new value, TTL, existing TTL, desired TTL, owner, application or service, IPAM reservation, network or subnet, forward record, reverse or PTR record, duplicate or conflict check, DNSSEC behavior where applicable, certificate SAN and hostname alignment, load balancer or backend readiness, propagation expectations, validation resolver set, rollback value, rollback TTL, change window, and consumer impact.

Production DNS cutover affecting broad traffic is Critical by default. DNS rollback MUST account for TTL and caches. IPAM changes MUST avoid duplicate allocation. Traffic cutover MUST define health gates, stop conditions, and data compatibility. Placeholder examples MUST NOT include real zones, IP addresses, customer domains, or certificate names.

Existing records MUST be read and recorded before replacement or deletion. Record-type changes require dependency review. Forward and reverse or PTR records MUST be considered together where reverse DNS is relevant. Split-horizon DNS views MUST be explicit. Internal and external answers MUST NOT be confused. DNSSEC changes MUST define key, signer, chain-of-trust, rollover, and rollback review. Certificate SANs and service hostnames MUST align before traffic cutover. TTL reduction for planned cutover MUST occur early enough to become effective before the change window. Agents MUST NOT assume immediate propagation. Validation SHOULD query multiple authoritative or recursive resolvers appropriate to the environment. DNS cache behavior MUST be included in rollback. Wildcard DNS records require High or Critical review. DNS deletion requires consumer and dependency review. IP allocation MUST use approved IPAM where required. Hard-coded unmanaged IP allocation is prohibited where IPAM is authoritative. Duplicate IP, duplicate hostname, stale reservation, and orphaned record checks are required. PTR deletion or creation MUST NOT be omitted when required by environment policy. Traffic cutover MUST verify backend readiness before changing DNS. Rollback MUST identify the exact prior record values. DNS changes MUST be auditable and correlated to the infrastructure change.

## Identity, IAM, RBAC, And Service Accounts

Infrastructure identity MUST follow least privilege. Application, deployment, plan, apply, break-glass, monitoring, and runtime identities SHOULD be separate where practical. IAM, RBAC, service account, managed identity, federation, permission boundary, role assignment, group membership, and privileged-access changes MUST identify subject, scope, action, resource, condition, duration, owner, and revocation path.

Wildcard IAM, broad administrator access, cluster-admin, subscription owner, domain administrator, root, or equivalent access is Critical unless narrowly justified and approved. Service identities MUST NOT approve their own changes. Production credentials MUST NOT be available to untrusted pull-request code. Access changes require negative review for privilege escalation and cross-tenant or cross-environment reach.

Every service or workload identity MUST define identity type, owner, purpose, environment, scope, permissions, trust relationship, authentication mechanism, credential source, rotation, expiration, revocation, interactive-login policy, network access, audit, break-glass behavior, decommissioning, and consumer systems. Managed identity, workload identity, federated identity, gMSA, virtual account, or equivalent short-lived mechanism MUST be preferred where supported. Long-lived static credentials MUST NOT be used where a supported workload identity can meet the requirement. Interactive login MUST be disabled for service accounts unless explicitly required and approved. Service accounts MUST be environment-specific unless a documented cross-environment design is approved. Shared service accounts are prohibited by default and require ownership and consumer mapping. Credentials MUST have defined rotation and expiration.

Orphaned service accounts MUST be detected and removed or disabled. Service-account decommissioning MUST revoke access, secrets, keys, tokens, and role assignments. Kubernetes service accounts MUST define token mounting, audience, expiration, projected-token behavior, and RBAC. AutomountServiceAccountToken SHOULD be disabled when not required. Cloud trust policies MUST constrain principal, audience, subject, repository, branch or environment, tenant, or equivalent claims. IAM policy simulation, access review, or equivalent negative-permission testing SHOULD be used where supported. Removing access requires administrator and workload lockout analysis. Privilege escalation paths through pass-role, impersonation, assume-role, token creation, group nesting, or delegated administration MUST be reviewed. Service-account secrets MUST NOT appear in code, state, command lines, or logs.

## Secrets, Keys, Certificates, And PKI

Secrets, private keys, certificates, kubeconfigs, SSH keys, tokens, service-principal secrets, signing keys, and state containing sensitive values MUST be stored in approved secret stores or protected platform mechanisms. They MUST NOT appear in source, state committed to Git, ordinary config, tfvars, examples, command lines, logs, plan output committed to the repo, screenshots, evidence, or artifacts.

Certificate and PKI changes MUST define subject, SANs, issuer, chain, trust store, private-key storage, key usage, EKU, algorithm, key size, expiration, renewal, rotation, revocation, deployment target, TLS termination point, monitoring, rollback, and owner. Certificate validation MUST NOT be bypassed. Trust-root and signing-key changes are Critical by default. Suspected secret exposure MUST stop normal completion claims and trigger rotation or incident guidance.

## Encryption And Key Management

Infrastructure that stores or transmits nonpublic data MUST define encryption at rest, encryption in transit, key ownership, key access, rotation, revocation, backup, recovery, and audit. Customer-managed keys, HSMs, key vaults, KMS keys, disk encryption sets, TLS policies, SSH host keys, and signing keys require owner and lifecycle documentation.

Disabling encryption, weakening TLS, bypassing certificate validation, broadening key access, deleting keys, disabling purge protection, or changing trust roots is High or Critical. Key rotation rollback MUST consider revocation, cache, trust, and data decryptability.

## Compute, Operating Systems, Services, And Middleware

Compute changes MUST identify image, OS version, patch source, bootstrapping, user identity, privileges, network exposure, service ports, disk layout, logging, monitoring, backup, shutdown behavior, restart behavior, health checks, hardening, and vulnerability posture.

Services and middleware MUST have explicit configuration ownership, startup order, dependencies, credentials, file permissions, ports, TLS, logs, resource limits, and rollback. Hosts MUST NOT use broad administrator permissions merely for convenience. Golden images, AMIs, VM templates, container base images, and appliance images MUST be versioned and reviewed.

## IIS, Windows Services, Linux Services, And Scheduled Infrastructure Jobs

IIS, Windows Services, systemd units, cron jobs, scheduled tasks, and platform jobs MUST define service name, execution identity, permissions, working directory, environment variables, secret source, restart policy, timeout, health check, log path, dependency order, installation path, rollback, and validation.

Windows Service and IIS work that hosts .NET code MUST also follow [AGENTS_DotNet.md](AGENTS_DotNet.md). PowerShell-based service, DSC, scheduled task, or deployment automation MUST also follow [AGENTS_PowerShell.md](AGENTS_PowerShell.md). Scheduled infrastructure jobs MUST not default to destructive mode merely because they are unattended.

Every IIS infrastructure change MUST define site name, application name where applicable, application pool name, application pool identity, managed runtime or no-managed-code setting, pipeline mode, start mode, idle timeout, recycling policy, rapid-fail protection, queue length where relevant, 32-bit application setting where relevant, physical path, content/deployment path ownership, filesystem permissions, binding protocol, hostname, port, IP binding, SNI behavior, TLS certificate identity, certificate store/location, certificate private-key access, HTTP-to-HTTPS behavior, authentication mode, authorization boundary, logging, failed-request tracing where required, request limits, upload limits, health endpoint, hosting bundle/runtime dependency, deployment strategy, rollback, and backup or configuration export where appropriate. IIS sites and applications MUST NOT use broad filesystem permissions such as Everyone, Users, Authenticated Users, or broad write access unless explicitly justified and approved. Application pool identities MUST receive only the minimum path, certificate, registry, network, and service permissions required. Production bindings MUST explicitly identify hostname, port, protocol, SNI, and certificate. Wildcard bindings require High or Critical review depending on exposure. Unreviewed catch-all bindings are prohibited. HTTP bindings for protected applications MUST define redirect, isolation, or approved exception behavior. TLS certificate binding MUST verify hostname/SAN, chain, EKU, validity, private-key association, and application-pool access where required. Physical paths MUST be canonicalized and resolved beneath approved roots. Deployment directories MUST not be writable by untrusted users. `web.config` and deployment logs MUST NOT contain plaintext secrets. IIS configuration changes MUST define whether `applicationHost.config`, delegated config, or site-level config is the source of truth. Changes to authentication, authorization, request filtering, handler mappings, modules, reverse proxy settings, or TLS are High by default. IIS restart, app-pool recycle, and site stop/start behavior MUST be explicit and MUST NOT be hidden. Successful file copy or site start MUST NOT be treated as application readiness. Hosting bundle/runtime compatibility MUST be validated for hosted .NET applications under [AGENTS_DotNet.md](AGENTS_DotNet.md). Configuration backups or exports MUST be protected when they contain sensitive settings.

Every Windows Service infrastructure change MUST define service name, display name, description, binary path, binary arguments, quoted path behavior, working directory, service identity, logon rights, start type, delayed-auto-start behavior, dependencies, failure recovery, restart count, reset period, service timeout, stop timeout, health check, logging, Event Log source, upgrade process, rollback, binary/config directory ownership, Service Control Manager ACL, registry/configuration path, secret source, network permissions, firewall requirements, and certificate access where relevant. Service binary paths containing spaces MUST be safely quoted. Unquoted service paths are prohibited. Service executable, configuration, and working directories MUST NOT be writable by untrusted or ordinary users. Service identities MUST use least privilege. LocalSystem, LocalService, NetworkService, domain accounts, gMSA, virtual accounts, and managed identities MUST be explicitly justified and reviewed according to scope. Interactive logon for service accounts MUST be disabled where not required. Broad local administrator or domain administrator rights are prohibited by default. Service Control Manager ACLs MUST prevent unauthorized reconfiguration, start, stop, delete, or binary-path changes. Service recovery MUST NOT create uncontrolled restart loops. Recovery commands MUST NOT execute arbitrary or mutable paths. Service upgrade MUST verify binary identity, version, signature or hash where required. A service being in Running state MUST NOT be treated as full application readiness. Service stop/start and reboot requirements MUST be explicit. Rollback MUST identify the exact prior binary/configuration version. Secrets MUST NOT be embedded in ImagePath, command-line arguments, registry values, or logs.

Every systemd service change MUST define unit name, description, User, Group, WorkingDirectory, ExecStart, ExecStartPre/ExecStartPost where used, ExecStop, environment source, secret source, restart policy, restart delay, TimeoutStartSec, TimeoutStopSec, KillMode, dependencies, ordering, network dependencies, logging, health/readiness, capability requirements, filesystem access, temporary files, runtime directories, state directories, upgrade, rollback, and enable/start behavior. User and Group MUST be explicit. Root execution requires High or Critical review and justification. NoNewPrivileges SHOULD be enabled where supported. CapabilityBoundingSet and AmbientCapabilities MUST be minimized. ProtectSystem, ProtectHome, PrivateTmp, PrivateDevices, ProtectKernelTunables, ProtectKernelModules, ProtectControlGroups, RestrictAddressFamilies, RestrictNamespaces, LockPersonality, MemoryDenyWriteExecute, and SystemCallFilter MUST be reviewed where supported. ReadWritePaths MUST be limited to required directories. World-writable executable or configuration directories are prohibited. EnvironmentFile and secret files MUST not be world-readable. Secrets MUST NOT appear in unit files, command-line arguments, journal output, or ordinary environment files. Unit drop-ins and override ownership MUST be explicit. Daemon reload, enable, start, restart, and stop behavior MUST be documented. Active state MUST NOT be treated as full application readiness. Restart=always or aggressive restart loops require bounds and operational review. systemd sandboxing exceptions require rationale. Unit files and executable paths MUST be integrity-controlled.

## Containers, Kubernetes, Helm, And Orchestration

Container and Kubernetes work MUST define image source, tag, digest, signature or provenance where available, runtime user, privilege model, capabilities, filesystem mode, seccomp/AppArmor/SELinux profile where applicable, resource requests and limits, probes, environment variables, secret mounts, config maps, volumes, network policies, service accounts, RBAC, namespaces, ingress, egress, rollout strategy, and rollback.

Protected production images MUST be pinned by digest and MUST avoid unreviewed `latest` tags. Kubernetes workloads MUST run non-root where feasible. Privileged containers, hostPath mounts, host networking, host PID, added Linux capabilities, cluster-admin, broad RBAC, unrestricted egress, and disabled admission policy require Critical or High review. Helm template rendering is not cluster validation. Server-side dry run does not prove runtime readiness.

## Databases And Stateful Services As Infrastructure

Managed databases, caches, queues, search services, object stores, persistent volumes, and stateful services provisioned by infrastructure MUST follow this standard and [AGENTS_Database.md](AGENTS_Database.md) where database behavior is involved.

Provisioning MUST define engine/version, storage, backup, restore, replication, maintenance window, network access, encryption, identity, parameter groups, extensions, monitoring, scaling, deletion protection, migration dependencies, RPO, RTO, and ownership. Changing stateful infrastructure MUST not be treated as stateless replacement.

## Backup, Restore, Disaster Recovery, RPO, And RTO

Backup and disaster-recovery configuration MUST identify protected resources, schedule, retention, encryption, storage location, immutability or soft-delete controls, access controls, restore owner, restore procedure, restore-test status, RPO, RTO, point-in-time capability, replication, failover, and evidence.

Backup configured is not restore proven. Snapshot existence is not restore evidence. Restore validation MUST use safe nonproduction targets or approved protected procedures. Destructive production work that depends on recovery MUST verify recovery through an authoritative mechanism or record `Blocked`. Failover and restore claims MUST NOT be marked `Passed` unless they actually ran.

## High Availability, Resiliency, Regions, Zones, And Failure Domains

Infrastructure changes MUST identify availability targets, zone/region placement, failure domains, single points of failure, dependency availability, load balancing, failover behavior, capacity after failure, maintenance windows, replication lag, health checks, and recovery owner.

Region, zone, failover, replication, quorum, autoscaling, or placement changes are High or Critical when they affect production reliability. Multi-region claims require validation or `NotRun` evidence. Adding replicas does not prove high availability without traffic, health, data consistency, and failover behavior.

## Configuration Management And Drift

Configuration management MUST define desired-state ownership, inventory, variables, secrets, execution identity, idempotency, check mode, drift detection, remediation, and conflict handling. Drift MUST be detected and reviewed before applying changes to managed resources.

Manual drift MUST NOT be silently overwritten when the field is outside IaC ownership. Drift MUST NOT be hidden by removing resources from state. Configuration tools MUST fail safely on ambiguous target sets. Drift detection unavailable because of credentials, backend, provider, or environment access MUST be recorded as `NotRun` or `Blocked`.

## Policy-As-Code, Compliance, And Guardrails

Infrastructure repositories SHOULD use policy-as-code or equivalent guardrails where risk justifies it. Policy results MUST be reviewed before apply. Policy failures MUST NOT be ignored, suppressed, or converted to success without an approved exception.

Policies SHOULD cover public exposure, encryption, secret handling, IAM/RBAC, tag/metadata requirements, region restrictions, data residency, backup, deletion protection, image provenance, container privilege, and cost controls. Guardrails in cloud, cluster, CI, or admission systems MUST NOT be disabled merely to make a deployment pass.

## Cost, Quota, Capacity, And Resource Limits

Infrastructure changes MUST consider cost, quota, scaling, capacity, resource limits, and billing owner. Autoscaling, instance size, replica count, storage growth, retention, logging volume, egress, NAT, public IPs, managed service tiers, and backup retention can materially change cost.

Unbounded autoscaling is prohibited. Resource limits and quotas MUST be bounded. Cost-impacting changes are High by default when they affect production or shared services. Evidence SHOULD include cost estimate, quota review, or reason the check was `NotRun`.

## Observability And Operational Readiness

Infrastructure MUST define logging, metrics, traces, alerts, dashboards, health checks, SLO/SLA signals where applicable, ownership, escalation, runbook, and operational acceptance criteria. Alert-routing changes are High when they can hide incidents or page the wrong team.

Logs and telemetry MUST NOT expose secrets, tokens, private keys, kubeconfigs, state contents, regulated data, or sensitive topology beyond approved audiences. Monitoring deployment does not prove alert behavior unless alert routing or synthetic validation ran.

## Deployment Strategies And Rollout

Deployment strategy MUST match workload and state. Valid strategies MAY include rolling, blue/green, canary, recreate, maintenance-window, phased region, or manual controlled rollout. The strategy MUST define rollout order, traffic shift, data compatibility, old/new version compatibility, maintenance window, user impact, capacity, health gates, stop conditions, and rollback or roll-forward.

Rolling deployments require compatibility. Blue/green requires data and DNS or traffic cutover planning. Canary requires measurable success criteria. Recreate requires downtime acceptance. Deployment MUST stop on failed health gates. Automatic rollback MUST NOT hide partial side effects. Infrastructure and application rollout order MUST be explicit.

## Rollback, Roll-Forward, And Irreversible Changes

Rollback planning MUST identify rollback eligibility, command or procedure, roll-forward alternative, data compatibility, state compatibility, artifact/version availability, timing, approval, verification, irreversible steps, and mitigation.

Not every infrastructure change is reversible. A destroy/recreate action MUST NOT be described as rollback when it loses data. State rollback MUST not be done casually. Provider/module downgrade compatibility MUST be reviewed. Certificate/key rotation rollback MUST consider revocation and trust. DNS rollback MUST account for TTL/cache. Storage and database changes may require roll-forward only. Irreversible changes require explicit approval before apply.

## CI/CD And Automation Security

Infrastructure CI/CD MUST use least-privilege workflow permissions, environment protections, OIDC or workload identity where supported, no long-lived cloud keys where avoidable, immutable action SHA pinning, trusted runners, runner isolation, fork/PR secret safety, protected branches, approval gates, artifact integrity, plan/apply separation, concurrency controls, timeouts, cancellation, audit, and context verification.

Production mutation MUST NOT run from untrusted pull requests. Workflow changes that modify deployment permissions require heightened review. Plan artifacts MUST be bound to commit and environment. Production credentials MUST not be available to untrusted code. Self-hosted runners require hardening and cleanup. Secrets MUST NOT appear in command lines or logs. Workflow steps MUST NOT use fake success commands. Apply MUST NOT run after failed validation. Concurrent production applies MUST be prevented where unsafe.

## Testing And Validation

Infrastructure changes MUST include applicable tests or justified statuses. Tests SHOULD use synthetic values, nonproduction accounts/subscriptions/projects, ephemeral resources where approved, local emulators, static fixtures, mock providers, and read-only discovery where mutation is not authorized. Production MUST NOT be used merely because a test environment is unavailable.

Applicable tests include format and syntax, static validation, provider/module initialization, plan/preview, policy-as-code, secret scanning, IaC security scanning, dependency integrity, environment targeting, context validation, state backend and lock behavior, state migration/import fixtures, plan replacement/destroy detection, variable boundary cases, empty target behavior, wildcard rejection, naming/tagging, IAM/RBAC least privilege, network exposure, DNS/IPAM, certificate validation, storage persistence, backup configuration, restore procedure where safe, HA/failure-domain assumptions, drift detection, cost/quota bounds, container security, Kubernetes manifest validation, Helm template validation, server-side dry run, IIS/service/systemd configuration, rollout, rollback, failure/cancellation behavior, production-blocking controls, and evidence generation.

Skipped or unavailable tests require exact `NotRun`, `Blocked`, or `NotApplicable` status and reason.

## Validation Commands

Repository-root [../AGENTS.md](../AGENTS.md) is the source of truth for repository validation. Infrastructure commands are conditional on actual tools, credentials, backends, providers, and safe environments. Exact command, working directory, tool version, exit code, summary, and status MUST be recorded. Missing credentials, backends, providers, policy engines, or environments are `NotRun` or `Blocked`. Plan does not prove apply. Apply does not prove readiness. Destroy validation MUST NOT use production.

Terraform/OpenTofu static validation examples:

```powershell
terraform version
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

`terraform init -backend=false` is suitable only for static initialization or validation where supported. A plan generated without the authoritative backend or state MUST NOT be treated as authoritative production plan evidence. Backendless plan behavior MAY be incomplete, fail, or differ from real state-backed planning. Backendless validation MUST NOT be used to claim drift detection, replacement accuracy, destroy accuracy, or no-change status.

Authorized state-backed planning examples:

```powershell
terraform init
terraform workspace show
terraform plan -out "<plan-file>"
terraform show -json "<plan-file>"
```

Production plan evidence requires the approved backend, workspace, variables, credentials, state, and target context. State-backed planning is credentialed and environment-specific and MUST NOT be implied as executed unless it actually ran.

Bicep and Azure examples:

```powershell
az account show
az bicep version
az bicep build --file "<template>.bicep"
az deployment group what-if --resource-group "<resource-group>" --template-file "<template>.bicep"
```

AWS and CloudFormation static validation examples:

```powershell
aws sts get-caller-identity
aws cloudformation validate-template --template-body file://"<template>.yaml"
```

`aws cloudformation create-change-set` is a credentialed API mutation even though it does not execute the stack change. It creates an environment-scoped CloudFormation resource and requires explicit account, region, stack, change-set name, role, template, parameter, capability, and cleanup context. It MUST NOT be presented as ordinary offline static validation. It requires approved nonproduction or production preview context according to risk. Unused change sets MUST be deleted or expired according to policy. Creation success does not prove execution success or stack readiness. Change-set review MUST include replacement, deletion, IAM capability, nested stack, macro, and unknown behavior. Stack policy, termination protection, rollback configuration, and service role MUST be reviewed where relevant. Secret-bearing parameters MUST NOT appear in command lines or logs.

Credentialed CloudFormation preview creation examples are mutating preview creation, account/region/stack specific, approval controlled, cleanup required, and not ordinary default validation:

```powershell
aws cloudformation create-change-set <approved-placeholder-arguments>
```

Kubernetes and Helm examples:

```powershell
kubectl config current-context
kubectl config view --minify
kubectl apply --dry-run=server -f "<manifest>.yaml"
helm lint "<chart-path>"
helm template "<release>" "<chart-path>" --values "<values-file>"
```

PowerShell examples:

```powershell
Invoke-Pester -Path tests -Output Detailed
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

Commands MUST be valid for supported tooling. Agents MUST NOT invent switches, show secret-bearing arguments, imply execution, or include unconditional apply/destroy commands as ordinary validation. Any apply example MUST be explicitly labeled mutating, approval-required, environment-specific, and outside default validation.

## Documentation And Runbooks

README files, runbooks, and operational docs MUST cover architecture, source of truth, ownership, environment mapping, accounts/subscriptions/projects, regions/zones/clusters/namespaces, state backend, provider/module/tool versions, variables, secrets, identities, network, DNS, certificates, storage, backup/restore, RPO/RTO, HA, monitoring, deployment, approval, rollback, drift, policy, cost, troubleshooting, emergency stop, break glass, maintenance, decommissioning, known limitations, and every public variable, parameter, configuration key, environment variable, workflow input, and operational mode.

Examples MUST be synthetic. Documentation MUST NOT include real credentials, subscription IDs, tenant IDs, project IDs, server names, IP addresses, DNS zones, certificate names, account numbers, kubeconfigs, secrets, keys, customer data, or patient data.

## Completion Evidence

Completion evidence MUST align with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md) and root [../AGENTS.md](../AGENTS.md). Evidence for infrastructure work MUST include exact files changed, exact commands, working directories, tool versions, exit codes, environment, account/subscription/project/tenant, region/zone/cluster/namespace, identity used, state backend, configuration revision, provider/module versions, plan or preview artifact identity, plan summary, create/update/replace/destroy counts, unknown/deferred actions, policy results, secret scan, security scan, drift result or status, cost/quota assessment, approval, backup/recovery, rollback/roll-forward, deployment result, post-deployment verification, GitHub Actions status, artifact verification, remaining risks, exceptions, and all `NotRun` or `Blocked` reasons.

Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. Unexecuted plan, apply, deployment, destroy, restore, failover, DNS, firewall, certificate, cluster, service, or production validation MUST NOT be labeled `Passed`.

## Failure Behavior

Infrastructure work is incomplete when target environment is ambiguous, source of truth is unclear, state backend is unknown, state locking is bypassed, production context relies only on cached defaults, plan or preview is missing where supported, apply uses a different commit/variables/state/environment than the approved plan, plan contains unexplained destroy or replacement, state surgery lacks backup and approval, provider/module/action/image versions float, public exposure is unreviewed, broad ingress or privileged identity lacks approval, secrets or sensitive state are committed or logged, certificate validation is disabled, persistent data lacks backup/recovery, snapshot existence is claimed as restore evidence, backup configured is claimed as restore proven, DNS or traffic cutover lacks rollback, IAM/RBAC is broader than required, production apply occurs from untrusted code, dependency integrity is unverified, Kubernetes workloads are privileged without approval, resource limits or autoscaling are unbounded, drift is ignored, policy failures are bypassed, rollback claims reverse irreversible changes, apply success is treated as readiness, GitHub Actions or deployment success is claimed without evidence, or missing infrastructure validation is relabeled `Passed`.

Agents MUST downgrade completion status to `Failed`, `Blocked`, or `NotRun` when evidence requires it.

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Exceptions MUST be active, scoped, time-bounded, risk-classified, approved, and included in evidence.

Exceptions MUST NOT permit plaintext secrets, fabricated evidence, unreviewed production destroy, ambiguous target environment, hidden production defaults, disabled certificate validation, unbounded public exposure, unbounded privileged access, unbounded autoscaling, state locking bypass without emergency controls, state mutation without backup, missing approval relabeled approved, `NotRun` relabeled `Passed`, untrusted pull-request production mutation, mutable dependency references for protected production paths without compensating controls, suppression of plan destroy/replacement evidence, or permanent policy bypass.

## Related Documents

- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_PowerShell.md](AGENTS_PowerShell.md)
- [AGENTS_DotNet.md](AGENTS_DotNet.md)
- [AGENTS_Database.md](AGENTS_Database.md)
- [AGENTS_WorkerService.md](AGENTS_WorkerService.md)
- [AGENTS_Integration.md](AGENTS_Integration.md)
- [AGENTS_WebFrontend.md](AGENTS_WebFrontend.md)
- [../AGENTS.md](../AGENTS.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)
- [../docs/ADOPTION_GUIDE.md](../docs/ADOPTION_GUIDE.md)
- [../docs/DOWNSTREAM_CONFIGURATION.md](../docs/DOWNSTREAM_CONFIGURATION.md)
- [../docs/ACTION_SECURITY.md](../docs/ACTION_SECURITY.md)
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)

## Revision History

- 1.1.1: Corrected remaining infrastructure gaps by adding explicit IIS controls, Windows Service controls, systemd hardening, DNS/IPAM operational detail, mandatory protected-production image digests, temporary firewall lifecycle, service-account and workload-identity controls, Terraform backendless-plan qualification, CloudFormation change-set mutation warning, and validator/Pester hardening.
- 1.1.0: Rebuilt as a comprehensive enterprise infrastructure standard covering tool applicability, cross-standard handoffs, discovery, risk, execution modes, source of truth, environment targeting, plan/apply separation, approvals, state backends, state migration, supply-chain pinning, naming, destructive changes, storage, networking, DNS/IPAM, IAM/RBAC, secrets, PKI, encryption, compute, services, Kubernetes, databases, backup/DR, HA, drift, policy, cost, observability, deployment, rollback, CI/CD, testing, validation, documentation, evidence, failures, and exceptions.
- 1.0.0: Initial infrastructure standard with baseline requirements for discovery, risk, plans, state, security, destructive changes, validation, evidence, and exceptions.
