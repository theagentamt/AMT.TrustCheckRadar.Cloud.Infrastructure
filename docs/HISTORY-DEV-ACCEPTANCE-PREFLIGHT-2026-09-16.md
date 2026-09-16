# Dev History acceptance preflight

Outcome: blocked before identity creation or activation. No authenticated feature
acceptance is claimed. Owner approval covers two new disposable Dev identities,
controlled History/badge fixtures and safe cleanup/alert verification, not global
exposure of incomplete behavior or shared review-account changes.

## Verified Baseline

- AWS account 107827791950, Region us-east-1, SSO profile trustcheckradar verified.
- Infrastructure runtime revision: `a0967f266ee8f6a06ff44ae6bc7456e07afb195e`.
  [Dev deployment](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35151701123)
  succeeded; evidence-only successor `097ebe8` does not change runtime.
- Analysis/History API release: `c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca`.
  Lifecycle/History deletion bridge: `8d25e19b691d82caf630edc7ebd84c0b45de0c5c`.
  All five functions were independently rechecked Active/Successful with the
  expected CodeSha256. Pins remain in the Dev Terraform inputs.
- History contract: schemaVersion 1, contractVersion 1.0.0, originally frozen at
  Lambda commit `08353eaf9fb5cb1ce7e339d9b6f630a7f0825f9d`.
- Relevant History, recognition, replay, lifecycle and deletion flags are false.
  Both History EventBridge rules were rechecked DISABLED.
- The existing Lambda smoke harness runs in plan-only mode with zero network,
  AWS or paid model operations. This is not execution of its advertised cases.

## Blocking Findings

1. `history_features` contains environment-wide booleans, not a two-subject
   allowlist. Enabling producer writes/recognition affects ordinary Dev analysis.
   Adding a client-side test-subject restriction does not constrain those workers.
2. Lifecycle and deletion reconciliation operate across shared tables. The bridge
   consumes the shared deletion stream from TRIM_HORIZON when enabled. Scoped
   API callers alone cannot isolate this background work.
3. `terraform/api/history.tf` requires active lifecycle and account-deletion
   integration for writes/mutations. The lifecycle and observability acceptance
   gates must not be removed or marked passed simply to make a plan succeed.
4. `scripts/history_dev_smoke.py` in the Lambda repository expects the old analysis
   hash and token/fingerprint disk files. The current approval allows credentials
   and tokens only in Keychain or transient memory. The harness needs a verified
   release manifest and a secure credential adapter before execution.
5. Existing smoke coverage does not exercise pagination/cursor attacks or a
   deterministically interleaved accepted-analysis/clear completion. Its serial
   complete-then-clear flow is not live proof of the corrected concurrent case.

## Case Results

| Case | Result | Evidence or reason |
| --- | --- | --- |
| AWS identity and deployed build checks | PASS | Read-only CLI checks described above |
| Shared gates and cleanup rules unchanged | PASS | All disabled |
| Harness inert preflight | PASS | Plan mode, zero external actions |
| Two-account isolation for activation | BLOCKED | Global runtime controls/shared cleanup |
| Cognito identities, login, controlled binding/bootstrap | NOT RUN | No safe isolated target yet |
| List/detail/progress and pagination | BLOCKED | Same isolation gate |
| Cross-account, invalid/revoked binding and cursor denial | BLOCKED | Same isolation gate |
| Same-ID replay, receipt replay and quota invariance | BLOCKED | Same isolation gate |
| Delete-one, logical clear and badge reset | BLOCKED | Same isolation gate |
| Concurrent clear and recognition-generation race | BLOCKED | Isolation plus deterministic harness needed |
| Physical purge, expiry/backlog and replay redaction | BLOCKED | Shared lifecycle cannot be invoked safely |
| Alert delivery and recovery | NOT RUN | Must be tied to isolated accepted test resources |

No test identities or Keychain entries have been created. There are therefore
no new credential references to hand off. The shared review credentials were
not accessed. No customer records, binding changes, bootstrap writes, mutations,
paid calls, purchases, full-account operations, UAT or Prod actions occurred.

## Proposed Next Scope

Review a temporary, separately named Dev acceptance stack with isolated tables,
functions, API routes, signing secret, cleanup checkpoints/stream and IAM. Its
roles must not be able to mutate shared Dev tables. Use two synthetic Cognito
subjects; explicitly review whether the pool/client is isolated too. Keep the
shared Dev API and all its flags unchanged. Bound runtime, fixture counts,
notification volume, retention and teardown responsibility before provisioning.

The Lambda owner must update the harness in its own repository: Keychain/in-memory
credentials, per-function immutable manifests, isolated-resource enforcement,
pagination/negative authorization cases and deterministic no-model race fixtures.
Do not copy credentials into evidence or manufacture server success by direct
History inserts. Distinguish fixture setup from actual completion-path acceptance.

An isolated candidate pass would not by itself approve activation of the shared
Dev endpoint. Return separate read and mutation readiness, physical-purge evidence,
and remaining release gates to ITCR-77. SECUR4ALL-223/224/225/226 and related
SECUR4ALL-196 remain open unless their actual coverage/acceptance is established.
