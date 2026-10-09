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
qualification references. Subjects are supplied from the existing encrypted
`GOVERNED_HISTORY_ENGINEERING_SUBJECTS_JSON` environment secret; they are never
printed in summaries or newly committed here.

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
artifact. Unrelated message, governed History, entitlements, analysis providers,
export and deletion services are outside this transition. UAT and Production
are outside the workflow.

The owner approved the optional global worker's five-minute linkable cursor
policy on 2026-10-04, including logical rather than guaranteed physical expiry.
Global traversal still requires separate scope and runtime qualification.
Scoped current-head reconciliation neither reads nor writes that cursor.

## CI/CD plan and apply

Use `.github/workflows/billing-dev.yml` on **main**. Local mock tests do not deploy.

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
