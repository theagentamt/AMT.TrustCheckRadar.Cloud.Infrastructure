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
