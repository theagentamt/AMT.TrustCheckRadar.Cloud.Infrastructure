# Private result feedback decisions

For ATCR-122 / SECUR4ALL-238, the owner approved both questions in the active task:

1. “Approve this structured-only V1 scope”: four optional choices (looks legitimate, looks like a scam, unclear, unhelpful), one report per owned result, no free text or original content, no charge, no automatic verdict/research changes, and no promise of a human reply.
2. “Existing receipt; accept disclosed backup retention”: attach feedback to the existing receipt and preserve its original seven-day expiry. Historical backups can retain it longer; the last verified window was 35 days and current settings require verification before activation.

The reviewed proposal is infrastructure commit `807dd0d82aa4c9c3b6937857fe93a40fb24cb557`, `docs/PRIVATE-RESULT-FEEDBACK-REVIEW.md`, SHA256 `9e3485588daeae698b139cb070b4de16bb9298348135271e7d9adafd9968bee6`. The accompanying interface packet SHA256 is `2d32f2662bc574cb4c21c61d7ba608fa7c262775ce9d0fd9a0d16cbad7469cae`. These decisions resolve the pending scope/storage choices in that immutable proposal; they do not qualify runtime behavior or assert deployment.

## Infrastructure implications

Use the existing purchase-entitlements CHECK row, original retention deadline and existing explicit expiry/account-deletion lifecycle. No separate feedback table, provider secret, model invocation or research pipeline is required. Feedback is an optional private product-quality purpose, independent of paid access and research consent.

A dedicated authenticated feedback handler needs only identity/deletion/device fence reads and condition checks, authority record reads, conditional transactional updates to an existing CHECK, and the existing authority HMAC key needed to verify ownership proofs. Do not grant provider invocation, billing mutation, table enumeration/deletion or arbitrary object storage. Confirm the actual Lambda SDK calls before finalizing IAM. Keep operational logs free of request bodies, proofs, category/account/result identifiers and raw content. Use the existing support@andmorethings.com alert path.

The service contract must distinguish exact accepted replay from a new report ID against an already-reported result. Feedback must not re-create an expired/deleted receipt or extend any expiry. Ordinary result projections must not expose the stored feedback object. The account-data inventory must name feedback and its backup/export boundary; existing export completeness is not implied.

## Current verification boundary

A read-only Dev `describe-continuous-backups` attempt against `trustcheckradar-dev-purchase-entitlements` failed because the AWS SSO token had expired. No AWS mutation occurred. Therefore, 35 days remains the last recorded audit value, not a newly verified setting. Before live activation, verify effective PITR, any additional backup/export copies, lifecycle deployment and restore quarantine/reapplication of expiry and deletion controls.

Implement and validate source on feature branches targeting release-V01. Preserve main-only GitHub CI. No live acceptance test is a pass until performed, and source completion does not imply device qualification or release.

## Contract clarifications from independent review

Idempotency is scoped to the owned result. An ordinary opaque feedback ID does not require a global uniqueness index or a client-generated digest protocol. On that result, exact same-ID/category replay acknowledges the original write, changed category under the same ID conflicts, and a new ID returns already received without saving another choice. Each different result independently requires ownership validation.

An expired short admission proof may still verify ownership for feedback while the original settled receipt remains retained. Receipt expiry, account deletion and device fencing remain authoritative. Duplicate acknowledgments require the same current fences as first writes; a read-only shortcut must not bypass revocation races. Conditional writes must preserve summary, original deadline, TTL and lifecycle index fields and never create a missing CHECK.

The canonical Android/Lambda fixtures must define matching eligibility for valid displayed complete, partial and inconclusive assessments, including noncharged limited results. Input errors, unsupported/blocked/unavailable/failed technical-only outcomes and results without a valid summary are excluded, along with local-only/legacy/pending/recovery results. The form must reference the exact current displayed assessment, never a sticky older warning combined with a newer receipt.
