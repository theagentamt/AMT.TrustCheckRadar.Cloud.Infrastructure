# Analysis cleanup source review

## Publication Is Not Release Approval

Lambda feature branch `codex/sprint-7-history-badges` is published at
`c87fa89d20467616a272d19aafbb6f3c5690aa73`, verified through the GitHub ref API.
The local ZIP checksums match the handoff:

| Artifact | SHA-256 |
| --- | --- |
| account_data_api.zip | `132ae98b239849bb2d6ff1784c8288b0efd49f5e0f16e1da5d8c7cc1904bcf4d` |
| conversation_analysis.zip | `3961715d8c9ad1646be64f73e078043a9d3621c85ddd92b4038c38eff0b0f806` |

The owner reports 293 tests and 129 subtests, compilation, shellcheck and package
validation passing. Infrastructure has not rerun the Lambda suite. Source
review found the following blockers, sent to the existing Lambda task. No
candidate release, new request TTL, infrastructure apply or activation is
approved by this publication.

## Required Corrections

1. **History cleanup compatibility.**
   `history_lifecycle.service._redact_analysis_replay` sets the abuse REQUEST
   row to COMPLETED_ERASED with expiresAt/ttl based on the History dedup policy
   (approved 120 days in Dev). The new
   `account_data_api.service._minimal_analysis_request` rejects an unexpired
   row when expiresAt is more than 86400 seconds in the future. If History
   cleanup runs first, a valid retained marker blocks ANALYSIS_ABUSE completion.
   Test both component orders, retries and pre-existing History markers.
   Preserve approved minimal retention without retaining response, authorization
   or event data, and without silently shortening the existing promise.

2. **Unsubstantiated request-retention expansion.**
   The preceding Lambda config default for REQUEST_ID_TTL_SECONDS was 900;
   this commit changes it to 86400. The infrastructure Dev inputs do not set
   this variable. That source baseline is not a live configuration inspection.
   Identify a specific prior approval or preserve the prior default pending a
   decision. The 120-day History policy does not establish a 24-hour general
   request policy. Bounding remaining lifetime is also not proof of a record's
   original lifetime.

3. **Local usage policy attribution.**
   The owner said billing is handled through app stores, not that all local
   consumption/security state may be deleted. Correct documentation attributing
   that broader decision to the owner. Present the exact minimal retention or
   deletion recommendation with replay/quota consequences and any actual
   remaining approval needed. Do not invent financial retention requirements.

These are source/contract review findings, not live data findings. No item
values or identities were read. The Lambda task owns corrections and tests.

## Infrastructure Follow-Up After Correction

- The disabled account-data candidate needs exact abuse-table Query/DeleteItem
  for ANALYSIS#REQUEST#*, ANALYSIS#RATE#*, ANALYSIS#SCAN_RATE#* and
  ANALYSIS#CONSUMPTION#*. PutItem should be restricted to REQUEST minimization.
  IAM can constrain PK families but cannot validate payload projections or SK
  ownership. Do not add Scan or index wildcard access.
- The candidate will need authoritative ANALYSIS_ABUSE_TABLE_NAME and bounded
  page size 100. Do not select the handoff's 86400 request TTL until corrected
  source and policy agree. Required component activation remains empty/gated.
- Existing pinned History/analysis preparation already supplies authoritative
  users/ledger names, scoped GetItem and transaction-only ConditionCheckItem.
  A standalone new analysis artifact without that preparation is not ready to
  deploy. Review effective IAM and ordering before any paired rollout.
- Old component receipts without retainUntilEpoch fail the new validators and
  conditional-create cannot overwrite them. Before activation, inventory their
  presence read-only or perform a separately approved provenance-aware migration.
  No live receipt inventory or migration was performed here.

Other unresolved account-data components and all deployment gates remain as
recorded in [RECOVERY-CLEANUP-SOURCE-HANDOFF.md](RECOVERY-CLEANUP-SOURCE-HANDOFF.md).
