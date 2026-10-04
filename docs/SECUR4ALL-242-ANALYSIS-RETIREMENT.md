# SEC242 — Retired analysis deployment boundary

## Problem and scope

Current Dev already runs the closed `conversation_analysis` handler. It replays
an owned existing result and never starts a new check. Its research migration
boundary denies writes, provider credentials and Lambda dispatch. This correction
addresses a separate source risk: generic deployment/History inputs previously
could select old dispatcher code outside that migration, retain obsolete Allows,
and route API Gateway to an unqualified function.

The correction preserves the established `POST /analysis` response contract and
current reviewed Dev archive. It changes deployment composition and permissions,
not analysis policy, scan limits, retention, API schemas or routes. The existing
one-account rules-only message/History scope stays enabled; no rollback, provider
activation, device switch or account reset is part of this work. UAT and Production
are not deployed. Their planning remains blocked until their own retirement
catalog entry and promotion review exist.

## Source guarantees

- The source-controlled retirement catalog binds environment, full release SHA,
  exact S3 object version and archive SHA-256. Its initial entry is the already
  published Dev retirement archive from `d98ffd65b42d54953ad83e980e58846b6fc02c5d`,
  recorded in `docs/evidence/dev-research-actions-publication.json`.
- A missing selection fails planning. A caller's approval string or promotion
  boolean cannot admit unknown bytes, versions or environments. Generic
  `artifact_release`, old History analysis pins and custom analysis environment
  maps cannot restore a dispatcher. Matching independent/coordinated selectors
  preserve the other four research migration pins and fences; mismatched selectors
  are rejected. Do not remove the coordinated migration merely to select analysis.
- Lambda publishes an immutable version; the unweighted `retired` alias selects
  that version. API integration invokes the alias. Permission is qualified and
  restricted to the same account, configured stage and exact `POST /analysis`.
  The legacy path stays disabled; source validation and the bounded deployment
  both reject its activation.
- Runtime Allows contain only partition-scoped `GetItem` for authoritative
  profile/deletion/device checks and owned request/consumption evidence. The two
  History tables retain partition-scoped `GetItem` for stored replay authorization.
  Both table settings remain present together, including the known Dev catalog
  names when the unrelated History deployment input is absent.
- Provider-secret/model-service/Lambda dispatch and database write/query/scan
  families have unconditional explicit Denies. Transaction writes are denied through
  their underlying Put/Update/Delete/ConditionCheck permissions, as specified by
  [AWS transaction IAM guidance](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis-iam.html). Old entitlement, quota, provider,
  campaign outbox, History settlement and analysis period-work grants are removed.
  This does not claim every legacy metadata variable in other helpers is removed.
- Protected Cognito settings, required table names and bounded projection settings
  are explicit. Writes, durable replay and recognition remain false. Removed badge,
  cursor and old provider/accounting configuration is not read by the retired core.

The Lambda source audit proved that the pinned retirement core and relevant shared
security/contracts are byte-identical to reviewed current main. Its source tests
cover owned replay, missing/erased evidence, account/device fences and no new
provider or accounting work. See Lambda
[PR109](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/109).

AWS documents stage/method/path-scoped invocation permissions and version/alias
qualification in its [API Gateway integration guidance](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html)
and [Lambda AddPermission reference](https://docs.aws.amazon.com/lambda/latest/api/API_AddPermission.html).

## Automated source acceptance

Local Terraform 1.12.1 mock API suite: **221 passed, zero failed**. The final suite
includes missing/forged pins, exact object version, claimed non-Dev promotion,
matching/mismatched selectors, generic rollback inputs, environment injection,
read-only IAM and qualified route checks. Existing historical assertions that
required the retired endpoint to query indexes/write History/use free quotas were
updated to assert permanent retirement instead.

The verifier suite covers bounded before/after fields, exact policy documents,
old unqualified permission removal, zero managed drift, qualified routing, unsafe
alias weights, digest authorization and actual downloaded archive bytes. Its
post-apply mode checks active shapes even when the plan is entirely no-op.
Local Python 3.14 CI helper suite: **327 passed**, including **15** retirement
guard tests. Final exact-head review is recorded in the source story.
Earlier syntax, missing locked-provider cache and incomplete synthetic fixture
attempts are not acceptance passes; the corrected final suites supply the evidence.

## Exact Dev deployment procedure

1. Integrate the reviewed correction into infrastructure main and require its
   ordinary main CI to pass. This does not deploy it.
2. Dispatch **Analysis retirement Dev** on that exact main SHA with
   `execution_mode=plan` and `expected_revision=<full SHA>`. It uses the existing
   Dev OIDC role and existing API state; it never applies in plan mode.
3. The workflow privately saves the full Terraform plan and verifies the complete
   initial transition. Only retired analysis IAM/configuration/alias/integration,
   primary invoke permission and removal of its old period-work grants may change.
   Runtime code pins/concurrency and unrelated capabilities must stay unchanged.
   Drift, extra actions, missing old-permission removal, legacy-route activation or
   different code/configuration cause rejection. The exact versioned S3 archive
   is downloaded and its actual hash verified. Preserve only the minimized report.
4. Independently inspect that report and plan proof. **Obtain owner approval for
   its exact reviewed digest and source SHA before apply.** Replanning is not
   approval; a changed digest needs review and fresh approval.
5. Dispatch the same workflow at the same SHA with `execution_mode=apply` and the
   approved digest. It replans, compares the digest, verifies the archive and
   applies only that saved plan. No manual AWS mutation is authorized here.
6. The workflow generates a fresh post-apply plan. `--bounded-dev --post-apply`
   requires zero managed changes/drift, exact active read-only policies, immutable
   alias/integration and qualified permission, no retained analysis period-work
   access, preserved closed gates and actual Lambda CodeSha equal to the approved
   archive. This is infrastructure acceptance, not a new multi-service user check.
7. Audit live resource-based permissions/role attachments read-only to detect
   untracked access that Terraform cannot inventory. Perform only the approved
   non-destructive backend contract checks and record what was actually tested.
   No physical device, existing account deletion or paid provider request is needed
   for this IAM/routing correction.

Ordinary environment deployment checks immutable retirement bytes and rejects
retirement transitions; it cannot bypass the isolated digest-reviewed procedure.
Raw plans, environment maps and logs are removed from the runner. Its seven-day
artifact contains only aggregate review results. A failure remains open Dev work.
Do not use a release testing follow-up to mark failed Dev acceptance complete.

## Rollback and later release handoff

Never roll back to the old generic dispatcher, `$LATEST` route or old write/provider
policy. A rollback must select a source-reviewed replay-only catalog entry, preserve
mandatory Denies and account/device ownership, and use a new reviewed plan/digest.
Keep unrelated retained Dev scopes unchanged. Any availability pause requires its
own concrete plan and existing approval boundaries.

Reuse [SEC334](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-334) for the later
assembled release/UAT matrix and link this page from SEC242. Release operators
promote the same qualified archive bytes through reviewed environment-specific
catalog/version/configuration changes. Pending cases include owned legacy replay,
new-ID migration denial without charge/provider invocation, wrong-account/device
and erased/expired-result rejection, plus ordinary shared-authority multi-service
fanout/retry accounting. Record exact pins, gates, account scope, expected charge
counts, privacy-safe evidence and cleanup. Those pending release cases are not
reported as performed here. Android emulator/store work remains in its existing
stories; physical-only ATCR148 stays open and does not block independent backend
completion.

## Plan-only diagnostic boundary — October 4, 2026

Initial isolated Dev plan run `37207970664` reached verification and was rejected
before apply. Its generic error did not identify the failed check. The verifier
now emits only the static source-defined rejection label; SDK, parsing and other
exception text remains redacted. An AST regression check requires every check
label to remain a constant string. This improves diagnosis without accepting an
extra action, relaxing a field/policy check, changing any archive, or applying a
plan. The rejection remains unqualified until a corrected plan passes review.
