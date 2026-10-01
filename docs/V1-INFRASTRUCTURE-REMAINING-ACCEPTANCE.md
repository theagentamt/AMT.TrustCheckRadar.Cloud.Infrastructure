# V1 infrastructure remaining acceptance

Historical 2026-09-20 audit: the early missing-handler and legacy-endpoint
statements below are preserved as evidence of that review, not current runtime
status. For the 2026-09-21 deployment and remaining access work, use
[the completed runtime migration](DEV-RESEARCH-RUNTIME-MIGRATION.md) and
[current authoritative access integration](V1-ACCESS-INTEGRATION.md).

Tracking: [SECUR4ALL-242](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-242). Source review on 2026-09-20; Lambda agent independently audited backend readiness. This record separates delivered Dev evidence from dependencies. It does not authorize enabling UAT/Prod or invent new storage contracts.

| Acceptance area | Evidence / current state | Next dependency |
| --- | --- | --- |
| Isolated resolver | Current Dev Python 3.14 version 2 with nine live smoke cases; initial version 1 had 22 owned-fixture cases, actual denied unqualified invocation, privacy-safe logs, no Terraform drift. SNS subscription and owner-confirmed test receipt complete. | Consumer integration belongs to SECUR4ALL-233; resolver traversal does not grant access or produce a safety verdict. |
| GitHub release and rollback | Dedicated manual Dev code-only workflow, matching reviewed plan digest, exact S3-version byte/hash validation, strict scope checks and Dev read-policy supplement implemented. | Actual GitHub OIDC plan and reviewed no-op apply passed, including artifact integrity and post-apply drift checks. See [release qualification](URL-RESOLVER-GITHUB-QUALIFICATION.md). Changed-code deployment/rollback remain separate acceptance cases. |
| Shared assessment contract | SECUR4ALL-190 is In Progress with merged draft schemas. A private Dev Lookup/resolver integration is now deployed; it is not the consumer assessment/access contract. | Accepted request/result/error/provenance and compatibility fixtures. |
| Paid/trial/complimentary authority | SECUR4ALL-230 and 232 remain To Do; current backend implements legacy FREE/PRO balances. | Backend-authoritative access, logical-check accounting, race/retry/revocation contract; trial storage and retention; actual artifact and IAM action inventory. |
| Restricted complimentary operator control | Existing device-recovery AWS_IAM/principal-allowlist pattern is reusable. No complimentary handler or grant/audit contract exists. | SECUR4ALL-232 chooses surface, grant schema and retention; then add exact invocation/storage policy and mobile-denial acceptance. |
| Safe promotion/rollback | Resolver artifacts are pinned; the new code-release verifier tests scope and integrity. | Wider authority/schema/cache compatibility and migration rules. Old access semantics cannot be treated as a safe rollback after migration. |

## Backend audit findings affecting infrastructure

The Lambda agent inspected the current Lambda branch without changing it:

- `src/conversation_analysis/scan_access.py` and `src/shared_entitlements/service.py`: external work currently uses a positive balance, not the agreed paid/trial/complimentary authority. Legacy FREE allocation and research-participation bonus remain. Infrastructure must not present the existing route as satisfying the new paid-only gate.
- `src/purchase_handoff/service.py`: purchase replay and concurrent entitlement updates need backend review before accepting cross-service accounting guarantees. Current purchase integration is Google Play only.
- `src/web_risk_communication/webrisk_client.py` and `app.py`: the existing adapter is Evaluate-shaped and lacks resolver/shared-accounting integration. An endpoint-only infrastructure change would not implement Lookup safely.
- Build registry has no trial or complimentary artifact. The untracked free-monthly-reset handoff is an older design candidate, not an approved V1 recurring free allowance.

No speculative trial/grant tables, schedules, public operator endpoints, provider-secret access or resolver caller grants were added. Required handoff for each remaining backend component: function/artifact name; storage schema and retention/deletion behavior; exact IAM operations; account/device/operator authorization; idempotency and logical-check accounting; environment activation defaults; authority/schema version and safe rollback rules; negative and concurrent acceptance fixtures. Existing tables and secrets should be reused where those contracts justify it.

## Verification limits and next step

The dedicated resolver workflow is merged and was exercised through actual GitHub OIDC, a reviewed no-change plan, exact deployed artifact verification, matching-digest apply and a clean post-apply plan. The initial run exposed one missing EIP attribute read; the bounded Dev policy correction was applied and read back exactly. Broad Dev deployment excludes resolver-only paths; UAT/Prod remain disabled.

This qualifies the no-op release path, not a changed-code rollout or rollback. The separately merged Lambda publisher uploaded only the resolver artifact and skipped broad publication. That newly published artifact has identical bytes to the deployed artifact; publishing did not change the live alias. See the linked qualification evidence for exact runs and versions.

Android V1-0 refinement is ATCR-97/98; native implementation is ATCR-124/125. Backend contracts SECUR4ALL-190/110 and product policy decisions remain prerequisites. Infrastructure V1-0 reporting policy is now a [reviewable contract](V1-OPERATIONS-CONTRACT.md) under SECUR4ALL-178; it does not deploy reporting resources or override customer charging. SECUR4ALL-242 remains In Progress until its broader authorization and promotion criteria have evidence.

## Approved bootstrap supplement applied

The full bootstrap plan exposed unrelated existing Dev/UAT/Prod differences and was not applied. A targeted saved plan was reviewed and contains exactly one creation: `aws_iam_role_policy.resolver_release_reads["dev"]`, policy name `read-existing-url-resolver`, on `trustcheckradar-dev-github-deploy`.

The supplement grants ongoing read access until removed: the listed EC2 Describe operations in us-east-1 (AWS requires wildcard resource scope for these network inventory calls), SNS inspection of only `trustcheckradar-dev-url-resolver-alerts`, and alarm inspection under `trustcheckradar-dev-url-resolver-*`. No network or SNS writes, production/UAT role changes, credential creation or OIDC trust changes are included. Automatic approval review initially required explicit approval for the persistent grant. The owner subsequently approved the exact role, scope and duration. A refreshed targeted plan added only this policy (one addition, zero updates/deletions); live AWS readback exactly matched the plan. The subsequent full bootstrap plan reports no change for this policy but retains 13 unrelated resource differences, none applied. Seven custom-policy simulations verified the intended Dev reads and lack of grants for network/SNS writes, out-of-region network reads and Prod topic reads. Those simulations cover this supplement alone, not the role's pre-existing aggregate privileges. The concrete policy is `bootstrap/access/url-resolver.tf`.

Local validation passed: 40 Python tests (12 release-specific), six mocked bootstrap Terraform cases, Terraform validate/fmt, Actionlint and whitespace checks. The release verifier successfully read the exact deployed artifact version and matched its SHA256 against an actual Dev no-change plan. Actual GitHub OIDC plan and matching no-op apply subsequently passed; see the qualification record. Dev environment variables were read back and match the expected role, region and state location. The original branch contained predecessor device-recovery changes. The `codex/url-resolver-release` review branch was recreated from current main with only resolver commits; original branch/history and unrelated work were preserved. Resolver paths are excluded from broad main-push deployment, and workflow-only changes require explicit dispatch.

## Private Lookup integration added

The [2026-09-20 deployment record](URL-ASSESSMENT-DEV-DEPLOYMENT-2026-09-20.md) documents the new IAM-only Python 3.14 assessment function, exact-secret and resolver-alias permissions, confirmed alert destination, eight live acceptance cases and the remaining consumer gates. The legacy Web Risk endpoint is unchanged by explicit owner choice. SECUR4ALL-233/242 remain In Progress.
