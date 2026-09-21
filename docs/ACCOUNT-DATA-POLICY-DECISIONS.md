# Account data policy decisions

## Owner Approval 2026-09-14

The owner approved the six-point follow-up in the infrastructure task. These
are Dev policy decisions, not authorization to upload artifacts, deploy,
activate features, merge main, or promote to UAT/Prod.

| Data or behavior | Approved decision |
| --- | --- |
| Recovery security audit | 90 days of minimal security evidence |
| Recovery retry receipts | 7 days |
| Recovery rate records | 24 hours |
| Recovery table PITR | 7 days |
| Post-confirmation operational logs | 14 days |
| Minimal account-deletion receipts | 120 days; operation, status, timestamps and necessary account linkage only; no contact details or submitted content |
| Consent audit | Preserve the existing 400-day policy for minimal evidence of acceptance/withdrawal |
| Export and deletion | Export must finish before deletion. Accepting deletion cancels unfinished exports. Do not promise login or ongoing authenticated status access after account removal |

The 120-day decision is conditional on verified backup/replay coverage before
retiring suppression fences. It is not blanket retention for all stores, an
instruction to enable ledger TTL, or approval to erase a fence while older
recoverable copies can recreate an account. Restore must use fresh deletion
suppression before serving data. TTL is eventual and does not establish the
24-hour active-data deletion deadline.

The owner stated that billing will be handled through app stores and supplied
no separate financial-record retention requirement. This does not establish
that no transactions exist, or authorize deletion/reassignment of purchase
anti-replay records. Entitlement, usage and token ownership records held by
this backend remain in scope. The Lambda owner must propose a minimal,
bounded ownership/anti-replay contract and identify any remaining decision;
no financial retention period is inferred here.

## Normal Registration Switching Decision 2026-09-17

The iOS task relayed the owner's explicit ITCR-59 decision: keep automatic
switching during normal device registration. Preserve the existing behavior of
`POST /device-registration`: registering a different installation may atomically
activate it and inactivate the previous binding. Do not add a requirement for
fresh sign-in and explicit confirmation for every normal registration switch.

This resolves the registration-versus-recovery switching-policy question only.
The separate consumer recovery route's fresh-authentication and rate controls
must not be described as a global device-switch policy. Prior-device rejection
applies while its binding remains inactive; a later normal registration may
switch it back. This is not permanent revocation of that installation.

Registration remains a mutation, not a status read. This decision does not
authorize background status probes, automatic retry loops after ambiguous
network outcomes, or new mobile invocation behavior. It does not create a
read-only device-status endpoint.

Consumer recovery remains unavailable pending a published versioned contract
and fixtures, approved receipt expiry/reuse semantics, safe authoritative
revalidation, and security/release acceptance. Existing seven-day receipt
retention does not itself resolve logical expiry or operation-ID reuse.

Provenance: owner decision relayed by the iOS task
`01a0608b-a8f2-7f61-909c-19c520f5a47e` for ITCR-59. Its reported mobile status is
In Progress, with ITCR-90 Open for manual Dev verification; these statuses were
not independently verified or changed by infrastructure.

Recording this decision authorizes no backend behavior change, tracker update,
commit/push, deployment, recovery activation, or UAT/Prod promotion.

## Implementation Boundaries

- Dev foundation inputs record the approved recovery policy, with storage
  provisioning explicitly false. API deployment and activation remain gated.
- The 14-day log policy must be selected during a reviewed rollout only after
  inspecting/importing any existing post-confirmation log group. Do not
  destroy/recreate the log group or silently adopt it through these approvals.
- The Lambda task owns cleanup, minimization, export cancellation, expiry
  checks and race/idempotency tests. Infrastructure permissions will follow
  its verified component contracts.
- Missing inventory components, Cognito identity resolution/finalization,
  legacy purchase locators, backup coverage and deployed acceptance remain
  engineering blockers. Policy approval does not mark deletion complete.
- No mobile changes or YouTrack updates are included in this work.

## Owner Decisions 2026-09-21 — ATCR-94

The owner authorized Android-first implementation with Lambda and infrastructure
dependencies and approved these two concrete decisions in the task:

- **Direct authenticated account export:** current user-visible account data plus
  a scope manifest, without another server-side payload copy. Values are observed
  during download, not a frozen cross-store snapshot. Continuation access expires
  15 minutes after export starts and is not extended by retry. Account deletion
  stops export access. Cancel discards the local download; it does not independently
  revoke an issued continuation token before expiry. Access remains authenticated,
  account/device-bound and subject to current deletion/session checks.
- **Restoration after deletion:** a newly created account may restore an existing
  store subscription only after fresh store verification and ownership checks
  preventing two active accounts from claiming the purchase. Remove the old local
  purchase binding instead of retaining it indefinitely. This does not authorize
  reassignment from another active account, token-only cached verification or
  matching accounts by email. Linked purchase lineage and deletion races remain
  engineering acceptance requirements.

No new export payload store, financial retention interval or durable export status
service was approved. Existing recovery/consent/deletion receipt periods, the
export-before-deletion rule and backup/restore suppression requirements remain.
The Lambda contract must enumerate actual fields and exclusions, not expose raw
rows. Android must label incomplete downloads and handle cancellation honestly.

These decisions authorize implementation, tests, source publication and tracker
coordination for the current story. They are not evidence of deployed cleanup,
end-to-end acceptance or permission to promote to production. The earlier scope
statements about no mobile/tracker work described the September 14 inventory
task; they do not override the owner's new ATCR-94 implementation instruction.
