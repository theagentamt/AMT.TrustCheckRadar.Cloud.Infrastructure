# Recovery cleanup source handoff

## Verified Publication

Lambda feature branch `codex/sprint-7-history-badges` is published at
`9a6f5fd1d2a223ea08aece4e6ff38fd5f29e80c0` (verified with the GitHub ref API).
This is not a main merge or a Dev deployment. The six local artifact hashes
match the owner's handoff:

| Artifact | SHA-256 |
| --- | --- |
| account_data_api.zip | `991bebf6810bd76fbfe159fb8b913f96968dea37c29cd4c1328c6385da961bd2` |
| campaign_deletion_bridge.zip | `dea379ca71ec4b7bc1b2a6f49363455a05b33e077b99021e40e031688984e085` |
| device_recovery.zip | `9228f2ba267e10701dd79486966212f91bcb6b44dd60b530c69db79a4c7e9e6b` |
| history_account_deletion_bridge.zip | `c3aa3805728cc56db084eff7e9e413394161b288fbb03c89e644d2b6f9646d25` |
| history_lifecycle.zip | `78a77329d8830ff767118664ed61c0ed90f095aaf0ec51985910a8ef721453fd` |
| history-contracts-1.0.0.zip | `4dd156e55d7912f9313b204eaa67fe90c8dc6638ab2b0461286e24f70cdc0a32` |

The Lambda owner reports 287 tests and 129 subtests, compilation, shellcheck,
package validation and checksum verification passing. Infrastructure reviewed
the changed cleanup/configuration and recovery authority code, but did not
independently rerun that Lambda suite. No immutable S3 versions are available;
do not invent versions or relabel earlier staged artifacts as this release.

## Infrastructure Integration

The disabled `account_data_api` candidate now receives:

| Variable | Value |
| --- | --- |
| DEVICE_RECOVERY_CONTROL_TABLE_NAME | Same-environment approved foundation recovery table; empty if unavailable/invalid |
| ACCOUNT_DELETION_RECOVERY_DELETE_PAGE_SIZE | 100 |
| DEVICE_RECOVERY_RECEIPT_RETENTION_DAYS | 7 |
| DEVICE_RECOVERY_AUDIT_RETENTION_DAYS | 90 |
| DEVICE_RECOVERY_RATE_STATE_TTL_SECONDS | 86400 |
| ACCOUNT_DELETION_RECEIPT_RETENTION_DAYS | 120 |

Only validated recovery storage receives Query, PutItem and DeleteItem grants
on its exact table ARN with USER#* LeadingKeys. No recovery Scan, index wildcard,
new ledger TTL or Cognito deletion permission is added. Recovery storage
validation now matches the handler's fixed 90-day audit and approved 7-day PITR.
Existing scoped ledger permissions cover component and pagination progress
records; exact SK and operation binding are Lambda responsibilities.

All deployment selections, consumer activation, account deletion, schedules and
event-source activation remain unchanged and disabled for these candidates.
The approved Dev policy is not authorization to provision its absent table.
Existing post-confirmation logs still require reviewed import/adoption before
the approved 14-day retention can be applied.

## Coordinated Release And Remaining Work

New component receipts require retainUntilEpoch. Publish/review the account,
campaign and History workers together; do not combine incompatible receipt
readers/writers. This field is metadata, not expiresAt, and does not authorize
automatic removal of deletion safeguards. Historical receipts require explicit
compatibility review before activation.

Recovery cleanup deletes RATE records, minimizes unexpired RECOVERY/AUDIT
records, deletes expired evidence and persists bounded continuation progress.
Unknown families fail closed. Its component receipt does not mean the full
account was erased. Recovery retries now check profile/deletion authority before
returning a stored result.

Still incomplete: ANALYSIS_ABUSE, ENTITLEMENTS and legacy purchase ownership,
CAMPAIGN_OUTBOX, USER_PROFILE, IDENTITY/finalization, complete account export,
provider coverage, backup/replay verification, operational alerts and deployed
acceptance. Export cancellation is documented, not a claim that the complete
export implementation exists. No mobile or YouTrack changes are included.
