# Proposed next actions — no cloud change authorized by this packet

The local reconciliation and exact Message runtime gate remove two preparation
blockers. The smallest next step is to publish and normally integrate the
reviewed local source into `release-V01` when the owner authorizes publication,
then obtain a fresh read-only Dev preflight and saved, bounded plan. No apply,
secret upload or AI/mobile operation belongs to that step. Do not promote main,
dispatch a main-only workflow from release, change CI triggers or widen its
deployment scope to make the plan pass. Existing main-only deployment controls
and any release exception require their own exact source/workflow reconciliation
before dispatch. Current main is a source reference, not promotion authority.

Specifically, pinned main `.github/workflows/deploy.yml` restricts the Message
job to `refs/heads/main`, while repository integration policy targets
`release-V01`. This increment does not import or relax that workflow. A later
rollout needs an explicitly reviewed release-capable manual deployment path or
owner-authorized promotion. Do not use a different source revision, override the
guard or add a CI trigger as a workaround.

## Smallest proposed shared-maintenance cloud change

Only after source integration, current readback and exact plan review, propose:

- Existing Dev `trustcheckradar-dev-url-lease-recovery` worker and its unweighted
  `live` alias, same `trustcheckradar-dev-purchase-entitlements` table, reviewed
  unchanged artifact or separately qualified replacement.
- Set only `LEASE_SWEEP_ENABLED=true` through the independent maintenance switch;
  enable only its existing one-minute EventBridge rule/target, recovery heartbeat
  missing-data alarm and expiry-overdue alarm actions. Preserve existing alert
  destinations and no-retry target/invoke configuration.
- Publish a new numeric worker version only if the reviewed environment change
  requires it; do not guess the future version. Pin the actual code hash, complete
  environment and alias readback after apply. Reject any plan change to other
  functions, IAM/trust, other schedules/targets, routes, actor lists, trial/operator/consumer
  gates, account-deletion activation, storage/indexes or entitlements. Importing
  their current source definitions does not authorize such a plan change.
- Reuse the existing constrained recovery role. No new provider, secret,
  role-assumption, identity or data permission is proposed. If the current role
  cannot perform the reviewed cleanup, stop with the exact missing action;
  permission expansion requires a new proposal.

Required action-time evidence: fresh same-account/function/table/alias/code/config
and role-policy readback; enabled exact rule/target and invocation resource policy;
heartbeat and overdue alarms plus destination; active GSI1 and authority backup/
retention metadata; and a bounded, privacy-safe inventory of due categories and
expected effects using existing authorized keys/indexes. No raw payloads, account
identity output, broad table scan or HMAC-key derivation is authorized here.
If that inventory cannot be obtained within scope, activation remains blocked.

## Separate irreversible cleanup decision

The existing worker cannot currently enable recovery while disabling expiry.
Activation runs both passes across retained HMAC account partitions, potentially
including accounts other than the selected tester. It is not tester-only.

The category map below is checked against the retained deployed worker11 ZIP,
SHA256 `6b9ba8b94e6fcb564932e5a98d0638194436dfa7788e9452db7c9399a3f92be6`,
matching the dated readback code hash `a5uouU5vy1ZJMuWpjQY4GUQ236d4jpRS23yTmaP5K+Y=`.
This was an offline archive inspection, not fresh deployment evidence. That ZIP
has no operations-metadata retirement helper. Newer retained backend source does
include selective removal of expired operations fields on receipts, preserving
accounting. Do not silently substitute that newer worker source: a replacement
requires its own exact runtime qualification, effect inventory and review,
including that extra irreversible field removal. The two Message ZIP runtime
passes do not qualify either worker artifact.

| Pass | Existing record categories | Effect |
| --- | --- | --- |
| `V1_PENDING` | Overdue admitted pending check receipts | Conditional failed/zero-charge settlement; release original paid/trial reservation and inflight hold. No new check or grant. Deleting accounts are skipped. |
| `V1_EXPIRING` | Expired `V1_PREPARATION`, `V1_ATTEMPT_COUNTER`, settled `V1_CHECK_RECEIPT` including minimized History, and `V1_PURCHASE_USAGE` period rows | Conditional permanent deletion after the existing policy/inventory/expiry checks. Recovery checkpoints under `V1#CHECKPOINT` support bounded progress. |

Before this apply, the owner must separately confirm the fresh due-row scope,
counts/categories, retention policy and cross-account irreversible deletion.
This packet supplies no counts and is not that confirmation. Do not describe it
as a temporary tester toggle. PITR/backup metadata does not make a flag rollback
a data restore. Any backup-based restoration is a separate recovery operation.

Rollback closes new admissions first, keeps maintenance running while pending
work drains/reconciles, then reviews due rows/retention before disabling the
worker. Reverting flags cannot undo settled receipts or restore deleted History.
Do not restore a known admission-without-maintenance state simply because it was
the previous snapshot. Preserve the seven-day complimentary grant through its
retained expiry `2026-10-27T22:09:34Z`; verify current state later, never revoke it
as test cleanup. Do not reset paid/trial counters or eligibility.

## Later one-message AI and other journeys

The earlier scoped AI approval remains operationally held. Before resuming it,
the parent must confirm the exact package/configuration/security plan, selected
tester and current device/access, fresh secure key handoff if the old key remains
unavailable, and reviewed one-hour permission expiry/rollback. The proposed
exception remains the exact 99-character synthetic pasted-text message, Other/EN,
dated `gpt-4.1-mini-2025-04-14`, one generation total, no count call, no retries,
max512 output, US$1 additional maximum with conservative reservation US$0.4198496.
Revalidate official price/context assumptions before dispatch. Failure or
uncertainty consumes the one-use allowance. No provider call may be used as a
readiness probe. Do not claim general model qualification from that one test.

Temporary access would be evaluator-only exact-secret GetSecretValue plus only
conditional PutItem to the dedicated test-control partition, with time-bounded
narrow deny exceptions, no reads/scans/updates/deletes of test controls and no
shared-secret change. Exact current policy/secret/reservation metadata and expiry
must be independently reviewed at action time. Secret creation/upload, IAM
exceptions and AI enablement are not performed or newly authorized by this local
step. After the future test/failure, close the test path and remove temporary
reader/reservation permissions; do not delete the secret/key or revoke the grant.

Android must be ready before any short window starts. Preserve candidate.3 /
schema3, original-proof reconciliation and original accounting. Establish exact
operation/receipt-to-owned-History correlation through supported interfaces,
without opaque-ID extraction or invented endpoints. Complimentary success does
not prove paid/trial deduction. OCR/share variants and URL/QR provider calls need
their own exact scenario/target/disclosure and finite budgets; the fixed Message
exception does not cover them. Existing History can be scoped separately with
its owner/current-device fences and without funded-allowance admission.
