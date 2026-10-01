# ATCR-122: private result feedback policy review

Status: proposed, not yet approved. This is a focused data-purpose/retention decision for SECUR4ALL-169/238 and Android ATCR-122. No deployment, provider use or storage activation is performed by this review.

## Proposed V1 behavior

A signed-in person on the active device may send one structured report for an owned, retained, settled governed message or URL assessment, including QR links analyzed through the URL service. The server verifies the existing check ID, proof, receipt ID, supported assessment version and valid minimized result summary. Local-only, legacy/history, pending, expired, missing/corrupt and recovery-clarification results are outside this initial contract.

Four choices: `looks_legitimate` (I think this is legitimate), `looks_like_scam` (I think this is a scam), `unclear` (The result is unclear), and `unhelpful` (The result was not helpful). No free-text comment, original/sanitized message, screenshot, URL or extra demographic data is submitted. These are opinions for private product-quality evaluation, not verified truth labels or campaign contributions. Feedback is optional and separate from campaign/demographic/commercial research consent. It does not call AI/reputation services, consume a check, require an active subscription, change a verdict or promise a human response.

The first accepted report is immutable in V1. An explicit retry of the same ID and category returns its original acknowledgment without adding another report. Reusing an ID with changed content is rejected. A new ID for a previously reported result returns a distinct already-received state; it does not save the new choice or disclose the earlier category. Only a committed/confirmed server write is acknowledged. Lost or uncertain delivery remains unconfirmed; cancel/background/account/result changes clear the foreground form without claiming remote cancellation or a refund. There is no persistent mobile feedback outbox or automatic retry.

## Minimized fields and boundaries

Proposed POST `/v1/result-feedback` body: feedback transport version, opaque feedback ID, result check ID/operation proof/receipt ID/assessment transport version, and one category. The server derives account identity from authenticated context and result family from the retained receipt; the client cannot supply ownership, verdict overrides or extra fields.

Stored feedback is one bounded object on the existing CHECK row: feedback ID, category, server received time and feedback policy version. Its result/account linkage already exists on that row. No second result copy, additional retention clock, campaign publication, free-text logging or new contact/support channel is introduced. Feedback is not returned through ordinary analysis receipt/history projections. The inventory must identify its purpose, access, retention, deletion, backup and export treatment. Do not claim existing account export is complete if it lacks this field.

The first implementation choice below is recommended because existing ownership, explicit expiry purge and account-deletion workers already delete the whole CHECK row. Writes must remain conditional on the exact owned, settled and unexpired receipt plus account/deletion/device fences. Apply bounded authenticated request limits and transaction conflict handling; never create a missing result to accept feedback.

## Retention decision

**Option A — existing result receipt (recommended):** feedback becomes inaccessible at the original receipt's existing seven-day deadline, not seven days after feedback submission. Sending feedback never extends expiry. Existing explicit expiry/account-deletion workers remove the complete row; DynamoDB TTL is an eventual fallback, not proof of immediate physical erasure.

This option inherits existing shared-table backups. Terraform enables point-in-time recovery. The last recorded Dev audit (2026-09-14, ACCOUNT-DATA-INVENTORY.md) found a 35-day window. Feedback can therefore remain in historical backups after active expiry. Effective backup settings and any additional copies must be rechecked before activation; do not claim every physical copy disappears on day seven or that uninspected backup coverage is known. Restored tables stay quarantined until expiry/deletion controls are reapplied. This proposal preserves the shared table's existing settings; it does not disable billing/authority backups or authorize extending them.

**Option B — separate storage without backups:** use a dedicated feedback store with no PITR/backup/export replication, anchored to the same original receipt deadline. This needs separate IAM, bounded expiry cleanup, account-deletion integration and restore/transport inventory. TTL still cannot guarantee physical erasure at an exact instant. Choose this if feedback must be excluded from the shared-table backup scope; do not silently weaken the existing shared table's backups.

Neither option authorizes longer-lived evaluation extracts or anonymous aggregates by implication. Any later retained output needs its own explicit purpose and retention rules. No live feedback activation until the selected storage/deletion/backup boundary and the authenticated service are verified.

## Implementation and acceptance

Android and Lambda can build isolated validators, state machines and tests while this choice is reviewed. Publish an immutable canonical contract only after alignment. Infrastructure provides the selected least-privilege boundary and existing support@andmorethings.com alert destination; no new provider credential is needed. All work starts from release-V01; main-only CI and required local gates remain unchanged.

Verify exact account/result ownership, forged/cross-account/expired refs, concurrent duplicate reports, lost acknowledgment, deletion/write and expiry/write races, no verdict/allowance/research side effects, safe restore behavior, logging minimization and real Android foreground/lifecycle behavior. Preserve existing assessment contracts and receipt semantics. Distinguish source/local, deployed and physical-device evidence; do not silently defer acceptance or close a disabled feature as live-qualified.

## Review requested

Approve the structured-only V1 behavior above and select retention option A or B. Exact draft English/Spanish interface wording is in FEEDBACK-INTERFACE-REVIEW.md; small truthful operational/error labels may be refined without introducing a new data purpose, retention rule or support promise.
