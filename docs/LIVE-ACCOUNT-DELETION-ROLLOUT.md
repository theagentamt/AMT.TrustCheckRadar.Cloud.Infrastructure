# Live account deletion rollout

Current status, September 26: the four independently qualified inventory markers
are initialized with exact readback, and the current1480 key and registry are
initialized without changing older periods. Cleanup-only Dev worker configuration
is deployed and all six stack post-plans have no drift. Actual runtime validation
found and corrected a History checkpoint expression defect. All six actual
empty-work handlers now pass. Scoped HTTP admission
is deployed for the one prepared disposable identity. Its first request completed with twelve validated receipts, actual Cognito absence
and preserved unrelated records. The status-response correction is deployed and both isolated accounts completed
erasure. A final bounded token-rejection observation is underway after transient
HTTP503 made the second monitor inconclusive. No general accounts are admitted. Earlier
closed-preparation statements below describe the corresponding completed stages.

The owner requested live-deletion implementation on September 26. The immediate
path is an authenticated account request, durable cleanup of that account's data,
twelve verified component receipts, and removal of its Cognito identity. Whole-period
campaign HMAC retirement remains SECUR4ALL-207 lifecycle work; it is not required
before an individual account can complete while its period key remains enabled.

## Infrastructure implementation

`account_deletion_activation` is nullable and Dev-only. Null preserves disabled
configuration and creates no public deletion routes. The `workers` phase configures
the existing account-data handler, deletion stream and five-minute reconciliation
before admission. The `api` phase adds only JWT-protected POST and GET
`/v1/users/account-deletion`, requiring the Cognito user-admin scope and exact
method/path/account API Gateway invoke permissions. The Lambda derives the subject
from the validated JWT and enforces recent authentication for requests.

The activation object pins the exact account-data source and requires finalizer
inventory pins, recovery/outbox storage, the recovery index, monitoring and review
references for policy, identity, inventory and all component workers. The API phase
additionally requires a reference to the prior deployed worker acceptance. These
are operator attestations: Terraform does not verify evidence documents, write an
inventory marker, fabricate receipts, or prove that a deletion has completed.
`identity_finalizer_configured` reports configuration; completion-availability and
runtime-attestation outputs remain false because Terraform cannot establish them.

The exact twelve components are SESSION_REVOCATION, DEVICE_BINDINGS,
DEVICE_RECOVERY, ANALYSIS_ABUSE, HISTORY, CAMPAIGN, CAMPAIGN_OUTBOX, ENTITLEMENTS,
V1_AUTHORITY, PLAY_TOKENS, USER_PROFILE and IDENTITY. Configured completion means
those handlers have been qualified, not that any particular account is erased.
The runtime still verifies account-owned receipts and the independent inventory.
No retention values or business policies are changed.

Dev foundation selects the missing device-recovery control table under its existing
approved 90-day audit, seven-day receipt, 24-hour rate-state and seven-day PITR
policy. Provisioning the table does not authorize an account deletion. Its exact
name, PK/SK shape, TTL and bounded throughput are reviewed in the foundation plan.

The account-data permission fixes remove unsupported enclosing-operation context
from ConditionCheckItem. Profile Update and purchase Delete use the qualified
ForAnyValue transaction context and request no returned failed item. Their exact
ARN/key restrictions remain. The role still has existing broader ledger and other
cleanup permissions; these narrower statements do not override another Allow.

## Closed API/consumer compatibility

The original migration required an identical API/consumer source. Later independent
campaign updates changed the applied consumer release and consequently blocked
otherwise unrelated API planning. The new optional compatibility input pins both
exact SHAs and a review reference. Null retains the same-release rule; selection is
limited to Dev with consent disabled and the exact applied account/environment,
selected contract and paused consumers. It changes no API artifacts or gates.

The selected pair is API `d98ffd65b42d54953ad83e980e58846b6fc02c5d` and campaign
`f92285b50561397355a5fe2e466d297041336755`. Source review found identical shared
research-consent authority, notice/policy constants, feature contract and incoming
publisher contract. Added shared metadata handles bounded transient contribution
repair; it does not change the outbox consent envelope. Runtime admission remains
closed. This pair is not approval for subsequent releases or enabled research.
The deletion-only activation contract distinguishes paused research producers from
active cleanup workers. The API accepts this explicit research state and preserves
the prior all-consumers check when reading older contracts.

## Current evidence and exceptions

The merged period-admission prerequisite (Infrastructure PR85, Lambda PR59) was
applied in Dev on September 26: four pinned Lambda updates and four IAM changes.
Direct readback verified hashes, policies, three disabled mappings, four disabled
schedules, eight disabled recovery alarm actions and four disabled-handler checks.
The subsequent full campaign plan has zero managed and output changes.

The fresh Cognito/profile audit enumerated three identities: all three unique
Username/sub mappings match. Two PROFILE records match their subjects, with no
orphan profile. One FORCE_CHANGE_PASSWORD administrative identity has no PROFILE
and is not admissible to the current deletion API. It remains untouched and outside
this account-deletion qualification; it needs a separately verified onboarding or
administrative lifecycle path. Username/sub consistency does not mean the entire
inventory is approved. The observations are separate reads, not one snapshot.

The purchase/profile/ledger IAM fixture passed 13 grouped actual AWS cases; all
three synthetic tables and the temporary role were removed. It validates relevant
identity-policy behavior and atomic rollback, not Cognito, every other component,
SCPs/resource policies or actual full-account erasure. Local audit tests ensure
bounds and prevent personal identifiers from entering the retained report.

## Activation and shutdown sequence

1. Deploy reviewed source and permissions for every receipt producer, including
   the campaign repair fixes and refreshed account-data recovery enrollment.
2. Qualify current storage, retained periods/locators, authority/purchase coverage
   and identity mapping; write only a genuinely reviewed manifest and matching
   inventory controls. No empty scan, TTL age or passing mock can substitute.
3. Enable workers, verify durable recovery and alerts at support@andmorethings.com,
   and record actual deployed worker acceptance.
4. Expose authenticated HTTP admission only for designated synthetic subjects and
   qualify end-to-end identity removal, component receipts and credential rejection.
5. Evaluate broader rollout separately against remaining evidence and environment
   gates; successful scoped Dev tests do not admit other accounts automatically.

To stop admission, change `api` to `workers` first. Remove the public route/invoke
grant, wait past the maximum in-flight request timeout, then confirm newly accepted
and pending requests have reconciled before changing `workers` to null. An empty
backlog observed before admission drains is not sufficient. Terraform cannot enforce
transition history; null is not a safe routine one-step rollback of active requests.

No existing customer account has been selected for deletion by this rollout work. Export, paid
provider checks and physical-device testing are independent; they do not gate backend
engineering. SECUR4ALL-200/207/245 remain open until their actual acceptance is met.

## Account-cleanup source and qualification

[Lambda PR60](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/60)
integrates source `f92285b50561397355a5fe2e466d297041336755` at release merge
`223e9bea5b109131de98bf2b07251a8f7877eeb1`. Five exact-source production archives
were independently verified and published to immutable Dev object versions.
Frozen-candidate deletion now repairs and resumes without extending deadlines;
published aggregates retain their approved anonymous form while linkable transient
pairs are removed. A lost final repair acknowledgment no longer strands the cursor.
Publication checks all included contributor tombstones and refuses transactions
beyond the DynamoDB bound rather than silently omitting contributors.

The 48-case Python 3.14 ARM64 AWS fixture passed. Its two added cases exercise
actual campaign cleanup through a CAMPAIGN receipt, sealed control and finalizer
DynamoDB proofs. Cognito and other-component receipts/inventory are injected, so
this is not evidence of live identity removal or erasure by all twelve components.
The fixture still models intelligence in the isolated pipeline table and uses one
key for two periods; separate new-grant IAM tests cover distinct table resources.
See [runtime results](evidence/live-account-deletion-2026-09-26/runtime-results.json),
[package manifest](evidence/live-account-deletion-2026-09-26/production-manifest.json)
and [publication](evidence/live-account-deletion-2026-09-26/publication.json).

No actual inventory approval or live-generation assignment is inferred from these
results. New Dev account-data source is selected with activation null. The full
account endpoint remains unavailable until coordinated component acceptance.

The three new campaign aggregate/tombstone grants passed 14 isolated AWS IAM cases.
The supplied role audit found no existing action/resource/key-namespace overlaps
for those grants. This is new-grant qualification, not a full deployed-role test.
Both temporary tables and the role were removed. The separate runtime fixture's
three tables, role and function were independently confirmed absent; its key is
PendingDeletion for October 3, not destroyed. Local API Terraform validation passed
133 cases. The final full campaign Terraform suite passed all 36 cases, including the
exact-key encryption permission regression.

## Campaign table encryption access

The current key policies delegate authorization to IAM. Existing table-specific
DynamoDB service grants do not demonstrate caller authorization for the deletion
role, whose prior policy contained only period-key GenerateMac access. Preparation
adds Decrypt on exactly the transient and persistent campaign keys, constrained to
this account and regional DynamoDB through kms:ViaService. It grants no direct
KMS use or key management. The default-encrypted IAM fixtures do not qualify this
CMK path. The later actual-role probe and delayed CloudTrail correlation below qualify the
fresh decrypt path; the original IAM fixture alone does not establish it.

## Closed deployment verified

Infrastructure PR86 merged at `4135af1b5143a92fd443a61c75224b9dc0920c6e`.
The recovery control table, four f922 campaign packages, exact cleanup/decrypt
policies and f922 account-data package were deployed manually to Dev. API recovery
storage wiring also refreshed account export and device-recovery configuration;
self recovery remains false and the operator allowlist is empty. Direct readback
matched package hashes, environment and policies, confirmed seven-day recovery
PITR/TTL and no public deletion route. Full foundation, campaign and API plans all
reported no differences after deployment.

A temporary function using the actual deployed deletion role successfully made
strongly consistent, projected reads of absent synthetic keys in both encrypted
campaign tables. It made no table writes and returned no item data. The function
and its possible log group were removed; the production function was unchanged.
The immediate CloudTrail lookup was empty. A delayed bounded lookup then confirmed
successful Decrypt events for both exact CMKs, the unique temporary function role
session and matching DynamoDB table encryption contexts. Both observations remain
in the evidence; the delayed result qualifies fresh KMS access for this probe.

## Deletion-only activation control

`campaign_deletion_activation` is null by default and is not selected in Dev.
It pins the reviewed campaign source, UUIDv4 generation and three manifest/revision
pairs, requiring existing cleanup preparations plus inventory/runtime/encryption
evidence. Selection enables only the deletion bridge, ledger stream, five-minute
recovery and its alerts. Research publisher, aggregator and whole-period lifecycle
remain paused under the global kill switch. This object does not create or approve
inventory records; live workers independently verify their exact stored proofs.
The all-consumers output becomes false when cleanup is active; a separate research
producer output stays true, avoiding a false claim that all consumers are paused.
All-component nonempty fixtures and synthetic Cognito deletion remain outstanding.

Turning `campaign_deletion_activation` back to null stops accepted campaign work.
First close public admission, drain in-flight requests and reconcile all accepted
account/withdrawal work; only then stop the campaign workers. Their stream and
schedule both wait for the required runtime policies during initial activation.

Lambda PR61 source `997e265f7edf10ce7369481f7d576b4276e8c418`, merged at
`218769da5b482f98b8cb7e0be93d16e656c38c3e`, adds a fail-closed configuration
check requiring durable campaign recovery enrollment whenever deletion is enabled.
Only config.py differs in the account-data package; all campaign pins remain f922.
The independently verified immutable account-data version is now selected in Dev
with activation still null. Local validation passed 44 tests, 20 subtests and eight
SDK cases. Package publication is separate from deployment acceptance.

Infrastructure PR87 merged at `4f11ae989d3075a5439ae9611729dba4040cefc7`.
The 997e account-data guard is deployed and directly read back with unchanged
disabled environment and no public deletion route. Full API planning reports no
drift. Campaign control outputs and alarm descriptions were applied with all gates
and alarm actions still disabled. The unprofiled administrative identity exception
is tracked in SECUR4ALL-327; it was not changed or deleted.

## Dependent cleanup workers

The History bridge and lifecycle packages are pinned to reviewed Lambda source
`997e265f7edf10ce7369481f7d576b4276e8c418`, with independently verified Python
members, immutable S3 versions and disabled-handler checks. The proposed Dev plan
updates only those two packages/runtimes and their two IAM policies; Python 3.14
replaces 3.13/3.12. All consumer gates remain false. ConditionCheckItem receives
namespace-scoped permission without unsupported enclosing-operation context;
receipt Put uses ForAnyValue transaction context and NONE returned values. Existing
lifecycle control writes remain broader and are explicitly tested as such.

Three separate, null-by-default activation objects prepare later coordinated
cleanup. History requires terminal-safe source, runtime/IAM references and existing
observability/runtime policy gates. V1 authority and Play token cleanup each require
an exact deployed source, one to ten explicitly named subjects and inventory,
runtime and permissions references. They enable only deletion workers and recovery;
they grant no provider or paid-access activation. No activation object is selected
in Dev. These attestations are not substitutes for actual evidence or admission
scope alignment. Do not open public account deletion while downstream workers
accept only a designated test subject.

History and V1 stream discovery now separate ListStreams (regional Resource `*`,
as required by AWS) from exact-stream read permissions. This grants no base-table
read through the stream statement.

## Campaign inventory and restore boundary observations

The September 26 complete, strongly consistent base-table traversals found the
same two period registry rows before and after; the outbox and intelligence tables
were empty. Their exact resource lineage and backup settings were recorded. These
are current-state observations, not historical per-account erasure or approved
inventories. The retired legacy key was not found, while its old registry remains.
Do not fabricate a locator or completion marker to conceal that limitation.

The enabled campaign-review API was independently bound byte-for-byte to tracked
source: it cannot create an absent aggregate, and updates require state/version
checks. It must nevertheless remain in the restore-quarantine inventory because
it can mutate a restored aggregate. The trends API is read-only. Any restore or
resource rebinding must invalidate prior generation/manifest qualification, keep
all writers including review quarantined, re-enumerate restored data and key
coverage, then qualify fresh manifests before attaching the restored tables to
runtime roles. Existing PITR retention is disclosed; a clean live scan does not
prove those backups contain no historic contributions. The observation includes
the known managed deployment scope and the owner's statement of no known manual
copies, not a claim to discover all possible unmanaged copies.

Both History execution-role policy projections passed all twelve grouped cases
against actual isolated AWS resources (24 total), including conditional atomic
rollback, permitted namespace checks, forbidden returned items and standalone
receipt writes. The three temporary tables and fixture role for each run were
removed. The harness binds the exact Terraform plan and complete dated role audit;
it rejects unknown overlapping grants and preserves the measured broader legacy
lifecycle behavior. This is IAM/atomicity evidence, not actual worker execution,
KMS encryption acceptance or live deletion qualification. See the two `history-*-iam.json`
evidence files. Local validation passed 23 History contracts, 21 URL integration
contracts, 13 Play runtime contracts and 12 harness tests (normal and optimized).

PR89 was merged into release-V01 at `68c83891ca2125b1887b8f1ac637910d2b350645`.
The reviewed History four-resource update and authority one-policy update were
applied to Dev. Exact History package hashes, Python 3.14 runtimes, policies and
disabled streams/schedules were read back successfully. Subsequent full History
and authority plans showed no drift; Play's plan had no managed changes. No live
activation object was selected. The readback is preserved alongside the evidence.

Actual disposable Cognito acceptance now passes both normal finalization and
recovery from a lost successful-delete acknowledgment. Lambda PR64/65 and
Infrastructure PR90 are integrated in release-V01; the runtime source is
`2f497f13ff4276aef696a3622f46157776f228af`. This removes the isolated identity SDK
integration gap, not the remaining application inventory, deployed-worker and
authenticated API acceptance requirements. All live activation gates remain off.

## Scoped Dev HTTP admission

The first authenticated Dev route test must accept only the same expressly
selected subjects as V1 and Play cleanup. `account_deletion_activation.http_subjects`
is empty in workers mode (routes absent, runtime HTTP closed) and requires one to
ten canonical lowercase UUIDs in API mode. UUIDv7 Cognito subjects are supported.
The exact sorted list is passed as `ACCOUNT_DELETION_HTTP_SUBJECTS_JSON`.

Reviewed account-data source `65df9c7e7fe338f00df8ecc13795014ab928cdfa` validates
JWT claims first, checks this HTTP-only list before service construction, and uses
the existing fixed SERVER_UNAVAILABLE/503 response for missing, malformed, empty,
non-Dev or out-of-scope admission. GET and POST have the same scope. Worker stream
and reconciliation paths do not use the HTTP list. This is bounded Dev acceptance,
not a general production rollout; no route or subject is selected yet. Eighteen
focused Terraform tests passed, including UUIDv7, missing/bad/noncanonical/excess
subjects and rejection of HTTP subjects in workers-only mode. Independent Lambda
review verified the exact21-member package and handler tests.

The new package changes the account-data writer source binding. Earlier campaign
cutover evidence remains historical; repeat final source/role/gate and strong
inventory checks after this closed deployment before writing qualified markers.

## Scoped HTTP guard installed, inventory qualification continuing

Infrastructure PR92 integrated at `a216c3a65b07ae1674cd68c3fa913824dfc8f1b1`.
The sole reviewed Dev change installed account-data65df; direct readback matched
its immutable hash and all unchanged environments/policies, with deletion gates
false and routes absent. The subsequent full API plan had no drift.

The five-store full-read audit recognized all observed profiles, participation,
operation receipts, retained consent audits and device bindings. Recovery, abuse
and shared URL cache were empty. Existing entitlement controls and legacy usage
are independently classified; no unknown family remains in observed rows.
These observations are not marker approval or historical backup erasure. Final
writer binding and post-installation campaign qualification precede any marker.

The separately reviewed create-only current-period key operator uses bounded
metadata discovery and a durable single-attempt journal. AWS-managed keys are
excluded only after exact DescribeKey classification. It never changes existing
keys, writes a registry or approves inventory; those remain separate operations.

The fresh campaign audit passed after the installed HTTP guard and a new closed
writer boundary; its sole allowed source difference is the reviewed65df package.
The create-only period1480 key plan passed independent review and execution,
including full discovery before/after creation; the absent registry remains
untouched. No legacy key was changed or scheduled for deletion.

The prepare-only Dev account harness passed independent review and sixteen local
tests. It created one unique disposable example.invalid identity with message
delivery suppressed and invoked the exact deployed post-confirmation writer to
create a genuine PENDING_AGE_GATE profile. Its private atomic journal preserves
the owned subject and original operation; no password or JWT was persisted. This
is administrative bootstrap, not native signup-trigger delivery qualification.
No deletion request, inventory approval or runtime activation has occurred.

## Final writer boundary

The 13-store writer audit binds all 31 functions and execution roles, versions,
aliases, API integrations, Cognito hooks and stream/scheduled targets. Current
managed ingress does not select the four retained enabled historical versions;
the serialized operator must not invoke or rebind those versions. Such changes,
restores and unreviewed source/role changes invalidate the inventory qualification.

History reads stay disabled. Their current cursor Put needs an atomic account
deletion fence before read activation; follow-up SECUR4ALL-328 owns that concrete
fix and permission/race qualification. The inactive path does not block the scoped
Dev deletion test. No retained usage or audit records were changed.

## Qualified inventory and cleanup-only activation candidate

The independent reviewer verified all four immutable manifests and all 28 evidence
digests, then the external approval and exact four-row plan. The reviewed source
initializer conditionally created all four markers in one transaction and verified
exact readback. It did not infer approval from an empty scan or alter existing
ownership/HMAC controls. The independently reviewed period initializer then created
only absent current1480 with the matching locator manifest/generation and verified
its readback; both old period rows and keys remain unchanged.

Four saved cleanup plans pass every Terraform check and change no Lambda code:
campaign deletion processing, terminal-safe History cleanup, and subject-scoped
V1 authority/Play token cleanup. They enable reconciliation and appropriate alarms,
including twelve new History alarms. All research, providers, access engineering
and History read/mutation admission remain closed. API phase is workers-only with
an empty HTTP subject list and no routes; its final deployment plan follows the
campaign state update. The sole selected V1/Play subject is the newly prepared
disposable identity. No deletion command exists yet.

The final preactivation check found and corrected two infrastructure gaps before
any worker was enabled: the support SNS policy omitted thirteen account-data and
six Play cleanup alarm ARNs, and campaign ListStreams was incorrectly scoped to
a stream ARN. The replacement plans add exactly those nineteen CloudWatch source
ARNs and separate regional ListStreams discovery from exact-stream record reads.
All existing data mutation grants remain byte-equivalent by statement. This
reviewed cleanup-activation delta supplements the original closed-role binding;
it does not expand data-writer admission or invalidate the unchanged qualified
source/inventory. Both existing topics have confirmed support@andmorethings.com
subscriptions. No alert message was sent as part of the read-only check.

Eight campaign activation and fourteen resolver security tests pass. The old
campaign activation plan is withdrawn; only the replacement v2 plan is eligible
after independent review. Other three cleanup plans are unchanged.

## Worker deployment accepted as configuration

Infrastructure PR94 merged at `4de3cfddb008191162d400681927724e27561ffa`.
After the SNS policy update, the replacement campaign plan and unchanged History,
V1 authority and Play cleanup plans were applied. The separately reviewed API
workers-only plan passed exact review: seven in-place changes, adding only
AdminGetUser/AdminDeleteUser for the existing Dev Cognito pool while preserving
all prior IAM statements and keeping the HTTP subject list empty and routes absent.
Its immutable plan digest is `c4b649c4b9350025337c740fd693ef02089a44abad25dd03911162c5e4f9b29f`.

Direct readback matched all changed function environments/code, published aliases,
stream mappings, reconciliation schedules, policies and alarm actions. All six
subsequent full plans report no drift. This proves deployed configuration; actual
empty-work reconciliation invocations and authenticated disposable-account
erasure remain separate acceptance steps.

The first actual empty-work attempt passed account-data, campaign cleanup and
History bridge reconciliation, then stopped at History lifecycle without claiming
a pass. The deployed History failure/error alarms were already active. The initial
partial report is retained; HTTP admission stays absent while the Lambda owner
diagnoses the runtime failure. No deletion commands or synthetic receipts were
injected. Configuration/no-drift acceptance is not runtime health acceptance.

Bounded log diagnosis identified a concrete source defect: both History lifecycle
checkpoint updates reference the DynamoDB reserved keyword `shard` without an
expression-name alias. Fourteen observed ValidationExceptions match the same
checkpoint frame; the sanitized diagnostic retains only error categories/counts
and source locations, with no raw log messages. The correction belongs to Lambda;
no IAM expansion or permission bypass is needed.

Actual CloudWatch/SNS evidence confirms five other cleanup workers emit successful
reconciliation metrics. History lifecycle has failure metrics and no successful
sweep yet. Both alert topics retain exactly one confirmed support subscription;
CloudWatch action history and SNS aggregate counters show published/delivered
notifications with no observed failed notifications. This proves the service
pipeline, not receipt in a person's inbox. The initial alarm states are preserved.

The read-only test baseline covers thirteen table identities and twenty-three
existing non-target rows by hash, excluding documented mutable global cursors.
The private baseline is not committed. Final observation must preserve every
baseline row and validate the original operation and all twelve genuine receipts.

The independent review approved source `1dd917057527e58cf07c70eb0155991cb6c5bb3c`
and both deterministic History archives. All twenty-six archive members matched
the frozen Git source. The bridge archive is byte-identical to the prior deployed
version; the lifecycle change only aliases `shard` in two checkpoint update
expressions. Eighteen source tests and twenty-three mocked infrastructure tests
pass. This narrow correction supplements the qualified inventory's writer binding:
it changes no schema, admission gate, IAM grant, receipt semantics or data family.
Original inventory markers are not rewritten. Actual deployment and successful
reconciliation must still be verified before HTTP admission.

After PR95 integration, the exact History-only plan was applied and direct
readback matched every changed artifact and preserved environment. The subsequent
History plan reported no drift. All six real cleanup invocations then passed with
no deletion commands or receipts injected. The repeated plan updated only the
verified History code/revision pins; the reviewed helper retained actual outcomes.

The next API plan selects only the prepared disposable subject, retaining all
worker flags and adding exact authenticated GET/POST routes. It authorizes no
other account or device test. The private original operation journal and hashed
other-row baseline remain the test inputs; successful HTTP acceptance is distinct
from final erasure evidence.

Scoped API plan `3aa9692489bfa6d95d53f6268898f975dcb8caf3d41307f717210de870e20b92`
passed independent review: five exact authenticated route/integration/permission
creates and one environment change containing the prepared subject. No source,
role grant, other environment or admission changes occur. Eighteen activation
contract tests pass. History successful-sweep metrics are now ingested and its
heartbeat/expiry alarms recovered; older error/failure alarm observations remain
visible while evaluation windows drain. The broad monitoring reread was throttled;
a bounded targeted metric/alarm read succeeded without changing alarm states.

PR96 integrated at `7f43a43a668c0e23a22693dfc6dbfbccdaf06190`; the exact scoped API
plan was applied, direct readback verified both routes/authorizer/permissions and
the sole account allowlist, and the full API post-plan had no drift. The reviewed
operator authenticated the owned disposable identity and the actual HTTP endpoint
accepted its single original operation with 202. No credentials were persisted.

The postacceptance monitor ended inconclusively after its first GET observation;
its private journal remains ACCEPTED and no second POST/password reset occurred.
Nine genuine component receipts were observed. Analysis cleanup advances one
family per pass and reached family index3; USER_PROFILE/IDENTITY correctly wait
for its receipt. A source review found a separate pending-status serialization
defect with DynamoDB Decimal timestamps. The Lambda owner is reproducing and
correcting it. No completion or token-rejection claim is inferred from acceptance.

The first accepted operation completed through the genuine scheduled workers:
twelve source-validated receipts and the original operation match, recovery
sidecars are absent, the user partition is empty, and actual Cognito AdminGetUser
reports the identity absent. Every one of the twenty-three baseline unrelated
rows across thirteen unchanged table identities is preserved. No manual receipt,
command repair or Cognito deletion was used. Its token monitor remains separately
inconclusive; successful erasure does not rewrite that result.

Lambda PR70 source `eba5d938c1da5cf36540cf654e674f46bba3fa71` fixes only native JSON
conversion of the already-validated pending-response timestamps. The reviewer
verified all twenty-one package members against Git and found only service.py
changed from the deployed source. Actual SDK/handler regression covers persisted
GET and duplicate POST responses and preserves malformed-record rejection. The
first live unretained error is not retroactively labeled with an observed status.
This response-only correction changes no data writer, schema, receipt, retention
or inventory admission; it is an explicit narrow supplement to source bindings.

A second uniquely created suppressed-delivery disposable identity has a genuine
pending-age profile and its own durable operation journal. It is prepared solely
to qualify corrected pending HTTP and token rejection without retrying/resetting
the completed first account. The three subject lists select only the second
identity after first completion. Actual enrollment is administrative bootstrap,
not proof of native signup-trigger delivery.

The second test baseline was captured after the first terminal result, covering
thirteen table identities and thirty-seven non-target rows, including retained
first-operation proof. The second admission plans only replace each exact
single-subject list and publish corresponding V1/Play cleanup aliases; the API
also installs the reviewed response-only correction. IAM, unrelated environments,
retention and general admission remain unchanged.

PR97 integrated at `988fd03cbada0cd6685a8b6a3149444c5e3e6626`. All three reviewed
plans were applied in dependency order. Exact readback verified the reviewed
account-data hash, routes/authorizer/permissions and both cleanup aliases with the
second subject only; all three updated stacks report no drift. History error,
failure, heartbeat and expiry alarms are now all OK, with real success metrics.
The second distinct original operation was accepted through HTTP202 and its
reviewed token monitor continues in memory while the scheduled workers complete.

## Acceptance boundary

The live tests use newly created otherwise-empty disposable accounts. Their real
HTTP, scheduled-worker, DynamoDB receipt and Cognito evidence complements the
prior populated-family/failure fixtures; it is not equivalent to full UAT or a
broader account rollout. SECUR4ALL-200 retains its UAT and complete criterion-to-
evidence mapping. SECUR4ALL-207 retains whole-period lifecycle/key retirement
and delayed/restore work independently of individual erasure. SECUR4ALL-245
retains its restore/replay and full resource-coverage acceptance until mapped.
All three stay open; unavailable physical devices or mobile work are not blockers
for their independent backend acceptance. No Production or general account
admission is implied by these scoped Dev results.

The second account completed naturally with all twelve validated receipts, actual
Cognito absence, an empty user partition, no recovery sidecars and all thirty-seven
baseline unrelated rows unchanged. The corrected monitor ran ninety-two iterations; its final HTTP observation
received503 and the strict monitor ended
inconclusively. The503 is not proof of access rejection. Reserved concurrency1 is
shared with cleanup, so transient handling is appropriate; concurrency remains
unchanged and no precise request-level throttle cause is asserted.

Lambda PR71 source `0e3ece226c9f6f116bbc0606eebfa203d81e0748` changes only the operator
monitor: bounded GET transport/429/500/502/503/504 retries preserve the600-second/
120-poll ceiling, same-poll dual denial and postnetwork pre-expiry checks. A
persistent transient remains inconclusive. Twenty-two normal/optimized tests
pass; no production artifact or prior operation was changed.

A third isolated identity is prepared for this credential-only acceptance gap.
The prior two scheduled completions remain authoritative and untouched. Third
cleanup may use at most three operator-triggered real reconciler ticks after its
one HTTP request, guarded by exact source/revision/single-subject configuration
and a full strong ledger pass rejecting every other pending command. No command
or receipt is injected. Six normal/optimized tests check containment and bounds.
Terminal-status observation from those ticks is not completion evidence; the
independent twelve-receipt/Cognito/baseline observer must still pass. The third
baseline covers thirteen table identities and fifty-one non-target rows.
