# V1 infrastructure remaining acceptance

Tracking: [SECUR4ALL-242](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-242). Source review on 2026-09-20; Lambda agent independently audited backend readiness. This record separates delivered Dev evidence from dependencies. It does not authorize enabling UAT/Prod or invent new storage contracts.

| Acceptance area | Evidence / current state | Next dependency |
| --- | --- | --- |
| Isolated resolver | Current Dev Python 3.14 version 2 with nine live smoke cases; initial version 1 had 22 owned-fixture cases, actual denied unqualified invocation, privacy-safe logs, no Terraform drift. SNS subscription and owner-confirmed test receipt complete. | Consumer integration belongs to SECUR4ALL-233; resolver traversal does not grant access or produce a safety verdict. |
| GitHub release and rollback | Dedicated manual Dev code-only workflow, matching reviewed plan digest, exact S3-version byte/hash validation, strict scope checks and Dev read-policy supplement implemented. | Read supplement applied and verified after explicit approval. Review/merge, then real OIDC plan run. No claim that source-only workflow is operational yet. |
| Shared assessment contract | SECUR4ALL-190 remains To Do. Resolver has its own contract, not the complete consumer assessment/access contract. | Accepted request/result/error/provenance and compatibility fixtures. |
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

The code-release verifier was exercised against the real current Dev no-change plan and immutable deployed ZIP. Python and mocked Terraform tests establish guard behavior, not a live GitHub OIDC deployment. The Dev-only bootstrap supplement was applied after explicit approval and verified by readback; no deployment role trust was changed. The existing main-branch environment workflow can apply broader Dev stacks on merge, so review that impact before merging this branch.

Complete the GitHub release activation in review, while backend owners deliver SECUR4ALL-190/230/231/232/241 contracts. SECUR4ALL-242 stays In Progress until its wider authorization and safe-promotion criteria have evidence.

## Approved bootstrap supplement applied

The full bootstrap plan exposed unrelated existing Dev/UAT/Prod differences and was not applied. A targeted saved plan was reviewed and contains exactly one creation: `aws_iam_role_policy.resolver_release_reads["dev"]`, policy name `read-existing-url-resolver`, on `trustcheckradar-dev-github-deploy`.

The supplement grants ongoing read access until removed: the listed EC2 Describe operations in us-east-1 (AWS requires wildcard resource scope for these network inventory calls), SNS inspection of only `trustcheckradar-dev-url-resolver-alerts`, and alarm inspection under `trustcheckradar-dev-url-resolver-*`. No network or SNS writes, production/UAT role changes, credential creation or OIDC trust changes are included. Automatic approval review initially required explicit approval for the persistent grant. The owner subsequently approved the exact role, scope and duration. A refreshed targeted plan added only this policy (one addition, zero updates/deletions); live AWS readback exactly matched the plan. The subsequent full bootstrap plan reports no change for this policy but retains 13 unrelated resource differences, none applied. Seven custom-policy simulations verified the intended Dev reads and lack of grants for network/SNS writes, out-of-region network reads and Prod topic reads. Those simulations cover this supplement alone, not the role's pre-existing aggregate privileges. The concrete policy is `bootstrap/access/url-resolver.tf`.

Local validation passed: 39 Python tests (11 release-specific), six mocked bootstrap Terraform cases, Terraform validate/fmt, Actionlint and whitespace checks. The release verifier successfully read the exact deployed artifact version and matched its SHA256 against an actual Dev no-change plan. GitHub OIDC execution remains pending review/merge. Dev environment variables were read back and match the expected role, region and state location. The original branch contained predecessor device-recovery changes. The `codex/url-resolver-release` review branch was recreated from current main with only resolver commits; original branch/history and unrelated work were preserved. Resolver paths are excluded from broad main-push deployment, and workflow-only changes require explicit dispatch.
