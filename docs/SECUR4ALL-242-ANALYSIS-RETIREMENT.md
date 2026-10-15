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
- Application KMS decrypt/data-key requests are explicitly denied when
  `lambda:SourceFunctionArn` is present (`Null: false`). AWS documents that this
  context exists for SDK requests from function code, but not Lambda's automatic
  environment encryption/decryption. The conditional deny preserves service
  initialization and adds no KMS Allow. See [AWS source-function context](https://docs.aws.amazon.com/lambda/latest/dg/permissions-source-function-arn.html)
  and [IAM Null checks](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_condition_operators.html#Conditions_NullCheck).
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
old unqualified permission removal, zero substantive drift, qualified routing, unsafe
alias weights, digest authorization and actual downloaded archive bytes. Its
post-apply mode checks active shapes even when the plan is entirely no-op.
Local Python 3.14 CI helper suite: **336 passed**, including **24** retirement
guard tests. Final exact-head review is recorded in the source story.
Earlier syntax, missing locked-provider cache and incomplete synthetic fixture
attempts are not acceptance passes; the corrected final suites supply the evidence.

Read-only AWS `SimulateCustomPolicy` checks with wildcard resource evaluation
returned explicit Deny for all five decrypt/data-key action variants with the
source-function context present, and implicit Deny without it. The exact isolated
Null condition also matched with key-present input. Full-policy evaluation against
a synthetic specific key returned implicit Deny, so that attempt does not prove
an explicit match. These are policy simulations, not KMS service requests or live
initialization evidence. Live initialization still requires the approved repair
and the bounded Dev contract check.

## Exact Dev deployment procedure

1. Integrate the reviewed correction into infrastructure main and require its
   ordinary main CI to pass. This does not deploy it.
2. Dispatch **Analysis retirement Dev** on that exact main SHA with
   `execution_mode=plan` and `expected_revision=<full SHA>`. It uses the existing
   Dev OIDC role and existing API state; it never applies in plan mode. Keep
   `plan_scope=retirement` for the full initial transition.
3. The workflow privately saves the full Terraform plan and verifies the complete
   initial transition. Only retired analysis IAM/configuration/alias/integration,
   primary invoke permission and removal of its old period-work grants may change.
   Runtime code pins/concurrency and unrelated capabilities must stay unchanged.
   Substantive drift, extra actions, missing old-permission removal, legacy-route activation or
   different code/configuration cause rejection. The exact versioned S3 archive
   is downloaded and its actual hash verified. Preserve only the minimized report.
4. Independently inspect that report and plan proof. **Obtain owner approval for
   its exact reviewed digest and source SHA before apply.** Replanning is not
   approval; a changed digest needs review and fresh approval.
5. Dispatch the same workflow at the same SHA with `execution_mode=apply` and the
   approved digest. It replans, compares the digest, verifies the archive and
   applies only that saved plan. No manual AWS mutation is authorized here.
6. The workflow generates a fresh post-apply plan. `--bounded-dev --post-apply`
   requires zero managed changes/substantive drift, exact active read-only policies, immutable
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

The diagnostic rerun `37208699019` identifies managed drift. A diagnostic report
now lists only source-catalog resource labels, known changed field names and
unknown-field counts. Before/after values, unknown resource labels and unknown
field names are never emitted. All managed drift still rejects the plan; this
report does not authorize reconciliation or apply.

Run `37209217873` reports one resource outside the original diagnostic labels.
The checked-in diagnostic catalog extends labels to public API Terraform resource
definitions and top-level attributes/blocks from the locally read locked AWS
provider 6.65.0 schema. Instance keys and all attribute values remain redacted.
Catalog entries control diagnostic output only; they grant no drift exception,
deployment permission or runtime access.

## Verified automatic-stage readback

Run `37209785080` identifies the sole drift as the existing API stage's
`deployment_id`. The locked AWS provider marks this field optional/computed;
[AWS documents automatic stage deployments](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-stages.html).
The verifier permits only this service-managed pointer readback for the exact
Dev `$default` stage: all other before/after fields must match, both pointers
must be known, the stage and Dev API counterparts must be exact no-ops, API/stage
identities must correlate, and source must enable automatic deployment without
an explicit deployment ID. Unknown values, changed stage settings, trust,
permissions, routes, API identity or unrelated drift still reject. The complete
readback remains in the reviewed digest and its count appears in the minimized
report. Post-apply still requires zero planned resource changes and checks all
retirement shapes. This is not a general drift exemption or a state-only apply.

## Applied transition and initialization correction — October 4, 2026

The original owner-approved transition applied successfully in
[run 37213843044](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/37213843044).
Its initial post-apply acceptance failed, which kept SEC242 In Progress until
the separately approved correction and live acceptance recorded below. The
approval for that transition did not authorize another apply.

Read-only SDK inventory verified the pinned alias/version, scoped API route and
permission, exact two managed/two inline policies, and absence of untracked
grants. Behavioral checks then exposed an initialization defect: the unauthorized
HTTP request returned 401; the authenticated owned-device request with a fresh
request ID returned 500 before
the handler ran. Exactly one missing-auth direct alias diagnostic returned
`KMSAccessDeniedException`. No provider or database write path ran, and no account,
device or trial state was changed. The initial unconditional KMS deny prevented
Lambda from decrypting its environment. These failed checks are not passes.

The correction changes only the runtime policy to the application-context KMS
deny described above. Code, version, alias, API permissions, concurrency, retained
one-account rules-only scopes and unrelated capabilities stay unchanged. There
is no new KMS Allow, manual AWS apply, state-only refresh or rollback.

After reviewed source is merged to main and main CI passes, dispatch this same
workflow with `execution_mode=plan`, `plan_scope=runtime-kms-repair` and the exact
new source SHA. The verifier accepts exactly one in-place runtime-policy update
from the known previously applied policy to the corrected policy. Every other
managed resource must be an exact no-op without unknown values. The ordinary
deployment guard still rejects this update. Review the minimized plan and obtain
owner approval for its **new exact digest and source SHA** before dispatching
`execution_mode=apply` with the same scope. Post-apply verification must pass,
then repeat the live resource inventory and bounded HTTP checks. Do not close
SEC242 until the required Dev behavior succeeds. Owned positive legacy replay
remains unperformed because the inventory contained no eligible existing pair;
local source/Moto tests and the pending SEC334 release case are distinct evidence.

## Exact computed-role readback and verification mode

The provider's cached role view still contains the former period-work attachment
and the former History write policy even though the separately managed policy
resources and live SDK inventory show their removal. Post-apply verification and
the single-policy repair may accept only this exact computed readback for the
analysis role; the initial retirement plan may not. The proof requires the exact
Lambda trust and role/function source references; exact current managed policy,
attachments and inline policies; and a historical History policy bound to the
pre-apply inventory's normalized policy digest. All counterpart resources must be
no-ops, except the exact runtime-policy update in repair mode. Unknown fields,
extra/duplicate policies, changed trust, resource identities or unbound historical
policies reject. At most one stage and one role readback are permitted; full
before/after views remain bound to the reviewed plan digest.

`execution_mode=verify` generates a fresh protected plan and invokes post-apply
verification without applying anything. It is useful only when the final expected
policy and all other active shapes already match source. It does not repair a
policy, persist refreshed state or authorize a deployment. After a successful
repair, use this mode if a later acceptance audit is needed; do not reapply the
original transition to reconcile computed views.

## Final retained Dev acceptance — October 4, 2026

The owner separately approved repair digest
`d565ce50d049146ee42d7030573a242d090f709627c09162b9a3c0c2610bbbe8`
at main `1f06b7c8338ce07f460ffbb0c16859b30877be5f` (reviewed source
[PR160](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/pull/160)).
Main [CI 37216599710](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/37216599710)
and plan-only [run 37217141723](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/37217141723)
passed. Approved [apply run 37227179724](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/37227179724)
matched that digest, applied exactly one runtime IAM policy update and passed its
post-apply verifier: zero managed changes, zero computed readback differences and
the original immutable archive verified. No manual AWS deployment occurred.

Read-only SDK inventory independently matched the exact role trust, two managed
and two inline policies, application-context KMS deny without a KMS Allow, paired
GetItem-only History access, pinned version/alias, exact same-account/stage/route
permission, JWT primary route and absence of unqualified/version-specific or
legacy-route permissions. The retained rules-only account scope was preserved.

The bounded live check made exactly two HTTP requests without retry. The
unauthenticated request returned 401 without handler work. The authenticated
owned-device request used a fresh synthetic request ID and returned 409,
`LEGACY_MIGRATION_REQUIRED`, `retryable=false`. Four consistent GetItems proved
its exact request and consumption rows absent before and after. Pre/post authority
readbacks matched the same existing trial/history and allowance with no new
paid or complimentary source. There was no account/device/trial reset or fixture
write. Fresh private authentication headers were deleted.

The 1,742 ms API/Lambda log window contains exactly two API records (401/no
integration and 409/backend 409), one Lambda START/END/REPORT, zero error logs
and zero provider-name sentinels. An initial temporary operational assertion
incorrectly expected service status 200 from `$context.integration.status`;
[AWS documents that this field is the backend Lambda response status](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-logging-variables.html).
The raw failed assertion is preserved and a separate hash-bound corrected
assessment accepts the observed backend 409. No HTTP or cloud query was repeated
to make this correction. The initial short-timeout authority read produced no
snapshot and no HTTP request; one authorized read-only rerun with realistic
timeouts then supplied the precondition.

Observed telemetry covers the retired-analysis/API window only. Provider
non-dispatch is established separately by the audited pinned handler's immediate
missing-request return and IAM provider/dispatch denies, not by provider metrics.
This is not paid-provider, evaluator/URL fanout, store or UAT qualification.
The aggregate receipt is in
[`evidence/sec242-analysis-retirement-dev/acceptance.json`](evidence/sec242-analysis-retirement-dev/acceptance.json).
Private raw inventories, account/device identifiers, row keys, credentials and
content are excluded from the repository.

These results complete SEC242's retained Dev retirement boundary. Earlier scoped
URL/access/trial/message/complimentary evidence supplies the other accepted
infrastructure slices; SEC232's AWS_IAM-only operator route and actor-forgery
denial supply the normal-mobile operator exclusion. Broader SEC190, SEC230 and
SEC76 work remains open in its own scope. SEC334 remains open for the release
matrix below; none of those unexecuted cases is reported as passed.

### SEC334 retirement release instructions — pending execution

1. Promote reviewed replay-only catalog bytes and environment configuration
   through CI/CD, with fresh exact-digest approval where required. Privately
   verify archive/version/alias, JWT route and scoped permissions, role inventory,
   gates and test-account/device ownership. UAT/Production currently have no
   admitted retirement catalog entry; this handoff does not activate them.
2. Use the verified `POST /analysis` entry point and schema 1.0 with a fresh
   request ID, `sourceType=pasted_text`, `localSanitizationApplied=true`, benign
   synthetic `sanitizedText`, `entities=[]`, `campaignConsentGranted=false` and
   `appFeatures=null`. A protected credential fixture must supply the real test
   account JWT and current `X-Device-Binding-Fingerprint`; do not fabricate them.
   Expect unauthenticated 401 and authenticated fresh-ID 409 migration denial,
   `retryable=false`, no new request/consumption row and unchanged allowance.
3. For positive legacy replay, first find an eligible owned existing completed
   request/consumption pair. None existed during this Dev qualification. If there
   is no eligible pair, keep the case pending until an explicitly approved fixture
   procedure exists; do not manually create ledger or History rows. Reopen must
   preserve original accounting and create no new provider work or charge. Repeat
   ownership/device/deletion/expiry rejection cases with separately reviewed
   fixtures and approvals for any protected mutation.
4. Record private bounded row/authority readbacks and API/Lambda telemetry;
   capture provider/evaluator metrics separately if claiming their qualification.
   For this retired route, backend integration status is 409, distinct from the
   Lambda service invocation status. The Dev runner was a private temporary
   helper, not a committed reusable release runner. Implement and review that
   release automation in SEC334 before repeating the automated matrix; do not use
   the historical success-analysis smoke script as a retirement runner.
5. Remove temporary credential/evidence fixtures without resetting the reusable
   account, original trial, active device, receipts or retained one-account scope.
   The owner retained that scope and requested no rollback. Any future disable
   needs its own reviewed current-revision plan and authorization. Physical-only
   work stays in ATCR148; an Android/UAT delay does not block independent backend
   Dev delivery.
