# AGENTS Web Frontend Standard

| Field | Value |
| --- | --- |
| Status | Active |
| Version | 1.1.1 |
| Owner role | Engineering Standards Maintainers |
| Last reviewed | 2026-06-21 |
| Changelog | See [../CHANGELOG.md](../CHANGELOG.md). |

## Purpose

This document defines enforceable enterprise requirements for AI agents creating, reviewing, or modifying browser-facing applications, static sites, frontend build systems, client packages, service workers, design systems, component libraries, and browser automation. It inherits [AGENTS_Base.md](AGENTS_Base.md), the repository-root [../AGENTS.md](../AGENTS.md), and all governance documents.

The standard is framework-neutral where practical and applies browser and web-platform controls for security, accessibility, privacy, performance, reliability, validation, and honest completion evidence. Browser code is untrusted from the server's perspective. Client-side validation is not a security boundary. Client-side authorization is not an authorization boundary.

## Applicability And Inheritance

This standard applies to static HTML and CSS, JavaScript, TypeScript, React, Vue, Angular, Svelte, Next.js, Nuxt, Remix, Astro, Blazor WebAssembly frontend assets where browser behavior is involved, single-page applications, multi-page applications, server-rendered frontends, static-site-generated frontends, Progressive Web Apps, service workers, permitted browser extensions, design systems, component libraries, admin portals, dashboards, authentication pages, forms, file uploads, data tables, reports, download interfaces, frontend build systems, package manifests and lockfiles, bundlers and compilers, client-side routing, browser storage, browser security headers and policies, frontend CI/CD, and unit, integration, accessibility, visual, and end-to-end browser tests.

This standard supports enterprise route structures such as `/dashboard`, `/scripts`, `/jobs`, `/reports`, `/admin/scripts`, and `/admin/users`. It also supports browser workflows that submit approved jobs, upload CSV files, display job status, and present report links while keeping authorization and business enforcement on the server.

Cross-standard handoffs are mandatory:

- ASP.NET Core hosting, authentication, authorization, cookies, antiforgery, APIs, Data Protection, Identity, JWT validation, IIS, server configuration, and backend security MUST also apply [AGENTS_DotNet.md](AGENTS_DotNet.md).
- REST, GraphQL, gRPC-web, WebSocket, SignalR, webhook-related UI, vendor API behavior, retry, rate limiting, and external service contracts MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md).
- CDN, reverse proxy, load balancer, TLS termination, DNS, CSP headers, HSTS, hosting, static asset delivery, cache headers, containers, Kubernetes, and infrastructure deployment MUST also apply [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md).
- Job submission, job status, script catalog, cancellation, replay, report links, worker state, and background-processing UI MUST also apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md).
- Database details MUST NOT be exposed directly to the browser. Database-backed application behavior MUST also respect [AGENTS_Database.md](AGENTS_Database.md) through server-side boundaries.
- PowerShell-generated frontend assets, deployment scripts, packaging, IIS automation, and test orchestration MUST also apply [AGENTS_PowerShell.md](AGENTS_PowerShell.md).

Local instructions MAY strengthen this standard. They MUST NOT weaken root, base, security, accessibility, privacy, evidence, review, approval, exception, or validation controls.

## Normative Terminology

The terms MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are used as defined in [AGENTS_Base.md](AGENTS_Base.md). A requirement is complete only when it is implemented, proven already present, recorded as `NotApplicable`, `NotRun`, or `Blocked` with reason, or covered by an approved active exception.

## Required Discovery

Before editing frontend code, agents MUST identify and record the relevant subset of runtime and exact version, Node.js, Deno, Bun, browser-native, or other toolchain, package manager and exact version, lockfile type, install command, framework and exact version, router, rendering model, bundler, compiler or transpiler, TypeScript configuration, CSS strategy, design system, component library, state-management system, client-cache library, form library, validation library, authentication model, session and token model, cookie behavior, browser-storage use, API origins and contracts, CSP, Trusted Types, CORS assumptions, CSRF protections, service workers, third-party scripts, analytics, error reporting, source maps, environment-variable exposure rules, browser support matrix, accessibility target, localization and time-zone behavior, performance budgets, package scripts, lint command, format command, typecheck command, unit-test command, integration-test command, accessibility-test command, E2E or browser-test command, build command, bundle-analysis command, dependency-audit command, production hosting model, and existing user changes from `git status --short`.

Rendering model discovery MUST explicitly identify CSR, SSR, SSG, ISR, hybrid, MPA, or PWA behavior where applicable. Agents MUST inspect `package.json` or equivalent manifest, lockfiles, build configuration, TypeScript configuration, framework configuration, router configuration, existing component patterns, design-system documentation, authentication code, API client code, security headers, service-worker registration, browser storage, environment configuration, CI workflows, existing tests, accessibility tooling, and existing user-visible behavior.

Agents MUST NOT invent package scripts, frameworks, commands, routes, APIs, security headers, auth providers, browser policies, or validation mechanisms that are not present.

## Risk Classification

Frontend work MUST be classified using [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md). Critical by default: client-side handling of privileged credentials, browser exposure of private keys or server secrets, bypassing server-side authorization, storing privileged access tokens in unsafe storage, disabling CSP, Trusted Types, CSRF, cookie protections, TLS validation, or authentication controls, rendering unsanitized attacker-controlled HTML or script, loading arbitrary third-party script, payment or regulated-data flows, cross-tenant data exposure, admin impersonation, service-worker changes capable of persisting malicious or stale code broadly, production dependency or build-chain compromise, disabling security headers, and production release behavior that bypasses integrity or approval controls.

High by default: authentication UI, session handling, token refresh, logout, authorization-sensitive navigation, admin pages, file upload, file download, CSP changes, CORS assumptions, CSRF behavior, redirects, service workers, third-party analytics, dependency upgrades, build-system changes, source-map publication, API-origin changes, error-reporting changes, browser-storage changes, routing changes that affect security or tenancy, and production bundle and deployment changes.

Moderate examples include non-security-sensitive component refactoring, accessibility remediation, performance optimization, test additions, documentation, and visual changes that do not affect semantics, routing, security, data flow, privacy, or build behavior.

Risk MUST be reevaluated when authentication or authorization scope changes, data classification changes, a new third party is introduced, a new script executes in the browser, browser storage changes, public routing changes, admin capabilities change, service-worker scope changes, build or deployment behavior changes, source maps become public, or user data begins flowing to analytics or telemetry.

## Frontend Architecture And Rendering Model

Every frontend MUST declare rendering model, hydration model, routing model, authentication boundary, API boundary, state boundary, cache boundary, error boundary, localization boundary, deployment model, static-asset ownership, browser-only versus server-executed code, trusted versus untrusted content, public versus authenticated routes, administrative routes, and offline behavior.

SSR code and browser code MUST NOT share secrets accidentally. Hydration data MUST NOT expose sensitive server state. Public and private rendering paths MUST be explicit. Framework conventions MUST be followed unless a change is justified. Architectural changes require migration and compatibility review.

## Source Of Truth And Ownership

Frontend projects MUST identify one source of truth for routes, API contracts, design tokens, authentication state, feature flags, and environment configuration. Ownership MUST be defined for generated code, shared components, service workers, analytics, and accessibility requirements.

Duplicate client models that drift from server contracts MUST be avoided. Generated clients MUST identify generator and schema version. Frontend feature flags MUST NOT replace server authorization. Multiple state systems MUST NOT manage the same data without an explicit design. Manual edits to generated code require an approved regeneration strategy.

## Browser Support And Compatibility

Frontend work MUST identify supported browsers, minimum versions, mobile and desktop scope, enterprise browser requirements, polyfill strategy, transpilation target, CSS compatibility strategy, feature detection, graceful degradation, unsupported-browser behavior, and accessibility technology support.

User-agent sniffing SHOULD be avoided when feature detection is possible. New browser APIs require support review. Polyfills require supply-chain and bundle review. Unsupported browsers MUST fail clearly and safely. Compatibility changes require representative testing or a `NotRun` reason.

## Package Manager, Lockfiles, And Reproducible Installation

Every frontend repository MUST define one approved package manager, exact package-manager version or managed mechanism such as Corepack where supported, committed lockfile, frozen or immutable lockfile install in CI, clean install validation, cache behavior, private registry configuration, integrity verification, and a rule prohibiting secrets in package-manager configuration.

No mixed lockfiles are allowed unless an approved monorepo design explains ownership. No production build may use an unlocked dependency graph. Silent lockfile regeneration is prohibited. `npm install` MUST NOT replace `npm ci` in CI without justification. Equivalent frozen-lockfile modes MUST be used for pnpm, Yarn, or other managers. Unexplained lockfile changes are incomplete work. Package-manager upgrades require review. Install scripts require risk review. Production dependencies and development dependencies MUST be correctly classified.

## Dependency And Supply-Chain Integrity

New or changed dependencies MUST be reviewed for package source, publisher, maintainer health, license, vulnerability status, typosquatting risk, install scripts, postinstall scripts, native binaries, WASM, transitive dependencies, bundle impact, browser permissions, network behavior, data collection, release history, abandoned-package risk, provenance or signature where available, and SBOM where required.

Dependencies MUST NOT be added for trivial behavior without justification. Floating URLs and unversioned CDN assets are prohibited for protected production paths. Packages from untrusted registries are prohibited. Dependency confusion risks MUST be considered. Audit results require review, not automatic blind fixes. `npm audit fix --force` or equivalent MUST NOT be run automatically. Major dependency upgrades require breaking-change review. Lockfile integrity MUST remain intact. Build tools and test tools are part of the supply chain.

## Build, Bundling, And Compiler Configuration

Build configuration MUST define build mode, minification, tree shaking, code splitting, chunk naming, asset hashing, cache busting, source maps, environment replacement, public path or base path, API base path, CSS processing, static asset handling, image optimization, bundle budget, build reproducibility, build metadata, version stamping, and error behavior.

Production builds MUST use production configuration. Development flags MUST NOT leak to production. Build-time secret injection is prohibited. Public base paths MUST support deployed subpaths where required. Minification success is not functional validation. Build warnings affecting correctness or security MUST be reviewed. Asset hashes MUST change when content changes. Generated bundles MUST NOT be hand-edited. Build output MUST NOT be committed unless repository policy explicitly requires it.

## Environment Variables And Configuration Exposure

Frontend configuration MUST distinguish public browser variables from server-only secrets. Public browser variable names MUST be allowlisted. Environment validation, safe defaults, no production fallback, environment-specific API origins, build-time versus runtime configuration, tenant-safe configuration, configuration schema, startup or build validation, and documentation MUST be defined.

Every value embedded in a browser bundle MUST be treated as public. Prefixes such as `NEXT_PUBLIC_`, `VITE_`, or framework equivalents do not make values secret. Browser code MUST NOT contain private keys, database credentials, client secrets, server API keys, signing keys, privileged tokens, or internal-only connection strings. Missing environment configuration MUST fail safely. Environment values from query strings, local storage, or untrusted origins MUST NOT select privileged backends. API-origin switching MUST use allowlists. Production configuration MUST NOT silently fall back to localhost, test, staging, or another tenant.

## Authentication And Session Handling

Authentication work MUST define provider, login flow, logout flow, session establishment, session expiration, renewal or refresh, multi-tab behavior, revocation, idle timeout, absolute timeout, error handling, redirect behavior, account-switch behavior, MFA behavior, reauthentication for sensitive actions, server enforcement, and accessibility of auth flows.

Authentication MUST be enforced server-side. Frontend route guards are UX controls only. Tokens and session data MUST NOT appear in URLs. Logout MUST clear browser-accessible session state and invoke server or provider logout as required. Session expiry MUST NOT silently retain privileged UI. Refresh logic MUST avoid infinite loops and token storms. Authentication errors MUST NOT leak sensitive details. Login redirects MUST be allowlisted. Post-login return URLs MUST be validated. Reauthentication is required for high-risk actions where policy requires it. Authentication state MUST handle multiple tabs or windows safely. Frontend code MUST NOT impersonate server authorization.

Every OAuth/OIDC browser flow MUST define identity provider and client type, public versus confidential client classification, authorization and token endpoints, redirect URI and post-logout redirect URI, response type and response mode, scopes and audience or resource, PKCE, state, and nonce behavior, session cookie behavior, token storage and refresh strategy, rotation, revocation, logout, multi-tab and account-switch behavior, reauthentication behavior, error handling, transaction identifiers, and tenant or provider selection rules. Public browser clients MUST use Authorization Code flow with PKCE where OAuth/OIDC is used and the provider supports it. Implicit flow MUST NOT be used for new browser applications. Resource Owner Password Credentials flow MUST NOT be used for browser applications.

OAuth state MUST be high entropy, transaction-bound, validated on return, and consumed once. OIDC nonce MUST be generated, transaction-bound, validated, and consumed once when ID tokens are used. Redirect URIs MUST be exact, allowlisted, environment-specific, and registered. Wildcard redirect URIs are prohibited for protected production clients. Return URLs MUST be validated separately from identity-provider redirect URIs. Tokens MUST NOT appear in query strings, fragments, browser history, referrers, analytics, or logs. ID tokens MUST NOT be treated as API access tokens unless the provider contract explicitly defines that use. Issuer, audience, authorized party/client, expiration, not-before, nonce, signature, and token type MUST be validated by the appropriate trusted backend or approved library. Browser code MUST NOT implement custom cryptographic token verification when approved platform libraries exist.

Refresh tokens require provider support, rotation, reuse detection where available, bounded lifetime, revocation, and approved storage. Refresh-token reuse or rotation failure MUST fail safely and require reauthentication. Refresh logic MUST prevent refresh storms. Session fixation MUST be prevented by rotating or replacing session state at login and privilege elevation where applicable. Account or tenant switching MUST clear prior identity, cache, and authorization state. Callback handling MUST reject unexpected state, nonce, issuer, audience, tenant, client, response type, response mode, code, or redirect context. OAuth errors MUST not expose codes, tokens, client secrets, PII, or sensitive provider details.

## Authorization And Privilege Boundaries

Authorization-sensitive frontend work MUST define server-authoritative roles and permissions, route visibility rules, action visibility rules, admin boundary, tenant boundary, object-level authorization, feature flags, audit-sensitive actions, and unauthorized-state handling.

Hiding a button is not authorization. Disabling a control is not authorization. Client-side role checks MUST NOT be the only enforcement. Object IDs from the browser are untrusted. Admin routes MUST be server-protected and direct navigation to admin routes MUST receive server denial when unauthorized. Cross-tenant identifiers MUST NOT be accepted without server validation. Empty input MUST NOT mean all targets. Frontend optimistic updates MUST NOT imply authorization success before server confirmation. UI MUST NOT reveal unauthorized sensitive metadata through labels, counts, links, or error messages.

## Cookies, Tokens, And Browser Storage

Cookie, token, and storage designs MUST define cookie names, `Secure`, `HttpOnly`, `SameSite`, path, domain, lifetime, rotation, deletion, storage location, threat model, XSS impact, CSRF impact, multi-tab behavior, and logout behavior.

Sensitive session tokens SHOULD use Secure, HttpOnly cookies where architecture supports it. Privileged or long-lived tokens MUST NOT be stored in localStorage or sessionStorage unless an approved threat model and exception require it. IndexedDB, Cache Storage, localStorage, sessionStorage, and in-memory caches MUST be classified by data sensitivity, user, tenant, and logout behavior. Browser storage MUST NOT cross user or tenant boundaries. Logout MUST clear protected browser caches and storage. Client-side encryption does not make browser storage a secret store when keys are also available to the browser.

## Cross-Site Scripting And HTML Injection

User-controlled content MUST be rendered through safe framework escaping or approved sanitization. Untrusted HTML MUST NOT be inserted directly. Dangerous APIs and bypasses such as `dangerouslySetInnerHTML`, Angular sanitizer bypasses, direct `innerHTML`, `outerHTML`, `insertAdjacentHTML`, document writes, unsafe template compilation, unsafe markdown rendering, DOM clobbering, and script URL injection require security review and tests.

Sanitization MUST be centralized, configured for the allowed content model, and tested with XSS payloads. CSV previews, report views, markdown, rich text, imported HTML, error messages, and translated strings MUST be treated as untrusted unless proven otherwise.

## Trusted Types And DOM Safety

Trusted Types SHOULD be used for applications with material DOM injection risk where browser and framework support allow it. Where Trusted Types is used, policies MUST be named, minimal, reviewed, and enforced through CSP where practical. DOM sinks MUST be inventoried when bypass APIs are introduced. Trusted Types bypasses require security review and completion evidence.

## Content Security Policy

CSP MUST be governed as a security control. Changes MUST define directives, script policy, style policy, image/media/font/connect policies, frame and worker policies, reporting endpoint, nonce/hash strategy, Trusted Types behavior where applicable, third-party allowances, environment differences, and rollout mode.

CSP MUST NOT be disabled for convenience. `unsafe-inline`, `unsafe-eval`, wildcard origins, broad `connect-src`, broad `frame-ancestors`, and permanent report-only bypasses require High or Critical review. CSP success does not prove XSS safety, and CSP failures must not be ignored.

Every CSP MUST define, where applicable, delivery mechanism, `default-src`, `script-src`, `script-src-elem`, `script-src-attr`, `style-src`, `style-src-elem`, `style-src-attr`, `img-src`, `font-src`, `connect-src`, `media-src`, `frame-src`, `frame-ancestors`, `object-src`, `base-uri`, `form-action`, `worker-src`, `manifest-src`, `child-src` for required legacy compatibility, Trusted Types directives, reporting configuration, nonce and hash strategy, third-party sources, environment differences, report-only rollout, enforcement rollout, violation ownership, and triage process.

`default-src` MUST be explicit for protected applications. `object-src 'none'` SHOULD be used unless a reviewed requirement exists. `base-uri` MUST restrict base URL manipulation. `form-action` MUST restrict submission destinations. `frame-ancestors` MUST define clickjacking protection. `connect-src` MUST explicitly cover approved API, WebSocket, telemetry, and worker destinations. `worker-src` MUST govern service workers and other workers where supported. `manifest-src` MUST be defined for PWAs. Nonces MUST be unpredictable and request-scoped. Static or reusable nonces are prohibited. CSP hashes MUST match reviewed immutable content. `unsafe-inline`, `unsafe-eval`, wildcard hosts, scheme-wide allowances, and broad data/blob sources require High or Critical review. Report-only mode MUST have an owner, review period, remediation process, and enforcement target date. Report-only mode MUST NOT remain permanent without an approved exception. CSP reports MUST NOT receive secrets or protected payloads. Violations MUST be triaged without automatically weakening policy. CSP changes require deployed header/runtime verification where possible. CSP delivery MUST remain aligned with [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md) hosting controls.

## CSRF

Cookie-authenticated state-changing requests MUST have CSRF protection enforced by the server or an approved equivalent design. Frontend code MUST carry antiforgery tokens or headers according to the server contract. SameSite cookies, custom headers, and CORS are not a universal substitute for CSRF review. Cookie-authenticated POST requests need CSRF protection unless an approved design proves otherwise.

CSRF-sensitive work MUST define antiforgery mechanism, issuance, binding, transport, rotation, expiration, SameSite assumptions, login CSRF behavior, logout CSRF behavior, multi-tab behavior, failure response, retry behavior, reauthentication behavior, and backend ownership. GET, HEAD, OPTIONS, and other safe methods MUST NOT perform state-changing business actions. Login endpoints MUST address login CSRF and account-confusion risks. Logout endpoints MUST address logout CSRF according to the threat model. Tokens MUST be scoped and validated according to the server framework contract. Tokens MUST NOT be accepted from untrusted origins. Rotation behavior MUST be defined for login, logout, privilege change, renewal, and session rotation where applicable. Failed CSRF validation MUST fail closed. Failed CSRF validation MUST NOT automatically retry the mutation. Frontend handling MUST distinguish CSRF failure from validation and network failure. Retry loops after antiforgery-related 400, 401, or 403 responses are prohibited. Tokens MUST NOT be logged, analyzed, or placed in URLs. Frontend and backend token names, headers, cookies, and rotation behavior MUST remain synchronized.

## CORS And Cross-Origin Behavior

CORS MUST NOT be treated as authorization. CORS changes MUST define allowed origins, methods, headers, credentials, preflight behavior, exposed headers, environment differences, and server enforcement. Wildcard origins with credentials are prohibited. Browser success does not prove an API is authorized correctly.

CORS and cross-origin changes MUST define exact allowed origins including scheme, host, and port, normalization and boundary-safe matching, environment separation, credentials mode, methods, headers, exposed headers, preflight behavior, preflight cache duration, redirect and cookie behavior, WebSocket/SignalR origin behavior, development proxy behavior, error handling, and ownership. Dynamic origin reflection MUST use a strict allowlist. Blind Origin reflection is prohibited. Suffix matching without a hostname boundary is prohibited. Production allowlists MUST NOT silently include localhost, loopback, development domains, wildcard ports, preview domains, or test origins. `*` MUST NOT be combined with credentials. Preflight caching MUST be reviewed for policy-change and revocation behavior. Cross-origin redirects require credential, cookie, authorization-header, and origin review. WebSocket and SignalR endpoints MUST validate Origin where required by platform and threat model. WebSocket upgrade success does not prove authorization. Unsafe public CORS proxies or ad hoc relay services are prohibited. Development proxy configuration MUST NOT be treated as production CORS configuration. Credential mode MUST match the approved server contract. Cross-site cookies require SameSite, Secure, domain, and CSRF review. Allowed-origin configuration MUST be environment-specific and validated at startup or deployment.

## URL, Redirect, Navigation, And Opener Safety

URL construction MUST use safe parsers and protocol allowlists. `javascript:`, `data:`, and other active or unexpected protocols MUST be rejected unless a reviewed use case explicitly permits them. Open redirects are prohibited unless targets are allowlisted and validated. Login return URLs, download links, report links, and external navigation MUST be validated.

External links using `target="_blank"` MUST use safe opener protection such as `rel="noopener noreferrer"` unless framework behavior proves equivalent. Navigation that crosses tenant, account, admin, or privilege boundaries requires server verification.

## Forms And Input Validation

Forms MUST be accessible, labeled, keyboard operable, error-associated, resilient to refresh and duplicate submission, and clear about validation state. Client-side validation is for usability only and MUST NOT replace server validation. Empty scope, empty target, empty filter, or missing file input MUST NOT mean all targets. Destructive or broad forms require confirmation, preview, and server-side authorization.

## File Upload And Download Interfaces

File upload UI MUST define accepted types, size limits, count limits, preview behavior, client validation, server validation, malware scanning expectation where applicable, storage location, progress, cancellation, retry, duplicate handling, error handling, and privacy. Browser file validation is insufficient by itself. CSV and spreadsheet previews MUST escape formula-like values and HTML. Uploads for job execution MUST preserve immutable approved input identity.

Protected downloads and report links MUST require server-side access-time authorization. Public report URLs are prohibited for protected data unless an approved signed, scoped, expiring design is used. Download filenames and content disposition MUST avoid injection and sensitive data leakage. Report links MUST NOT appear as final before artifact readiness and authorization are proven.

User filenames MUST NOT become server filesystem paths. Display filenames and server storage identities MUST be separate. HTML, SVG, XML, PDF, Office files, archives, and other active or complex formats require type-specific review. Uploaded HTML or SVG MUST NOT render inline in a privileged application origin unless sanitized, isolated, and approved. Previews MUST use safe rendering or sandboxed isolation. CSV import previews MUST escape HTML and formula-like cells. CSV exports MUST address spreadsheet formula injection for values beginning with `=`, `+`, `-`, `@`, tab, carriage return, or other spreadsheet-interpreted prefixes. Client MIME and extension checks are advisory only. Server MIME, extension, content, size, count, schema, row count, authorization, tenant, malware scan, and immutable-input validation remain authoritative. Archive traversal, bombs, nested archives, and excessive file counts MUST be governed server-side. Transfer success MUST NOT be displayed as processing, approval, or job success. Approved input replacement MUST create a new version, hash, or job identity.

Downloads MUST define server-authoritative Content-Type, Content-Disposition, safe filename, `X-Content-Type-Options: nosniff`, authorization and tenant/user boundary, artifact, job, attempt, and version identity, integrity hash where available, size, expiration, cache policy, and inline/attachment behavior. Safety MUST NOT be inferred from extension alone. HTML and SVG downloads are active content. Protected active content SHOULD be attachment-only or isolated on a non-privileged origin where appropriate. Expired, revoked, wrong-tenant, wrong-attempt, wrong-version, or mismatched artifacts MUST fail safely. Hash mismatch MUST fail closed where hashes are provided. Internal filesystem paths MUST NOT reach the browser. Download errors MUST NOT expose provider internals, signed URL details, or server paths. Cache headers MUST match sensitivity.

## API Clients And Data Contracts

API clients MUST define API origin, contract source, generated-client ownership, schema version, timeout, cancellation, retry, backoff, rate-limit behavior, idempotency behavior, error contract, authentication behavior, authorization failure behavior, validation failure behavior, partial-success behavior, and telemetry. API clients MUST also apply [AGENTS_Integration.md](AGENTS_Integration.md).

Retries MUST not duplicate non-idempotent operations. Abort or cancellation MUST be supported for long-running browser requests where feasible. Client contracts MUST not silently drift from server contracts. Error handling MUST distinguish validation failure, authentication failure, authorization failure, timeout, rate limit, network failure, and server failure without leaking sensitive data.

API contracts MUST define HTTP status and business outcome, error/problem contract, schema and media type version, required and optional fields, nullability, enum and unknown-enum behavior, date/time, time zone, duration, numeric precision, pagination, filtering, sorting, search, continuation tokens, correlation IDs, idempotency keys, retry safety, partial success, warnings, validation, authentication, authorization, rate-limit, timeout, cancellation behavior, and compatibility across rolling deployments. HTTP 2xx MUST NOT automatically mean full business success. The documented result contract MUST be evaluated. Partial success MUST remain explicit. Failed items MUST NOT be displayed as full success. API responses are untrusted input. Unknown enums MUST fail safely and MUST NOT map to privileged defaults. Missing required fields and schema-version mismatches MUST fail safely. Nullability mismatches MUST NOT be silently coerced when meaning changes. Date/time formats MUST be explicit and unambiguous, with time-zone interpretation defined. Pagination MUST define maximum size, stable ordering, continuation behavior, and duplicate/missing-item behavior. Filtering and sorting remain server-validated. Continuation tokens are opaque. State-changing retries require documented idempotency support. Idempotency keys MUST be unique, scoped, retained, and interpreted according to the server contract. Blind retry of non-idempotent requests is prohibited. Client cancellation does not prove server cancellation. Correlation IDs MUST be safe to display and log. Error bodies MUST NOT render directly as HTML. Generated clients MUST remain synchronized with the authoritative schema and generator version.

## Error Handling And Sensitive-Data Protection

Frontend errors MUST avoid exposing secrets, tokens, stack traces, internal hostnames, customer data, patient data, tenant data, or authorization details. User-facing messages SHOULD be actionable without disclosing protected internals. Error boundaries MUST handle expected rendering and data failures. Logs, telemetry, screenshots, traces, and error reports MUST redact sensitive payloads.

## State Management And Client Caching

State and cache designs MUST define ownership, scope, key structure, tenant and user partitioning, invalidation, refresh, optimistic update behavior, rollback, persistence, logout cleanup, stale-data policy, and sensitive-data classification. Tenant-safe cache keys are mandatory for multi-tenant or account-scoped data. Cache keys need tenant and user scope where data is scoped to tenant or user. Logout MUST clear protected caches. Account switch MUST not reuse protected cached data from another account or tenant.

## Routing And Deep Linking

Routes MUST identify public, authenticated, administrative, tenant-scoped, report, download, and job-related paths. Direct navigation and refresh MUST be tested for critical protected routes. Client route guards are UX only; server responses MUST enforce denial. Route parameters from the browser are untrusted. Admin routes MUST not reveal protected metadata through preload, title, breadcrumb, menu, count, or error states.

## Service Workers, PWA, And Offline Behavior

Service-worker and PWA changes MUST define scope, registration, update strategy, cache names, cache content, offline behavior, precache/runtime cache rules, API caching, protected-data handling, logout cleanup, versioning, stale-worker recovery, skip-waiting behavior, rollback, and browser compatibility.

Service workers MUST NOT cache protected API data by default. Service workers may persist stale or malicious behavior broadly and are High by default. Service-worker updates MUST not strand users on incompatible assets. Offline behavior MUST not show protected stale data after logout or account switch. Cache deletion and migration behavior MUST be tested or recorded as `NotRun`.

Service-worker work MUST define script identity, scope, registration path, allowed scope, versioned cache namespaces, precache manifests, runtime caching rules, executable asset integrity, installation, activation, update, atomic migration, cleanup, rollback, recovery, cache-poisoning threat model, authentication behavior, CSP behavior, tenant behavior, logout behavior, offline behavior, and observability. Scope MUST be no broader than required. `Service-Worker-Allowed` broadening requires review. Workers MUST NOT bypass auth, authorization, CSP, Trusted Types, or server controls. Cached executable assets MUST match the approved release identity. Precache manifests and script/style assets require integrity or immutable release controls. Cache keys MUST prevent user, tenant, environment, and release crossover. Runtime caching MUST validate method, destination, origin, credentials, status, content type, and cacheability. Opaque cross-origin responses require review before caching. Cache poisoning through URLs, query strings, redirects, headers, or compromised upstream content MUST be considered. Authentication pages, logout responses, antiforgery responses, token endpoints, and protected API responses MUST NOT be cached without an approved design. Cache migration SHOULD be atomic. New activation MUST NOT expose incompatible HTML, JavaScript, CSS, API, or cache versions. Old caches SHOULD be removed only after the new version is ready according to the strategy. Faulty active workers require documented recovery, such as unregister, rollback, cache purge, or approved equivalent. `skipWaiting` and `clients.claim` require compatibility review. Update failures MUST be observable. Offline fallback MUST NOT show protected stale data after logout, revocation, tenant switch, or permission change. Worker scripts and manifests MUST NOT load from mutable untrusted origins.

## Third-Party Scripts, Analytics, And Privacy

Third-party scripts, analytics, tag managers, pixels, chat widgets, maps, fonts, and embedded media require source, owner, purpose, data collected, privacy review, consent behavior, regional behavior, CSP changes, SRI or integrity options, network destinations, performance impact, failure behavior, and removal plan.

Third-party scripts need privacy review before use. Arbitrary third-party script execution is prohibited. Analytics MUST NOT collect secrets, tokens, regulated data, protected user content, or unauthorized identifiers. Consent and opt-out behavior MUST be respected where required. Tag managers MUST NOT become uncontrolled code execution paths.

## Subresource Integrity And External Assets

External assets for protected production paths MUST use pinned versions and Subresource Integrity where supported, or an approved equivalent integrity control. Floating external assets, unversioned CDN URLs, and mutable script URLs are prohibited for protected production paths. SRI hashes MUST match reviewed content and be updated intentionally.

## Accessibility

Frontend work MUST target WCAG 2.2 AA unless a stricter local requirement applies. Interactive UI MUST preserve semantic HTML, accessible names, labels, roles, keyboard navigation, visible focus, logical focus order, skip links where appropriate, contrast, reduced-motion behavior, error identification, form associations, status announcements, screen-reader behavior, touch target usability, and zoom/responsive behavior.

Accessibility is not optional. Components MUST not trap focus unintentionally. Modals, menus, comboboxes, tabs, dialogs, toasts, data grids, upload controls, and error summaries require keyboard and assistive-technology review. Automated accessibility success does not prove complete accessibility; manual review is required for critical journeys where automation cannot verify behavior.

## Design Systems And Component Behavior

Design-system changes MUST define token ownership, component API stability, accessibility contract, theming, density, responsive behavior, localization, versioning, deprecation, and migration. Shared components MUST not encode product-specific authorization decisions unless explicitly designed. Component props that accept HTML, URLs, render callbacks, or external targets require security review.

## Responsive Design And Device Support

Responsive behavior MUST be validated against the supported browser and device matrix where practical. Layout changes MUST account for mobile, desktop, zoom, reduced motion, high contrast, text scaling, pointer type, keyboard-only use, and viewport changes. Critical controls MUST remain reachable and readable.

## Internationalization, Localization, And Time Zones

Text, numbers, dates, times, currencies, sorting, pluralization, right-to-left layout, and time zones MUST follow the product localization model. Time-zone conversions MUST be explicit. User locale MUST not be trusted as authorization or tenancy input. Translated strings MUST be treated as untrusted unless the translation pipeline is trusted and controlled.

## Performance And Web Vitals

Frontend work SHOULD define performance budgets for bundle size, route chunks, image size, font loading, hydration, interaction latency, and Core Web Vitals or equivalent metrics where applicable. Performance-sensitive changes SHOULD include measurement or a `NotRun` reason. New dependencies, third-party scripts, large assets, blocking scripts, unbounded rendering, and excessive client caching require performance review.

## Reliability, Loading, Empty, Error, And Retry States

User workflows MUST define loading, empty, error, partial success, retry, cancellation, duplicate submission, offline, timeout, rate-limit, authorization failure, authentication failure, and stale-data states where applicable. Build success does not prove browser behavior. Retry behavior MUST be bounded and visible when user action is required.

Job polling MUST define initial, normal, and maximum intervals, backoff and jitter, timeout and maximum duration, terminal and unknown states, visibility/background-tab behavior, offline behavior, navigation and component-disposal cancellation, authentication expiry, rate limits, Retry-After handling, duplicate poll prevention, multi-tab behavior, job ID, attempt number, correlation ID, artifact readiness, cancellation request state, and cancellation acknowledgement state. Poll intervals MUST be bounded. Failure polling MUST use appropriate backoff and jitter. Tight or zero-delay loops are prohibited. Polling MUST stop on terminal states. Unknown states MUST follow a safe documented compatibility rule. Polling MUST cancel on navigation, logout, account switch, component disposal, or lost authorization where applicable. Background-tab polling SHOULD reduce or suspend where practical. Visibility changes MUST NOT create duplicate loops. Multiple tabs MUST NOT create unbounded duplicate load. Retry-After SHOULD be respected where safe. Rate limits MUST NOT cause tighter polling.

A cancellation request MUST NOT be displayed as completed until the server confirms terminal cancellation. Client request cancellation does not prove job cancellation. A job MUST NOT be shown completed until the server reports terminal completion. Report links MUST NOT appear before required artifact finalization and authorization. Stale responses from prior attempts MUST NOT overwrite current state. Out-of-order responses MUST NOT regress terminal state. Polling MUST NOT continue indefinitely without visible timeout or recovery. Cancellation, replay, retry, and report-link behavior MUST also apply [AGENTS_WorkerService.md](AGENTS_WorkerService.md).

## Observability And Client Telemetry

Client telemetry MUST define events, owner, purpose, sampling, consent, redaction, retention, destinations, correlation IDs, error grouping, release version, source-map association, and privacy review. Telemetry MUST NOT include secrets, tokens, raw regulated data, protected document contents, or unauthorized identifiers. Error reporting changes are High by default.

Telemetry failure MUST NOT break core UI. Telemetry transport MUST have bounded timeouts and failure handling. Console logs MUST NOT contain secrets, tokens, passwords, authorization headers, private keys, regulated data, uploads, or sensitive responses. Debug logging MUST be disabled in protected production builds unless approved. Correlation IDs MUST be opaque, safe, and non-secret. User and tenant identifiers MUST be minimized, pseudonymized, or omitted according to policy. Events MUST identify frontend release and environment. Telemetry endpoints MUST be allowlisted in CSP and configuration. Telemetry SDKs require supply-chain and privacy review. Offline telemetry queues MUST be bounded and non-sensitive. Consent and opt-out MUST be honored before nonessential telemetry where required.

## Source Maps And Debugging Artifacts

Source-map policy MUST define generation, publication, access control, retention, upload destination, release association, and sensitive-data review. Production source maps MUST NOT be public without review and approval. Debug builds, verbose logs, development overlays, test IDs containing sensitive information, and unminified protected production bundles require review.

Every production source map MUST associate with the exact source revision, release identifier, bundle filename, and content hash where supported. Maps MUST match deployed bundles. Maps and bundles MUST be secret-scanned before publication or upload. Upload success MUST be verified independently from deployment success. Provider upload MUST NOT make maps publicly reachable. Hidden maps still require protected storage, retention, and access control. Public maps require explicit review and approval. Retention MUST align with release support and incident requirements. Rollback MUST preserve exact matching prior maps. Error-reporting release identifiers MUST match deployed release identifiers. Mismatched maps MUST fail deployment verification or be reported as a defect. Provider credentials remain server-side or in protected CI.

## Testing Requirements

Frontend changes MUST include applicable tests or justified statuses. Tests SHOULD cover pure logic, component states, forms, validation, routing, authentication, authorization-sensitive visibility, direct navigation, admin routes, tenant boundaries, API success, API validation failure, authentication failure, authorization failure, timeout, rate limit, offline behavior, loading, empty state, error state, partial success, cancellation, duplicate submission, file upload, file download, CSV preview escaping, XSS payloads, unsafe URLs, redirect allowlists, CSP compatibility, Trusted Types where used, CSRF behavior, browser storage cleanup, logout, account switch, service-worker updates, accessibility, keyboard navigation, focus management, responsive behavior, localization, bundle build, dependency audit, browser compatibility, and source-map policy.

Tests MUST use synthetic data, test accounts, nonproduction APIs, mock servers, contract fixtures, local browser automation, isolated test storage, harmless uploads, and approved accessibility tooling. Never use production merely because nonproduction is unavailable.

## Browser And E2E Automation

Browser automation MUST define approved tool such as Playwright, Selenium, Cypress, WebdriverIO, or repository-standard equivalent, browser versions, base URL, test environment, test identity, seed data, isolation, cleanup, screenshots, video or trace retention, secret redaction, retry behavior, parallelism, flake handling, accessibility integration, and artifact review.

Browser tests MUST NOT target production by default. Tests MUST NOT use real privileged credentials. Screenshots, videos, traces, and HAR files may contain sensitive data and MUST be protected. Retries MUST NOT hide deterministic failures. Flaky tests MUST NOT be ignored permanently. Critical journeys require direct-navigation and refresh tests. Authentication tests MUST verify server denial, not only hidden UI. Browser-test success does not prove every supported browser unless the matrix ran. Missing browser binaries or services are `NotRun` or `Blocked`.

## Validation Commands

Repository-root [../AGENTS.md](../AGENTS.md) is the source of truth for repository validation. Commands are conditional on actual package manager, scripts, framework, browsers, feeds, APIs, authentication, and test environments. Exact command, working directory, tool version, exit code, test count, summary, and status MUST be recorded. Missing browsers, feeds, APIs, authentication, or test environments are `NotRun` or `Blocked`. Build success does not prove browser behavior. Automated accessibility success does not prove complete accessibility. Dependency audit warnings require review. Agents MUST NOT invent scripts.

npm examples:

```powershell
node --version
npm --version
npm ci
npm run lint
npm run typecheck
npm test
npm run build
npm audit
```

pnpm examples:

```powershell
node --version
pnpm --version
pnpm install --frozen-lockfile
pnpm run lint
pnpm run typecheck
pnpm test
pnpm run build
pnpm audit
```

Yarn examples:

```powershell
node --version
yarn --version
yarn install --immutable
yarn lint
yarn typecheck
yarn test
yarn build
yarn npm audit
```

Browser and E2E examples only where configured:

```powershell
npx playwright test
npx playwright test --project="<configured-project>"
```

Accessibility examples only where configured:

```powershell
npm run test:a11y
```

Bundle analysis examples only where configured:

```powershell
npm run analyze
```

Use the repository's actual scripts. Do not add fake scripts that only print success. Do not use `npm install` in CI when `npm ci` is required. Do not run automated force-upgrades for audit findings. Do not claim E2E, accessibility, performance, or browser compatibility without executed evidence.

## Deployment And Hosting

Frontend deployment MUST define hosting platform, base path, asset path, API origin, CDN, cache headers, compression, TLS, HSTS, CSP, security headers, source-map policy, service-worker scope, release identifier, rollback, health or smoke validation, environment configuration, and static asset invalidation.

Frontend deployment MUST also apply [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md). Deployment success is not application readiness. Static asset and HTML caching MUST avoid incompatible version mixing. Hashed immutable assets SHOULD use long caching. HTML and service-worker caching MUST support safe updates. Rollback MUST account for API compatibility and cached assets. Base-path hosting MUST be tested where applicable. Security headers MUST be verified from the deployed response. Production deployment MUST NOT publish development builds. Release artifacts MUST be immutable and associated with exact source revision.

## Documentation Requirements

README and frontend documentation MUST include runtime, package manager, install command, framework, rendering model, routes, authentication model, authorization assumptions, API origins, environment variables, public-variable warning, build command, test commands, E2E command, accessibility command, browser support, CSP, CSRF, CORS assumptions, storage use, service workers, analytics, source maps, performance budgets, deployment, base path, troubleshooting, known limitations, and every public script, environment variable, route parameter, feature flag, and operational mode.

Examples MUST be synthetic and MUST NOT include real credentials, API keys, tokens, tenant IDs, production hostnames, customer data, patient data, private routes, internal URLs, or secrets.

## Completion Evidence

Completion evidence MUST align with [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md) and root [../AGENTS.md](../AGENTS.md). Evidence MUST include exact files changed, exact commands, working directories, Node/runtime version, package-manager version, lockfile, install result, lint result, format result where applicable, typecheck result, unit-test result, integration-test result, browser/E2E result, accessibility result, build result, bundle result, dependency-audit result, browser matrix, CSP/Trusted Types result where applicable, CSRF result where applicable, authentication/authorization result, storage/logout result, service-worker result, source-map result, deployment result, GitHub Actions status, artifact verification, screenshots/traces reviewed, remaining risks, exceptions, and all `NotRun` or `Blocked` reasons.

Permitted statuses are `Passed`, `Failed`, `Blocked`, `NotRun`, and `NotApplicable`. Unexecuted browser, accessibility, performance, security-policy, deployment, or production validation MUST NOT be labeled `Passed`.

## Failure Behavior

Frontend work is incomplete when package manager or lockfile is ambiguous, install is not reproducible, lockfile changes are unexplained, client secrets are introduced, public variables are mistaken for secrets, authentication is enforced only in the browser, authorization is enforced only by hidden or disabled UI, privileged tokens are stored unsafely, untrusted HTML is rendered without approved sanitization, unsafe URLs or redirects are accepted, CSP is weakened without review, CSRF protections are absent for cookie-authenticated mutations, CORS is treated as authorization, browser storage crosses user or tenant boundaries, logout leaves protected cached data, uploads rely only on browser validation, downloads expose protected artifacts without access-time authorization, report links appear before artifact readiness, service workers cache protected data unsafely, third-party scripts are added without review, accessibility regressions are ignored, production source maps are exposed without review, build success is treated as browser success, automated accessibility success is treated as complete manual accessibility proof, browser tests target production because test infrastructure is missing, audit findings are force-fixed without review, missing validation is relabeled `Passed`, or evidence claims tests or browsers ran without command output.

## Exception Handling

Exceptions MUST follow [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md). Exceptions MUST NOT permit plaintext browser secrets, fabricated evidence, client-only authorization, unsanitized attacker-controlled HTML, arbitrary third-party script execution, disabled certificate validation, unbounded open redirects, cross-tenant storage leakage, public privileged tokens, missing security review relabeled as approved, `NotRun` relabeled `Passed`, production used as the default test environment, permanent CSP bypass, permanent accessibility exclusion for critical journeys, or mutable untrusted production dependencies without compensating controls.

Exceptions MUST be active, scoped, time-bounded, risk-classified, approved, and included in completion evidence.

## Related Documents

- [../AGENTS.md](../AGENTS.md)
- [AGENTS_Base.md](AGENTS_Base.md)
- [AGENTS_DotNet.md](AGENTS_DotNet.md)
- [AGENTS_Integration.md](AGENTS_Integration.md)
- [AGENTS_Infrastructure.md](AGENTS_Infrastructure.md)
- [AGENTS_WorkerService.md](AGENTS_WorkerService.md)
- [AGENTS_Database.md](AGENTS_Database.md)
- [AGENTS_PowerShell.md](AGENTS_PowerShell.md)
- [../governance/ORGANIZATION_CONTRACT.md](../governance/ORGANIZATION_CONTRACT.md)
- [../governance/COMPLETION_EVIDENCE.md](../governance/COMPLETION_EVIDENCE.md)
- [../governance/RISK_CLASSIFICATION.md](../governance/RISK_CLASSIFICATION.md)
- [../governance/EXCEPTION_PROCESS.md](../governance/EXCEPTION_PROCESS.md)
- [../governance/AI_GENERATED_CODE_POLICY.md](../governance/AI_GENERATED_CODE_POLICY.md)

## Revision History

- 1.1.1: Corrected remaining Web Frontend gaps by adding OAuth/OIDC browser-flow controls, directive-level CSP requirements, CSRF lifecycle and failure behavior, CORS/WebSocket hardening, upload/download active-content and integrity controls, API contract semantics, job polling and cancellation semantics, service-worker cache-poisoning and integrity controls, telemetry/source-map release integrity, and validator/Pester hardening.
- 1.1.0: Rebuilt as a comprehensive enterprise Web Frontend standard covering applicability, cross-standard handoffs, discovery, risk, rendering models, ownership, browser support, package-manager and lockfile reproducibility, dependency supply chain, build configuration, environment exposure, authentication, authorization, cookies, tokens, storage, XSS, Trusted Types, CSP, CSRF, CORS, URLs, redirects, forms, uploads, downloads, API clients, cache and routing, service workers, third-party scripts, SRI, accessibility, responsive design, localization, performance, reliability, telemetry, source maps, testing, browser automation, validation commands, deployment, documentation, evidence, failures, and exceptions.
- 1.0.0: Initial Web Frontend standard with baseline security, accessibility, testing, validation, evidence, and exception requirements.
