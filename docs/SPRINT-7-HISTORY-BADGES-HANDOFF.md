# Sprint 7 History and Badges: AWS ownership and Lambda handoff

Date: 2026-09-13; deployment update 2026-09-14. Product baseline and Dev retention
settings are approved; remaining contract gates are open. The owner authorized
Dev deployment/activation, but activation is blocked by incomplete dependencies.
Dev storage and the disabled lifecycle worker are deployed; see
HISTORY-DEV-DEPLOYMENT.md. Historical planning restrictions below do not override
this Dev authorization. UAT/Prod remain unchanged and unauthorized for promotion.
Input: Android "Sprint 7 backend and AWS requirements", revision 1, 2026-09-13.
The input is a consumer proposal, not an approved policy or deployed specification.
Focused stories, activation dependent on SECUR4ALL-185 (infrastructure implementation started):
- [SECUR4ALL-223](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-223): infrastructure; child of SECUR4ALL-186.
- [SECUR4ALL-224](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-224): Lambda read APIs; child of SECUR4ALL-186.
- [SECUR4ALL-225](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-225): Lambda completion/replay; child of SECUR4ALL-186.
- [SECUR4ALL-226](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-226): Lambda deletion/reset; child of SECUR4ALL-188.

Implementation milestone: `terraform/history-data/README.md` records the agreed
two-table/index contract and disabled data scaffolding on branch
`codex/sprint7-history-infrastructure`. SECUR4ALL-223 is In Progress. Lambda work
has been dispatched to the existing AMT Trust Check Radar Lambda task, which is
implementing in its own repository. No feature activation or deployment yet.

The local `history-processing` stack now wires the gated lifecycle worker,
immutable artifact/version/hash, exact environment/index IAM, five-minute
schedule and eight runtime alarms. Storage monitoring and operations/restore
runbooks are also implemented. Read/mutation route integration, producer IAM,
account bootstrap/deletion/export, final policies, release upload and live
acceptance remain outstanding. See `terraform/history-processing/README.md`.

2026-09-14 handback: the Lambda owner reports artifact-only Dev publication of
`0fad0cc500372bba5e66b08f90a743c5fb557bb2` with durable retention-locator recovery
and passing failure/TTL-first regressions. This supersedes the earlier upload
blocker for that release only, not deployment or activation approval. Follow-up
`68dd8df` implements the matching runtime retention guard: locator TTL must cover
90-day content plus the 24-hour cleanup window. It remains local and unuploaded.
The older uploaded `0fad0cc` release must NOT be selected for deployment; a new
authorized immutable release of `68dd8df` or a later reviewed descendant is
required. Final accepted artifact versions, policy approvals and live evidence
remain gates; stories stay open.

## Scope and evidence

Deliver retained, server-authoritative completed assessments and approved badge
progress across devices, without duplicate charges, History records, or awards.
Reuse Cognito, active device binding, API Gateway, entitlement/idempotency logic,
immutable Lambda artifacts, and the current environment-separated release flow.
No mobile source edits belong in the infrastructure workspace.

Read-only repository review found:

- Terraform stacks: foundation, api, edge, identity-workflows and campaign stacks.
  No dedicated cloud History/progress tables or routes were found.
- identity-workflows currently deploys post-confirmation; foundation exposes a
  deletion ledger and role. These are not evidence that full account deletion
  or export workflows are implemented. SECUR4ALL-200 is still To Do.
- Lambda release e7b9e842 persists RESULT_READY, then commits completion,
  consumption and entitlement changes transactionally; campaign publishing is
  consent-conditioned in that transaction. Reuse these reliability boundaries.
- analysis replay has REQUEST_ID_TTL_SECONDS default 900 seconds, and expired
  records can be reclaimed. This is not History retention or a long-term
  no-double-charge guarantee. Confirm effective Dev settings before migration.
- users, analysis-abuse-control and deletion-ledger tables have PITR configured.
  Retention/deletion must examine existing replay/backup copies as well as new
  tables; do not change shared backup policy without impact review.
- No full cloud History/progress or account export/delete handlers were found
  in the inspected Lambda checkout; only campaign-specific deletion code.
- This is source/YouTrack evidence, not a new live AWS inventory. SSO was
  previously expired. Do not report proposed UAT/Prod URLs as active services.

SECUR4ALL-221/222 concern the separate analysis request-size defect; this handoff
does not replace them or expand Sprint 7 into new screenshot ingestion.

## Approved product baseline (2026-09-13)

Owner approved the recommendations in this conversation. This section overrides
earlier proposals about snippets, points and retention in this handoff and its
consumer requirements. Approval of policy is not implementation, legal review,
activation, story completion or deployment authorization.

1. Server-authoritative History and Badges; encrypted device caches cleared on
   logout. Cross-device/reinstall recovery comes from retained server records.
2. History expires 90 days from the server-authoritative completion time;
   earlier user deletion is supported. Reads exclude expired/deleted content
   immediately. Replaying or reading does not restart the retention clock.
3. Retain the approved assessment, source type and completion time, plus bounded
   operational identifiers/versions required by the contract. No submitted
   conversation, screenshot, original sensitive values or snippet in History.
   Generated explanations require privacy validation/minimization; a sanitized
   flag does not establish anonymity. Do not extend campaign/analysis input
   retention to 90 days because History is retained for that period.
4. Badges only, no points. Initial milestones: 1, 5 and 20 qualifying completed
   checks. Recognize checking activity, never independently confirmed scams
   solely from model risk. No cash, redemption, paid access, scan allowance or
   campaign-consent effect. Do not implement the MAUI risk-weighted formula.
5. Delete-one and clear-History remove assessments without resetting Badges;
   explain the distinction next to the controls. Badge reset is separate.
6. Reset advances the recognition generation. Only qualifying checks submitted
   after the reset count; use server acceptance time/order, not the phone clock.
   Old records, retries, delayed completions of pre-reset submissions and old
   events cannot immediately re-award reset progress. A retry never counts twice.
7. Remove deleted/expired content from active stores, including replay copies,
   within 24 hours of deletion/expiry. This is a required SLA to implement and
   test, not an assertion that current systems already enforce it.
8. Keep only narrowly justified metadata needed to prevent duplicate charging
   or resurrection; fields and retention must still be explicitly finalized.
   Backups expire separately; restored backups must reapply erasures before
   traffic is served. No indefinite backup or tombstone retention by omission.
9. An offline device cannot receive immediate deletion. Clear caches on logout;
   on reconnection reconcile invalidation before showing stale cached records
   again. Describe offline limitations honestly; do not promise remote erasure
   from a disconnected device.

## Remaining decision and contract gates

SECUR4ALL-185 and ATCR-84 stay open until these are resolved and reflected in
versioned schemas, fixtures and acceptance tests:

- Exact backup/PITR retention window, restore procedure, and numeric lifetime
  and minimal field set for dedup, invalidation and deletion metadata. Badge
  state has a separate lifecycle; History expiry must not silently reset it.
- Whether identical content deliberately resubmitted under a new request ID
  counts toward badge milestones. No extra content fingerprint retention is
  approved by omission. Same-ID retry deduplication is already mandatory.
- Exact qualifying-completion rules, stable badge IDs, EN/ES catalog text and
  timestamps; any highest-risk/signal statistics remain out of scope pending
  separate approval. Assessment field bounds and privacy checks need fixtures.
- Technical route/envelope/header schemas, consistency SLA, cursor lifetime,
  snapshot/invalidation semantics and legacy recovery policy. Proposed paging
  remains 20 default/50 maximum and 262,144 UTF-8 response bytes, not ratified
  merely by accepting the five product recommendations.

History/Badges remain separate from campaign, marketing and model-training
consent. Contract refinement and synthetic tests can proceed; activation waits
for the remaining gates and proven lifecycle/account-erasure integration.

## Infrastructure story: isolated History and Badges data, IAM and release wiring

Owner: AMT Trust Check Radar Infrastructure. Split from SECUR4ALL-186.
Contract dependency: SECUR4ALL-185; lifecycle coordination: SECUR4ALL-188/200.

### Design direction, subject to the contract gate

- Prefer DynamoDB on-demand and existing HTTP API/Lambda services. Evaluate
  separate content and control/progress tables so content deletion and minimal
  dedup/generations have distinct retention. Avoid a table/Lambda per endpoint.
- Proposed access patterns: verified-account partition; chronological History
  key with server completion time plus request ID; direct request lookup via a
  locator item or a justified GSI; control/progress, mutation receipts and
  generation-scoped award dedup records. Do not expose these keys to clients.
- Record exact keys, required indexes/projections, read-consistency behavior,
  transaction participants, item-size bounds and hot-partition assumptions
  jointly with Lambda before Terraform implementation. No scan-based list API.
- Prefer a bounded transaction extension when practical. If projections are
  asynchronous, require an atomic durable completion/outbox event and repairable
  source retained for the approved recovery window. A short-lived replay item
  or a stream alone is not an indefinite recovery source. Keep campaign outbox
  separate: History must work independently of campaign participation.
- No OpenSearch, new identity system, server OCR, screenshot bucket/upload,
  client points-write API, public database or blanket IAM grants. Do not add
  NAT/VPC or async services without an identified requirement and cost review.

### Acceptance criteria

1. Provide per-environment Terraform/state integration, encryption, explicit
   retention and backup settings, expiry attributes and production deletion
   protection. Missing policy approval fails activation closed; no invented
   retention defaults. TTL is eventual cleanup, not the deletion deadline.
2. Define a scoped stack/remote-state ownership design using existing patterns;
   foundation/api/edge dependencies must not create state cycles. Export only
   versioned resource contracts and non-secret integration settings.
3. Least-privilege roles separate read APIs, mutations, completion/projector,
   lifecycle and export/erasure access. Grant Query to required index ARNs as
   well as table actions; constrain transaction/encryption permissions to
   actual participants. No caller-supplied account target or mobile AWS keys.
4. Wire immutable artifacts to the agreed three reads and three mutations on
   the existing authenticated API. Preserve /analysis and V1 compatibility.
   Proposed routes are in the shared contract below, not currently deployed.
   Gate feature activation independently; leave destructive routes inactive
   until authorization/lifecycle tests and owner approval pass.
5. Only if selected: provision private stream/queue/projector/DLQ and repair
   schedule with bounded retries, expiry, partial-batch failure handling,
   concurrency/backpressure and content-minimized events. Return runtime inputs
   and artifact names to Lambda before deployment. Scheduled purge may be
   required independently of projections to meet the approved deletion SLA.
6. Cover new stores, replay copies, events, cursor state and restored backups
   in lifecycle/erasure/export permissions and runbooks. Block activation if
   SECUR4ALL-200 or an export owner cannot fulfill the approved promises.
7. Add low-cardinality metrics/alarms for failed persistence, pending age or
   projection lag, retry exhaustion/DLQ, throttles, authorization failures and
   deletion backlog. No text, snippets, model output, tokens, fingerprints or
   account IDs in metric dimensions/logs/traces. Set retention and cost caps.
8. Produce a request-volume/record-size/retention cost estimate, including
   transactions, indexes, PITR/KMS, queues and logs. No unreviewed expensive
   always-on services or paid load tests.
9. Run formatting, validation, Terraform tests for environment isolation,
   disabled gates, exact table/index/IAM scopes, TTL/backup settings, routes,
   artifact wiring, concurrency and conditional async resources.
10. Plan against tested immutable Lambda artifacts and review changes before
    release. Main pushes can auto-deploy Dev: no trigger-bearing push/merge or
    apply is authorized by this planning request. Dev, UAT and Prod promotion
    require their applicable explicit approval. Record endpoints and deployed
    version separately from Android acceptance. SECUR4ALL-191 owns missing UAT.

## Lambda story A: authenticated History and progress read APIs

Owner: AMT Trust Check Radar Lambda. Split from SECUR4ALL-186.
Depends on SECUR4ALL-185; deploys against the infrastructure resource contract.
May share a read handler; do not duplicate identity/binding libraries.

1. Implement proposed GET /v1/users/history, GET /v1/users/history/{requestId}
   and GET /v1/users/progress, or return an agreed equivalent versioned design.
   Derive the account solely from verified Cognito claims and enforce the
   approved device-binding policy. No direct client History/points writes.
2. Implement newest-first principal-scoped pagination, request-ID tie-breaking,
   response-byte limits, server timestamps, versions and invalidation metadata.
   Use account/query/snapshot-scoped expiring opaque cursors; no base64-only
   raw DynamoDB keys or identities. A signed clear-text cursor is not secrecy:
   use encrypted authenticated data or random server-side handles as needed.
3. Specify concurrent inserts/deletes using consistent snapshots or explicit
   refresh-required responses. Reject obsolete generations; short/empty pages
   must not imply deletions or suppress remaining continuation records.
4. Return original approved assessment, authoritative source and separately
   versioned recognition state. Unknown/absent recognition or points is not
   zero; temporary unavailability is not a successful empty snapshot.
5. Progress returns only the approved locale-neutral catalog and counters,
   version/reset generation, progress/targets and server unlock times. No
   model-derived confirmed-scam award or unapproved point formula.
6. Reads never charge scans, invoke the model, award progress or silently
   rerun missing history. Exclude deleted/expired data immediately and return
   private/no-store cache headers; never use shared response caching.
7. Publish schema, examples, exact auth/binding headers, errors and limits;
   test source values, pagination/Unicode/byte boundaries, unknown catalog
   values, stale binding, cursor tampering and cross-account IDs/cursors.

## Lambda story B: durable completion, replay and idempotent recognition

Owner: AMT Trust Check Radar Lambda. Split from SECUR4ALL-186.
Depends on SECUR4ALL-185; reuse SECUR4ALL-183 without reopening completed work.
ATCR-69 is a distinct unresolved old-result acceptance case.

1. Extend conversation-analysis at its existing RESULT_READY and atomic
   completion/quota boundary. One verified account/requestId/payload yields
   at most one retained History record, charge and qualifying contribution.
   Preserve pasted_text/ocr/mixed. Same-ID/different-payload conflicts remain.
2. Select and document bounded synchronous writes or durable async projection.
   For async, commit recoverable source/event atomically with completion; no
   best-effort publish after success. Define pending states, convergence SLA,
   bounded retries, DLQ/repair and retained-source lifetime, and notify infra.
   Optional projection failure must not lose the authoritative assessment.
3. Design long-lived lookup/minimal dedup separate from the 900-second replay
   TTL. Document post-expiry retries and duplicate-charge prevention without
   retaining deleted assessment content. Never use TTL cleanup as an erasure
   guarantee or silently reuse an acknowledged completed ID for a charged run.
4. Keep the original risk assessment immutable and existing V1 replay stable;
   expose later recognition through versioned History/progress refresh. Reads
   and old-event replay do not award twice. Repeated content under new IDs
   follows approved policy, not an invented client heuristic.
5. Gate commits/projectors with account deletion status and captured History
   and badge generations. In-flight work and delayed/redriven old events may
   not recreate deleted content or restore reset badges. Keep campaign consent
   independent and preserve existing campaign transaction guarantees.
6. Publish legacy/backfill policy. Investigate ATCR-69 with an authorized test
   account and privacy-safe diagnostics. Recover the original assessment when
   available; otherwise explicitly report unavailable/expired/deleted, never
   fabricate it or rerun it with a new charge. Fresh scans do not prove recovery.
7. Tests inject failure before/after result persistence, quota commit and
   projection; duplicate events, concurrency, lease takeover, reconnect and
   repair. Prove one logical charge/award and eventual discoverability or an
   honest unavailable state for unrecoverable legacy data.

## Lambda story C: History deletion, badge reset and lifecycle integration

Owner: AMT Trust Check Radar Lambda. Split from SECUR4ALL-188; coordinates with
SECUR4ALL-186 and SECUR4ALL-200. Not a replacement account deletion/export API.

1. Implement approved DELETE /v1/users/history/{requestId}, DELETE
   /v1/users/history and POST /v1/users/progress/reset with principal/binding
   authorization, separately specified mutation idempotency keys and receipts.
   Keep destructive API activation gated until acceptance passes.
2. Delete-one/clear exclude content immediately; clear uses a generation or
   cutoff that old clients/events cannot reverse. Reset is independent from
   History, advances award generation and only counts approved post-reset work.
   Define both in-flight completions and concurrent mutation/retry behavior.
3. Purge all relevant content-bearing copies: retained assessment/snippet,
   replay response, staged result, event/DLQ payload and caches. Retain only
   explicitly approved minimal dedup/tombstones for a defined duration.
   A replay cannot return a supposedly erased assessment or resurrect History.
4. Expiry read filtering is immediate; a bounded explicit purge/repair process
   meets the approved deadline. Backups/restores reconcile erasures before
   serving traffic. Tombstone expiry forces obsolete clients/cursors to reset.
5. Integrate new stores with SECUR4ALL-200's durable deletion intent and write
   fence, Cognito deletion and erasure receipt. Coordinate export inventory and
   owner; if the workflow does not exist, record the blocker, not fake success.
   Specify active/offline cache invalidation limitations for mobile owners.
6. Add privacy-safe evidence and tests for partial deletion, retry, expiration,
   restore, old-event redrive and in-flight completion after delete/clear/reset/
   account deletion. Reuse SECUR4ALL-196 cross-account acceptance. No mutation
   should silently reset independent progress without approved policy.

## Shared wire contract and client handback

SECUR4ALL-185 owns final versioned OpenAPI/JSON Schema and deterministic fixtures.
All implementation stories must return:

- Exact route methods, JWT issuer/client/scope checks and binding requirements.
  Existing analysis uses Authorization, X-Device-Binding-Fingerprint and
  X-Device-Binding-Version; state precise read/mutation requirements, distinguish
  X-Request-ID/correlation from mutation idempotency keys, and never trust a
  client account ID/hash or client score, points, badge or timestamp.
- History fields: schemaVersion, immutable requestId, exact sourceType, defined
  accepted/completed server times (proposed integer epoch milliseconds), record
  version, expiry/deletion state; no snippet; original privacy-reviewed bounded
  scamScore 0-100, riskLevel, confidence 0-1, summary, signals and actions.
  Specify every required/null/empty/unknown-enum rule. Tombstones have no content.
- Recognition absent means unsupported/unknown; proposed pending, awarded and
  not_applicable states, independently versioned. No points in this baseline;
  stable badge IDs and server unlock times. Recognition updates do not rewrite
  the immutable assessment or same-ID V1 response.
- Page: records, nextCursor/null, server time, snapshot token/version and
  History generation/invalidation. Progress: catalog/rules version, update
  version/token, reset generation, approved counters and ordered badge entries.
  EN/ES localization strategy; do not translate old analysis results silently.
- Exact status/envelope/retryability for auth, binding recovery, invalid/expired
  cursor, snapshot change, missing/deleted/expired results, malformed input,
  throttling and unavailable/pending states. Bounded retry guidance including
  Retry-After semantics; no empty/zero success or logout on transient failure.
- Golden fixtures for all sources, partial/full assessment, empty/populated
  pages, absent/pending/awarded recognition, approved and unknown catalog values,
  duplicate/reordered pages, cursor attacks/expiry, concurrent writes, invalidation,
  tombstone expiry, Unicode/control/bidi and serialized-byte boundaries.
- Android current limits are constraints to reconcile, not policy: 100/page,
  500 cached, encrypted 2 MiB cache, cursor <=1,024 printable ASCII characters,
  snippet 240 UTF-16 units, text fields 1,000 UTF-16 units, 20 signals, 10 actions,
  response 256 KiB. Android additive merge needs generation/reset migration.
  Do not equate UTF-16 units with code points or silently truncate assessments.
- Unit/integration and deployed Dev evidence; UAT acceptance uses two disposable
  accounts and two sessions/devices under the approved binding policy, covering
  recovery, isolation, pagination, replay, cache logout and stale data removal.
  Do not weaken binding policy merely to make cross-device tests pass.
- Contract/fixture paths, immutable commit/artifact IDs and manifests, actual
  per-environment availability, runtime settings, approved policy versions,
  consistency guarantees, remaining gaps and deployment/rollback/repair notes.
  No secrets or customer content. API deployed != Android integration accepted.

Android consumers: ATCR-85/86/87/88/89, later destructive flows ATCR-94/95;
testers ATCR-62/65. iOS consumers: existing cloud-state ITCR-39/41 and their
owner-confirmed follow-ups; return the same contract even if implementation is
later. Do not create another mobile umbrella story or close their work here.

## Execution gates and existing story refinements

1. SECUR4ALL-185 + ATCR-84: approve policy and contract; all new work depends on
   this gate for activation. Synchronous/asynchronous design and resource
   contract can be jointly refined before artifacts exist.
2. SECUR4ALL-186: retained coordination parent for infrastructure and Lambda
   read/completion children. Mark provisioned, artifact-tested, API-deployed,
   and mobile-accepted separately. No cloud-authoritative client imports.
3. SECUR4ALL-188: lifecycle/privacy parent for the mutation/erasure child;
   retains disclosures/backup operational acceptance rather than duplicating it.
4. SECUR4ALL-196: extend existing isolation suite with the exact History/cursor/
   generation/reset/replay matrix. SECUR4ALL-200 must inventory and fence new
   stores before account-erasure promises or release acceptance.
5. Build synthetic tests/artifacts, implement scoped Terraform, review plan;
   only then seek Dev deployment approval. UAT/Prod have separate readiness
   and promotion gates; no production authorization is implied here.

AWS design references: [transaction constraints](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Constraints.html)
and [expired-item filtering](https://docs.aws.amazon.com/us_en/amazondynamodb/latest/developerguide/ttl-expired-items.html).
Respect 100 unique items/4 MiB transaction and 400 KiB item bounds; do not assume
arbitrary cross-service atomicity or treat asynchronous TTL as precise erasure.
