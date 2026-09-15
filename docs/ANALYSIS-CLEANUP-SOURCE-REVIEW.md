# Analysis cleanup source review

## Latest Source Handoff: aa274743

The Lambda task reports a subsequent owner instruction to use best practices
and published `aa2747438a43c432a49f63e282de7bb863f7e9d5` on the same feature
branch. Infrastructure verified GitHub publication and the three ZIP hashes:

| Artifact | SHA-256 |
| --- | --- |
| account_data_api.zip | `aa0d3fe00a0a6ab06090d8a69304b386c8d8e55d6224ae7566471b1245b17a01` |
| conversation_analysis.zip | `ee28a66008bc7386275d7dca5b6ab9c1dbae33ab0a2dcd627c98d503bde74ce1` |
| history_lifecycle.zip | `4d5b2e90591dd54a82a9bf89793e6ecb8592dbec0ba2d399d89a608ee3987a38` |

Source now requires ordinary analysis dedupe to be exactly 900 seconds. For
non-History legacy requests it keeps only the content-free allowlist and caps
expiry at deletion request plus 900 seconds, never extending an earlier expiry;
already-past boundaries cause deletion. Conditional replacement compares against
the original stored expiry. Valid History tombstones retain their expiry under
the separate deletion-anchored 120-day ceiling. Local scan-consumption deletion
still requires its explicit policy gate. The three policy defaults remain
pending, and the handler validates them before accepting stream/API work.

The Lambda owner reports 299 tests/129 subtests, compilation, shellcheck,
artifact validation and full checksums passing. Infrastructure reviewed the
source delta but did not independently rerun the Lambda suite. The existing
infrastructure at `91d3dc9` already matches these names, values and IAM needs;
no additional grant, environment selection or policy activation is necessary
to record this handoff.

The latest turn was not exposed by read_thread (its items list was empty).
The Lambda task subsequently supplied the exact owner direction:
"for the the retention and inventory questions, use best practices".
It also corrected its prior claim: the owner did not expressly authorize a live
Dev inventory or specify retrieval/output exclusions. Treat this as direction
to choose and document best-practice behavior, not execution or deployment
approval. The source retention choices are recorded above; live inventory
remains gated pending a precise scope. The Lambda owner is correcting its docs.

The reported inventory scope is aggregate-only by family/status/field-name set/
expiry-age bucket, with no content, identifiers, keys, hashes, authorizations,
event values or samples in output/logs. Do not use an unprojected DynamoDB Scan
to discover arbitrary field names: that would retrieve full records. A reviewed
projected or count-only approach must explain its coverage limitations and
exclude sensitive values at the retrieval boundary where required. No live-row
inventory, legacy receipt migration, source upload to AWS or deployment occurred.

Earlier sections below preserve the review history and the decisions pending
before this reported direction; they are not the latest artifact manifest.

## Corrected Candidate

`d24b653eea1b570083df6adee1e27f3c810980ce` replaces the rejected `c87fa89`
candidate below. GitHub feature-branch publication and these local artifact
hashes were verified; neither candidate has been selected or deployed:

| Artifact | SHA-256 |
| --- | --- |
| account_data_api.zip | `9b10d12e9fcd72e837b7f4a7812b1df96c2a1453306a7a4f04ba2656400c6bb3` |
| conversation_analysis.zip | `ee28a66008bc7386275d7dca5b6ab9c1dbae33ab0a2dcd627c98d503bde74ce1` |
| history_lifecycle.zip | `4d5b2e90591dd54a82a9bf89793e6ecb8592dbec0ba2d399d89a608ee3987a38` |

Source restores the ordinary request default to 900 seconds, removes the unsafe
abuse-table fallback, and distinguishes History's approved 120-day markers.
History account cleanup uses exact content-free conditional replacement with
retention anchored to the deletion request, not each retry. The Lambda owner
reports tests for both cleanup orders and 296 tests/129 subtests passing.
Infrastructure reviewed the changed code but did not rerun the Lambda suite.

Three independent gates remain pending: ANALYSIS_REQUEST_DEDUPE_POLICY_STATUS,
ANALYSIS_LEGACY_REQUEST_RETENTION_POLICY_STATUS and
ANALYSIS_CONSUMPTION_DELETION_POLICY_STATUS. Consumption is not queried/deleted
while its gate is pending, and no ANALYSIS_ABUSE receipt can mark the component
complete while a required decision is unresolved. Longer-lived unknown request
records can be stripped of content without silently shortening their expiry;
their policy/provenance still blocks completion. This is source behavior only.

Infrastructure now prepares exact four-family Query/DeleteItem and REQUEST-only
PutItem for the disabled account-data candidate, authoritative abuse table name,
page size 100, prior-source ordinary TTL 900, separate History retention 120,
and all three gates explicitly pending. Resource preconditions reject wrong
environment/account/Region abuse tables. The ordinary analysis Lambda's deployed
environment/default is not changed by this preparation.

History runtime gains REQUEST-only PutItem only when the paired account-deletion
candidate is selected. Existing lifecycle deployments without that candidate
retain their old actions. No resource, artifact version or activation is selected.
API tests: 38 passed. History-processing tests: 19 passed. Both roots validate.

### Remaining Owner Decisions

Recommendations, not approvals:

1. Keep ordinary request retry/deduplication at the prior 900-second (15-minute)
   source default. This is separate from History retention and is not an account
   token lifetime or a guarantee that all retry protection expires at 15 minutes.
2. Delete local ANALYSIS#CONSUMPTION scan-event rows on account deletion unless
   a concrete security/charge-dispute purpose requires a separately approved
   minimal record. This decision does not authorize deleting purchase-token
   anti-replay records or changing usage policy for active accounts.
3. Inventory legacy record types/expiry metadata and old component-receipt
   schema read-only, reporting aggregate counts/expiry ranges without submitted
   text, responses, credentials or user identifiers. Use that evidence to resolve
   exceptional legacy retention rather than approving unknown indefinite expiry.

No live-row inventory has been performed. All activation and policy gates remain
closed. Other missing account-data components still require implementation.

## Rejected Candidate Record

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
