# V1 Google Play billing: scoped Dev delivery

SECUR4ALL-244 coordinates infrastructure with SECUR4ALL-195/125 for Android-first
billing. This document describes source under review, not an activation or a
successful store purchase. Apple reconciliation remains SECUR4ALL-175; it does
not block independent Google component delivery.

## Agreed commercial and accounting behavior

- Individual plan: $4.99/month, 200 completed user checks per newly verified
  funded subscription period. A calendar month or an RTDN event alone never
  creates another allowance.
- Explicitly activated trial: seven days or ten completed checks, whichever
  ends first. Preparation, verification and opening History do not consume
  checks or reset the trial. Existing trial/device/account state is preserved.
- Each logical check counts at most once across its internal services/retries.
  Failed, partial and inconclusive checks do not count. Reopening a stored result
  never incurs another check.
- Unpaid, expired and exhausted accounts retain authenticated built-in features;
  external reputation and AI require authoritative access and remaining checks.
- Cancellation preserves verified access through its end. Grace and deferral
  retain only remaining checks until another funded period is verified.
  Recreating an account and restoring the same purchase cannot refill that period.
- Complimentary access bypasses subscription/allowance only; account/device,
  rate, concurrency and provider-budget controls continue to apply.

## Independent activation boundaries

Both roots default to closed billing. The optional activation inputs require one
canonical Dev subject, matching immutable Lambda source, and inventory/runtime/IAM
qualification references. Supply the one approved billing subject through the
independent encrypted `BILLING_ENGINEERING_SUBJECTS_JSON` environment secret.
There is no fallback to History selection. Preserve the existing
`GOVERNED_HISTORY_ENGINEERING_SUBJECTS_JSON` secret and all unrelated selections;
subjects are never printed in summaries or newly committed here.

| Root / mode | Enabled work | Boundaries |
| --- | --- | --- |
| play-verification / preparation | Authenticated account/device binding preparation | No Google call, paid grant, purchase verification or trial reset |
| play-verification / verification | Preparation and foreground verification of a Google-confirmed license-test purchase; encrypted retention of its token | Exact package/product/P1M base plan; one account; test purchases required |
| play-lifecycle / ingress | Authenticated Google notifications for an already-owned purchase head | Unknown, other-account and deleted-account purchases cannot initiate a provider discovery call |
| play-lifecycle / background | Ingress plus one-account scheduled current-head reconciliation | One selected head per invocation; no token-table Query/Scan, global checkpoint or global expiry sweep |

The scoped worker requires `PLAY_SCOPED_LIFECYCLE_WORKER_ENABLED=true` and
`PLAY_SCOPED_OWNED_HEAD_ONLY_ENABLED=true`. Global `PLAY_TOKEN_CLEANUP_ENABLED`
and `PLAY_CHECKPOINT_POLICY_APPROVED` stay false on that worker. IAM removes its
token-table Query/GSI and checkpoint grants and explicitly denies token enumeration
and `PLAY#CONTROL` access. Account, authority, retained-key, purchase ownership and
token observations remain coupled to conditional writes.

Existing token deletion retains its separate package correction, subjects, stream,
schedule and heartbeat settings. The billing package override cannot replace its
artifact. Every active billing plan and immediate pre-apply check requires the
selected billing subject to be admitted by the existing active token-deletion
runtime. The metadata prerequisite checks the reviewed package, live alias,
cleanup-only gates, tables/policy, concurrency, schedule and ledger stream. It
uses control-plane reads including `lambda:ListEventSourceMappings` and
`scheduler:GetSchedule`; denied reads fail closed. Metadata does not prove
actual erasure. Missing subject coverage requires a separately reviewed cleanup
plan that preserves existing subjects and all other deletion settings; this
workflow never widens cleanup automatically. Unrelated message, governed
History, entitlements, analysis providers,
export and deletion services are outside this transition. UAT and Production
are outside the workflow.

The owner approved the optional global worker's five-minute linkable cursor
policy on 2026-10-04, including logical rather than guaranteed physical expiry.
Global traversal still requires separate scope and runtime qualification.
Scoped current-head reconciliation neither reads nor writes that cursor.

## CI/CD plan and apply

On 2026-10-10 the owner explicitly authorized publication and reviewed integration
into **main** for this Android billing gap-fix effort. This is a scoped exception
to the default `release-V01` integration policy, not a blanket branch merge or
release promotion. The fix branch is `codex/billing-account-isolation-dev`, based
on the published main source; unrelated feature history is not imported.

A main merge triggers validation CI only. Deployment, billing transition and IAM
workflows remain manual `workflow_dispatch`; source integration does not apply
an IAM grant, change account selection, activate a runtime or approve a purchase.
Use `.github/workflows/billing-dev.yml` on main only after the separate exact
source/scope/digest and security/cost approvals. Unit tests do not establish live
endpoint or store acceptance.

1. Review and integrate source; verify successful main CI and immutable Lambda
   package publication. Supply `BILLING_PACKAGE_HASHES_JSON` as a JSON object with
   `source_sha` and exact hexadecimal SHA256 values keyed by `v1_play_handoff`,
   `play_lifecycle_ingress`, and `play_lifecycle_worker`. Set
   `BILLING_EVIDENCE_JSON` with the three reviewed reference fields:
   `inventory_reference`, `runtime_reference`, `permissions_reference`.
   The reviewed Lambda source and successful publication are recorded in
   `docs/evidence/sec244-billing-package-provenance.json`. Its public package
   hashes contain no account selection, purchase tokens or credential values.
2. Qualify current Google catalog/permissions, ownership inventory and token
   expiry/account-erasure/export behavior. Run a fresh metadata-only token audit;
   no-backup posture includes AWS Backup selections and execution roles, not
   merely table PITR. Missing audit permission is a deployment prerequisite,
   not permission to skip the audit. No original URLs, messages or token values
   belong in public evidence.
   The metadata audit needs four AWS Backup inventory actions and `iam:ListRoles`
   that the original deploy-role source does not grant. The separate
   `billing-inventory-access.yml` workflow can plan that exact read-only inline
   policy. Obtain approval of its source/policy digest before apply; it grants
   neither backup operations nor access to token records. Existing inline grants
   are preserved. Read back it and prove effective audit access before billing apply.
   Use `execution_mode=qualify` with the exact source revision and policy digest
   to prove the two schedule reads plus group and tag reads through the actual
   GitHub OIDC deployment role. This mode requires the installed policy to match,
   reports only resource states/counts, and performs no policy or runtime writes.
   An AdministratorAccess read or IAM simulation is not actual-role qualification.
3. Dispatch `execution_mode=plan` for the selected scope/mode with exact
   infrastructure `expected_revision` and `lambda_source_sha`. The preparer
   downloads version-pinned packages and checks their hashes. The guard rejects
   drift, deletion/replacement, unrelated changes, mismatched aliases, extra
   subjects and global worker gates. Raw plans/configuration stay private on
   the ephemeral runner; only minimized counts and the digest are published.
4. Obtain owner approval of that exact revision, scope, mode and plan digest.
   Dispatch `execution_mode=apply` with the same inputs and
   `reviewed_plan_digest`. A changed plan is rejected. Re-audit token storage
   and fingerprint unrelated Dev live runtimes before apply. Verify billing
   aliases, package/gates, concurrency, IAM/schedules, unrelated runtime
   preservation and zero drift afterward. Apply is configuration evidence,
   not a purchase/renewal acceptance result.
   Lifecycle apply also requires a hash-matched, unweighted foreground handoff
   live alias with the same source and account selection and enabled verified
   test-purchase/token-retention gates. Both lifecycle packages stay pinned across
   ingress/background/inactive transitions. Stopping the worker closes its
   schedule/heartbeat while retaining the token enumeration/checkpoint denies.
5. Preserve the reviewed selected configuration for subsequent billing runs.
   Ordinary deployment has no billing scope; do not perform a blanket Dev apply
   or remove existing message/History/access selection. Any later deactivation
   or artifact change needs its own reviewed plan; do not improvise a rollback.

The first preparation plan stopped on a stale IAM role `inline_policy` mirror:
the role's cached copy predated the tracked KMS condition correction, while both
separately managed policy resources and the live policies already matched source.
The guard accepts only this selected handoff role mirror when its refreshed
complete two-policy set equals both unchanged, separately managed policies and
the planned role is unchanged. Extra/missing/modified policies, trust or boundary
changes, policy writes, other roles and all other drift remain rejected. The
original mirror observation remains part of the approved plan digest. This check
does not grant or rewrite IAM, refresh backend state manually, or authorize apply.

Do not dispatch apply until source, audit access, artifacts and behavioral
prerequisites are qualified. The workflow does not create a Google subscription,
configure Play Console, initiate a purchase or change an account.

## Required Dev and release evidence

Before paid-launch acceptance, record actual Google evidence separately from
SDK/mock results:

- License-test foreground verification and acknowledgment; repeated delivery
  cannot transfer ownership or create a second funded allowance.
- Authenticated Pub/Sub test delivery with the approved 600-second pending-message
  retention, no acknowledged-message retention, snapshots, DLQ or extra queue.
  A test notification proves transport only, not a subscription transaction.
- Renewal, cancellation, grace/hold, expiration and refund/revocation; late or
  duplicate events cannot refill or restore obsolete access. Scheduled recovery
  must converge when a notification or acknowledgment response is missed.
- Fresh account/device fencing and negative unknown/other/deleted-account cases;
  no provider call or row mutation on rejected scope. Failed provider observations
  do not fabricate access or allowance values.
- Complete-only charge settlement and retries, paid-period restoration retaining
  used checks, unchanged trial, zero-charge History reopen, correct Android
  authoritative snapshot refresh. Test the actual configured candidate.
- Token expiry and account deletion remove the scoped retained token; export
  includes the authorized user-visible scope without disclosing purchase tokens.

Google transport setup is documented in `PLAY-NOTIFICATION-SETUP.md`; its older
setup record must be refreshed rather than assumed current. Reuse ATCR-112/114
for store/access end-to-end evidence and SECUR4ALL-334 for broader allowance
qualification. Physical-only cases remain in ATCR-148. Do not close retained
Dev acceptance merely by transferring it to QA. Independent component completion
and V1 paid-launch readiness are separate.

## Dev GET-only Pricing/Access selection (SEC195 / SEC244)

This is separate from purchase preparation, verification, trial activation and
History. The owner approved implementation and review on October 9, 2026; that
approval does not authorize a runtime apply. Android ATCR-170 can opt into the
fixed authenticated `GET /v1/access` route independently of purchase flags.

The existing schemaVersion 1 / owner-2026-09-20-v1 response is unchanged. An
admitted account without an active binding can receive an advisory snapshot with
`activeDevice=false`, `access.reason=ACTIVE_DEVICE_REQUIRED` and external checks
disabled. When no effective grant/period exists, allowance values are null;
clients must not invent a paid or trial allowance. Existing authority refresh
writes can occur during a GET, but this path neither grants nor activates trial.
Extra-only subjects always see `trial.activationAvailable=false`. Account, age,
deletion and JWT checks stay intact; no device registration is needed merely to
display this state.

`dev_access_snapshot_extra_subjects` is a sensitive, default-empty Dev-only set
of at most one distinct canonical UUID. Its environment key is emitted only on
the entitlements function and is interpreted only for exact GET route + method.
The original `DEV_SUBJECT_ALLOWLIST_JSON` and global trial policy are preserved.
Malformed extra configuration denies extra admission without breaking the
original subject's behavior. The extra selection does not enable another route,
scan admission, purchase retention, cleanup, provider call or background worker.

The dedicated `access-snapshot-dev.yml` workflow reads the independent encrypted
Dev environment secret `ACCESS_SNAPSHOT_EXTRA_SUBJECTS_JSON`. It reads, but must
not replace, `GOVERNED_HISTORY_ENGINEERING_SUBJECTS_JSON` to preserve the existing
access/trial and History account. No identifiers belong in source, workflow
arguments, public evidence or logs. The approved identity may be reused privately
for selection; it is not fresh session/device/account eligibility evidence.

Before a plan, the helper checks the preserved live access/History selection,
trial gates, old entitlement package and unweighted alias, then downloads and
hashes the exact reviewed new object version. Its checked-in package provenance
is `docs/evidence/sec244-access-snapshot-package.json`; it must contain the actual
immutable publication, not a guessed S3 version. Raw private plan/configuration
and logs stay mode 0600 on the runner and are removed in the final cleanup step.
The public review contains counts, revisions and a digest only.

Plan and apply are separate dispatches at the exact reviewed main commit. The
guard rejects drift, unknown Terraform checks, additions/replacements/deletions,
IAM or API changes, unrelated function changes, original trial/subject edits and
any environment change other than the extra GET key. It permits exactly two
in-place updates: `trustcheckradar-dev-v1-entitlements` and its unweighted live
alias, with the pinned reviewed ZIP. Protected live-runtime hashes exclude only
that function, preserving History, purchase, deletion and other consumers.
Apply must regenerate and match the approved exact digest, recheck the previous
live runtime immediately before apply, read back the new configuration, compare
protected runtimes and require a zero-drift plan. This is configuration evidence,
not Android live acceptance. No apply is authorized while only implementation
approval exists. UAT and Production have no selection or workflow path here.

This dedicated transition owns the private override. Ordinary environment
deployments do not deploy the URL-consumer stack; older guarded access/trial
transitions reject the extra-environment removal and package replacement. Do not
use raw Terraform or the generic shell helper to apply this stack without these
inputs and guards. Future changes to access/trial or the entitlement package must
preserve this scope or explicitly obtain approval to remove it. Removing access
or restoring the previous ZIP needs a new, separately reviewed exact Dev plan;
there is no automatic rollback or trial/account reset.

After an approved apply, ATCR-114 / ATCR-170 must repeat the authenticated live
GET from the preserved current session, render the authoritative plan/nullable
allowance and disabled trial action, restart/refresh without a duplicate grant,
and verify account/session isolation. The prior HTTP503 is failed acceptance.
Purchase acceptance (ATCR-112) and its token-cleanup prerequisite (SEC125) remain
separate; no purchase activation follows from this display-only work.


## Pending current-account activation proposal (2026-10-10)

This is the proposed sequence for review, not an approved saved Terraform plan.
No current saved-plan digest is available. Owner-completed AWS SSO refresh
verified the expected Dev account; fresh metadata evidence is recorded in
`docs/evidence/sec244-billing-account-readiness-2026-10-10.json`. The snapshot-only
selection differs from foreground billing, and neither is covered by cleanup.
The corrected guard passes the existing cleanup selection using real metadata
reads. The owner-approved metadata-only grant was applied by
[run 38056641078](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38056641078)
from exact source `c8a7fe49145769aeffca104992d39d807ab60b51`; independent live policy
readback matched and preserved both prior statements. After PR173 and successful
main CI, [run 38057601139](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38057601139)
from `c64f7160aafb87d643411f2d4d4ca6ef1ff5754c` qualified all four Scheduler reads
through the actual GitHub OIDC deployment role. No runtime or account selection
changed. The dedicated billing-selection secret was absent in the names-only
readiness check; no secret values were read. Owner confirmation establishes that
the current Play account is eligible for license testing; the actual checkout
must still display the test-purchase notice and a Google test payment instrument.

1. Publish and independently review the scoped source fix against main under
   the owner's 2026-10-10 exception, then merge after local checks pass. The
   source baseline is `1d7bb5f8dc35bf126620f0399178cb5931cb6d37`; the preserved
   release baseline is `353303b657dfe3e44eda59cd8ed343284880cf69`. No blanket
   merge or manual dispatch extension is needed for the authorized main route.
   Verify post-merge main CI; its failures block further deployment/promotion.
   This source permission does not authorize the remaining runtime/grant actions.
2. Dev identity and current live package/alias/gate metadata have been read.
   Complete actual protected deployment-role qualification after its reviewed
   metadata grant; its policy simulation is not role-execution evidence. Check
   effective permissions and the existing cleanup selection privately.
   Reconfirm the current account through a fresh authorized protected session;
   do not reuse expired identity fixtures or move to the old History account.
3. If cleanup does not admit the approved billing subject, prepare a separate
   cleanup-only saved plan using manual `billing-cleanup-dev.yml`, with only the
   exact main `expected_revision` input. Before dispatch, obtain fresh private
   account confirmation and explicit approval to configure the protected
   `BILLING_ENGINEERING_SUBJECTS_JSON` input with that one canonical subject.
   The workflow reads and privately preserves every live cleanup subject, adds
   the selected subject, and rejects a union larger than ten. Preserve the exact
   SEC332 package, IAM, stream,
   schedule and non-cleanup gates. Expected writable runtime surface is only
   token-deletion function configuration/version and its live alias; unexpected
   changes stop review. SECUR4ALL-125 owns actual erasure qualification. Metadata
   checks alone do not establish that behavior, effective IAM or provider access.
   The default `execution_mode=plan` route has no runtime write or artifact upload.
   Baseline and candidate plans/configuration stay private on the runner and are
   deleted; only counts and the review digest are published. Its guard requires
   fresh unchanged runtime metadata and rejects unrelated sibling/package drift.
   A separately approved `execution_mode=apply` requires the same exact main
   revision and `reviewed_plan_digest`. It regenerates a fresh executable saved
   plan, repeats all resource/output/package and fresh runtime guards, and
   compares its action digest before applying that same saved binary. Deleted
   plan files are never recovered or uploaded. The digest binds all prior seven
   projected plan fields and the exact qualified caller identity; only validated
   STS session suffixes are normalized. Account, role ARN prefix and role ID stay
   bound, and source references may consume only caller `account_id`. Terraform
   can omit an unchanged caller from resource changes; its exact known,
   non-sensitive prior-state representation is then qualified and bound instead.
   Apply additionally requires fresh actual `trustcheckradar-dev-github-deploy`
   identity and the same captured live configuration immediately before apply.
   The existing protected Dev environment, main-only condition, concurrency,
   OIDC permissions and role grants remain unchanged.
   Before apply, private fingerprints capture all other Dev live runtimes. After
   apply, cleanup configuration, a single published unweighted live version,
   exact package, concurrency, unchanged schedule/mapping configuration and
   protected runtime fingerprints must match. A final detailed plan requires
   zero drift with the same private union inputs. Failure requires reconciliation;
   no automatic rollback, subject removal, deletion or purchase retry occurs.
   No successful live plan is implied by local tests. Executing a resulting
   change needs this reviewed apply route and exact action-time approval;
   do not substitute a blanket deployment or manual configuration edit.

   The first actual plan-only dispatch, run
   [38059719092](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38059719092),
   failed during the real Terraform baseline before account-union preparation.
   Nothing was applied and private files were removed. Planning failures now
   emit only a bounded category and fixed allowlisted AWS operation/input names;
   raw configuration, identities, resource identifiers and log text remain private.

   After the approved KMS metadata grant, actual-role qualification
   [38065248175](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38065248175)
   succeeded. Cleanup plan
   [38065304351](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38065304351)
   completed its private Terraform baseline but failed during account-union
   preparation before metadata discovery. The original generic rejection does
   not establish which predicate failed, and the private plan was removed.
   The preparer now emits one fixed allowlisted rejection code, such as
   `selection_json`, `selection_shape`, `plan_complete`, `plan_version`,
   `plan_drift` or `plan_checks`. Other parsing, scope, provenance, metadata and
   output stages have bounded fallback codes. It never prints the underlying
   exception, supplied value, subject, resource identity or private plan.
   Completion, drift, check-status, account and package predicates remain
   unchanged. This diagnostic change does not establish successful planning
   or authorize admission/runtime changes; the next real plan must identify
   and resolve the actual blocking condition.

   The owner subsequently approved qualification of only the computed
   `aws_lambda_event_source_mapping.deletion[0].last_modified` refresh. The
   exception requires exactly one managed AWS mapping drift row, with an update
   action and every other before/after attribute identical. Both timestamps must
   be known timezone-aware values representing different instants; the refreshed
   value must equal fresh AWS metadata after UTC normalization. The mapping UUID,
   ARN, live deletion alias, declared deletion-ledger stream and effective stream
   configuration must also match. The source must not assign `last_modified`,
   and its stream/function references must select the existing deletion mapping.
   The planned counterpart must be exactly one unchanged no-op equal to the
   refreshed row, without unknown values. Missing proof, any additional drift
   (including data rows), or any other changed field still rejects with
   `plan_drift`. Metadata is captured once during preparation and reused for the
   same plan review; the final existing readback must still confirm it is fresh.
   The provider's empty-string defaults are normalized only for absent
   `kms_key_arn` and `starting_position_timestamp`; both corresponding AWS fields
   must be omitted. The live starting position must explicitly be `TRIM_HORIZON`.
   The helper was checked against the regenerated real baseline's mapping row
   and the fresh AWS mapping metadata; that adapter check passed. It does not
   establish that the complete workflow's subsequent plan has passed.
   This qualifies a read-only timestamp observation, not a state write, mapping
   update, cleanup admission or successful behavioral acceptance.

   At source `b5531e1552bacac7fd28f5278e8e1cebab35a136`, actual-role qualification
   [38069802993](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38069802993)
   passed, but cleanup plan
   [38069854399](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38069854399)
   reached the saved-plan guard and rejected an output update. Both real plans
   contained the identical `candidate_contract` update: it added only the
   previously absent `billing_subject_count = 0` and
   `scheduled_worker_active = false`, preserving every old output value.
   The source-only guard correction permits exactly that six-field Terraform
   output row, with known object values, explicit false sensitivity flags and
   `after_unknown = false`. The count must be an integer zero and the worker
   flag a Boolean false; both plans must have null `billing_activation`.
   Output inventories and complete rows must match between baseline and
   candidate, including value types. Every other output must remain a known
   no-op. Additional fields, changed prior values, unknowns, sensitivity or
   different actions still reject. All resource, source and live-metadata
   guards remain in force.

   Local boundary tests include the output addition together with the qualified
   timestamp refresh. The full guard also passed against the freshly regenerated
   private real baseline, candidate and captured metadata, reporting only two
   resource updates. This local verification neither applies nor writes state;
   the published plan-only workflow must still run successfully before a saved
   plan is qualified. Cleanup admission and behavioral qualification remain
   pending, and no apply authorization is implied.

   Diagnostic-source main CI
   [38059948494](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38059948494)
   passed stack validation but found a pre-existing snapshot rejection-test
   fixture defect: selecting its first resource depends on Python set ordering
   and can leave an already-permitted update unchanged. The repaired test selects
   an unrelated resource explicitly, checks alternate row orders, and requires
   rejection before artifact access. Production admission guards remain unchanged;
   passing source CI is still required before retrying the actual AWS plan.

   Main CI38060922997 passed at `c240c72e00c1658f20649da8042394df3f769c8c`;
   actual plan retry
   [38061674942](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/38061674942)
   failed with `kms:DescribeKey` access denial during baseline refresh. Exact-session
   CloudTrail audit found two denied requests. The deployment role's existing
   tagged-key permissions do not match the customer token key's tags or the
   AWS-managed DynamoDB encryption key. No plan digest or account union was produced.

   The owner approved full policy document SHA256
   `a85c886cd1eaf7513a22cf4eea0c44ad508e19f2e85018fe9d4313a224e33b3e`:
   preserve the four installed audit statements; add DescribeKey/GetKeyPolicy/
   GetKeyRotationStatus/ListResourceTags on customer key
   `62f786f5-76ab-41c3-ac77-fe362e0108ae`, and DescribeKey only on AWS-managed key
   `8724b7c1-4afc-48ab-b1ab-6e1a0aa74769`. Both exact key ARNs use account
   `107827791950`, region `us-east-1`, and RequestedRegion `us-east-1`. No
   cryptographic or mutation actions are added. This document hash is not the
   revision-bound workflow digest; derive that digest only after source review
   and main integration. The grant helper rejects fresh policy drift before a
   write, accepts an identical installed document without rewriting it, and
   requires the actual deployment role. Qualification then performs four
   Scheduler and five KMS metadata reads without exposing policy/tag contents.
   The token-key tag read disables CLI pagination to retain the service's
   `Truncated` flag and rejects missing or incomplete pages. Default CLI
   aggregation omits that flag; the real qualification must pass this boundary.
   Grant publication, actual role qualification and a successful real cleanup
   plan remain separate evidence. Runtime admission/apply is not authorized.
4. Configure the dedicated encrypted billing selection only after explicit
   configuration approval. SECUR4ALL-244 then prepares `handoff/preparation`
   against an exact integrated infrastructure revision and the reviewed Lambda
   source `65c186b461d86e825bdffe1ab9d8d8ca4eb3f48b`. Review the real saved-plan
   digest before apply. History, GET-only snapshot admission, trial policy and
   unrelated provider/account selections remain outside this transition.
5. Separately approve the exact Android source/build and installation. The
   purchase-capable Dev build uses `tcrPlayTestPackage`, `tcrPlayDeviceSetup`
   and `tcrPlayPurchase`; the installed snapshot-only APK cannot qualify checkout.
   Device registration, prepare and purchase are distinct permitted actions.
   Test the real protected preparation endpoint before any store transaction.
6. Only after preparation and cleanup prerequisites pass, prepare and review
   `handoff/verification`. ATCR-112 then executes the explicitly authorized Google
   Play test-payment flow on the preserved emulator/session. Require observed
   server verification, durable entitlement and server acknowledgment, followed
   by authoritative GET refresh; do not substitute fixture responses. Stop if
   the dialog lacks the test-purchase notice or offers a real charge.
7. Propose `lifecycle/ingress` and then `lifecycle/background` separately after
   foreground qualification. Preserve their exact account/source coupling and
   transport prerequisites. Actual RTDN, lifecycle and missed-delivery recovery
   evidence remain open; no foreground pass implies background readiness.

For each connected scenario, allow the initial attempt and at most two retries
for a classified transient read/transport failure. Stop immediately for an
observed reproducible defect, authentication failure or unmet gate. Reconcile
purchase/mutation outcomes before considering a retry. Route the defect to its
owning component, implement an authorized local fix, then repeat the original
case and affected integration checks; post-fix retesting is a new validation
cycle. Never use retries to bypass auth or fabricate provider responses.


## Initial Dev rollout impact and cost review

The eight-file local candidate changes infrastructure workflow/guard/policy,
regression tests and evidence only. No Lambda application source or ZIP and no
Android source was changed. The two runtime packages remain the observed live
handoff and cleanup packages. A later allowlist update would use Lambda
configuration updates, publish a version and move the existing live alias;
it does not require changing application code or installing a new package.

The initial proposed scope creates no AWS function, table, KMS key, log group,
queue, topic or schedule. This is the expected scope, not a generated Terraform
plan result; any create/delete or unrelated drift stops exact-plan review.
The dedicated billing subject is a GitHub Dev environment secret, not a new
AWS Secrets Manager secret. The existing History secret remains unchanged.

Exact IAM proposal for role `trustcheckradar-dev-github-deploy`, inline policy
`read-dev-billing-backup-inventory`, preserving its existing backup/IAM statements:

- `scheduler:GetSchedule` on
  `arn:aws:scheduler:us-east-1:107827791950:schedule/trustcheckradar-dev-play-lifecycle/trustcheckradar-dev-play-token-deletion`
  and
  `arn:aws:scheduler:us-east-1:107827791950:schedule/trustcheckradar-dev-play-lifecycle/trustcheckradar-dev-play-lifecycle-worker`.
- `scheduler:GetScheduleGroup` and `scheduler:ListTagsForResource` on
  `arn:aws:scheduler:us-east-1:107827791950:schedule-group/trustcheckradar-dev-play-lifecycle`.
- Every added statement requires `aws:RequestedRegion=us-east-1`. No scheduler
  mutation permission is added. SECUR4ALL-342 retains actual-role qualification.

Cleanup is already enabled every minute, with one scheduled target attempt,
256 MB, 60-second timeout and reserved concurrency one. Adding the current
approved subject preserves the previous subject(s), package, IAM, stream,
schedule and gates. It may increase existing per-invocation reads/processing.
It admits actual account-deletion handling for that subject if a valid deletion
command/event exists; qualification is not permission to request deletion.
No token decrypt/provider call or global traversal is enabled by this scope.

Foreground currently admits one different billing account. Selecting the
approved current account intentionally changes that one-account billing
admission while preserving History and GET-only access scope. A preparation
transition would close foreground purchase verification while retaining the
preparation path; verification is separately enabled after prerequisites.
The function remains 256 MB, timeout 29 seconds, concurrency2, attempts 20 per
60-second window and max in-flight 2. Registration/preparation can persist
binding/locator state; verification can retain a token and commit a real
entitlement and server acknowledgment. Each action requires its own acceptance
scope. Lifecycle ingress and its minute worker remain disabled in this initial
rollout; AI/proposer gates remain unchanged and disabled.

CloudWatch reported 1,440 cleanup invocations, zero errors/throttles and
651,522.34 ms total duration for the 24-hour window ending
2026-10-10T05:53:40Z. No handoff/worker invocation datapoints were returned for
that window. Official AWS Price List API rates effective 2026-10-01 in us-east-1
were $0.0000133334 per ARM GB-second at tier 1 and $0.0000002 per Lambda request.
At unchanged observed cleanup usage, 30 days of Lambda compute+requests are
approximately $0.074 before free tiers/discounts. If every existing scheduled
cleanup invocation consumed its full 60-second timeout for 30 days, the same
Lambda-only calculation would be approximately $8.65. Neither is an incremental
cost prediction, total AWS bill, guarantee or spend cap. DynamoDB, secrets,
scheduler, logs, APIs, KMS, GitHub Actions, taxes and other workloads are excluded.
Adding subject coverage may increase duration/requests; stream events and
foreground requests are additional workload. The owner approved a USD 5
additional-AWS operational stop threshold for the first 24 hours, from
2026-10-10T13:40:29Z through 2026-10-11T13:40:29Z. One Cost Explorer baseline read
succeeded, but estimated daily whole-account totals cannot isolate the workflow
or testing session. GitHub workflow costs are separate from this AWS threshold.
No budget, alert or spending-control setting was changed.

Use bounded manual validation with recorded request counts and the agreed
transient retry limit. Review aggregate usage after the approved deployment and
stop new discretionary test actions at the agreed operational threshold;
billing latency means a threshold alone is not a guaranteed hard cost cap.

Runtime backout requires a new reviewed exact Dev plan. Preserve source/package
pins and the prior alias/configuration readback, drain affected invocations and
close new foreground admission if needed. Do not automatically restore broad
History selection, delete bindings/entitlements, remove cleanup admission while
retained data requires it, disable existing cleanup, reset trial/allowances or
replay a purchase. Reconcile any in-flight store outcome before further action.
The read-only IAM addition can be restored to its prior reviewed document through
the same explicit policy-digest approval flow. No rollback was executed.

The owner's scoped main-integration exception removes the need for a release
workflow extension for these fixes. Preserve existing main-only automatic CI,
manual Dev workflows, environment protections and exact revision/digest approval.
A main source merge runs validation only; runtime and security changes still
require their own explicit action-time authorization. UAT and Production remain
outside this proposal.
