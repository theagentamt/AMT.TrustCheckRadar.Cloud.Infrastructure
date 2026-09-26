# Minimal next all-component deletion qualification

Read-only assessment of release-V01 223e9bea (reviewed Lambda source f92285b). No account mutation or activation was performed. Root owns infrastructure and real inventory acceptance.

## Conclusions

All twelve components have receipt implementations. A fresh empty synthetic account qualifies empty passes, session revocation and final identity composition only. It cannot establish nonempty History erasure, pending reservation release, recovery metadata cleanup, or paired token/ownership deletion. The 48 AWS campaign cases qualified real DynamoDB campaign→receipt→finalizer composition, with injected Cognito and assumed synthetic other-component receipts; they do not replace these acceptance tests.

Research can stay paused during campaign account deletion. Lambda bridge has no global research kill-switch dependency. Current Terraform couples its event-source mapping to `local.active` (which is false for the paused candidate), and hardcodes recovery schedule/environment disabled. A separately reviewed deletion-only activation overlay is required. Keep global campaign kill switch true, publisher/cluster admission false and queue/observation mappings disabled, lifecycle false and its three jobs disabled. Enable only the deletion mapping/recovery schedule and bridge flags after qualification.

## Exact bridge configuration

- APP_ENVIRONMENT=dev, schema1, exact pipeline/users/deletion-ledger/intelligence names.
- CAMPAIGN_DELETION_STREAM_ENABLED=true, CAMPAIGN_RECOVERY_ENABLED=true, CAMPAIGN_COMPLETION_ENABLED=true.
- CAMPAIGN_RECOVERY_INDEX_NAME=CampaignRecoveryDueIndex.
- All three locator/recovery/completion manifest SHA256 pins and positive inventory revisions must match exact approved rows. Completion marker links the other two; approvals must precede the request.
- CAMPAIGN_PERIOD_ADMISSION_ENABLED=true **on deletion only**, canonical UUIDv4 generation, actual account identity pin and AWS Region. Every retained HMAC_KEY row must match strict admission schema/generation/locator pins and remain ENABLED with an available correct HMAC key. Cleanup accepts OPEN or CLOSING; no period closing or retirement is needed for one account.
- PARTICIPATION_ITEM_SK=CAMPAIGN_PARTICIPATION, audit400d, contributor recovery7d, transient21d.
- Stream requires exact own-account/Region ledger source ARN; scheduled input is exactly {"schemaVersion":1,"operation":"reconcile-campaign-cleanup"}. At least6s remains before each SDK call in real orchestration.

Never omit an unusable prior period merely because its key is retired. A lower inventory bound requires separately accepted prior-period erasure/restore evidence. Current synthetic tests do not approve period1478 exclusion or create admission metadata/markers.

## Producers and ordering

| Receipt | Actual producer | Required activation qualification |
|---|---|---|
| SESSION_REVOCATION | account_data_api | Exact Cognito username=sub mapping; AdminUserGlobalSignOut; existing-user and retry/missing-user handling |
| DEVICE_BINDINGS | account_data_api | Strong owned partition traversal, active pointer/device records, pagination and fenced writers |
| DEVICE_RECOVERY | account_data_api | Pending recovery, receipts/rate/audit families under existing retention rules |
| ANALYSIS_ABUSE | account_data_api | Current request/dedupe/consumption plus retained legacy shapes; unknowns fail closed |
| CAMPAIGN_OUTBOX | account_data_api | Complete locator coverage and paired own items, no empty-GSI inference |
| ENTITLEMENTS | account_data_api lifecycle | PURCHASE#CONTROL/OWNERSHIP_INVENTORY; owned legacy/modern entitlement and token locators; preserve approved global usage |
| HISTORY | history_account_deletion_bridge, then history_lifecycle for nonempty histories | HISTORY_ACCOUNT_DELETION_ENABLED=true; lifecycle enabled and bounded settings/retention approvals. History reads/writes/recognition need not be enabled |
| CAMPAIGN | campaign_deletion_bridge | Above independent deletion-only gates, actual inventory/pins and real worker receipt/seal |
| V1_AUTHORITY | v1_authority_deletion | STAGE=dev, V1_AUTHORITY_DELETION_ENABLED=true, exact test UUID allowlist, current/retained HMAC secret+inventory, ledger ARN and120d receipts; no paid/provider/admission activation |
| PLAY_TOKENS | play_token_deletion | STAGE=dev, PLAY_TOKEN_CLEANUP_ENABLED=true, same UUID allowlist/HMAC inventory, exact no-backup token table; no provider/decrypt required |
| USER_PROFILE | account_data_api | All ten upstream receipts before deleting profile; approved consent audit policy retained |
| IDENTITY | account_data_api shared finalizer | Exact eleven upstream receipts, full12 inventory and SEALED0 recovery control; actual Cognito mapping/delete; terminal fence+IDENTITY atomic |

Account-data stream alone is insufficient durable finalization: it can acknowledge its initial event while other components remain pending. Its reconciliation schedule must run (or an explicitly qualified invocation of that exact static reconciliation event must be part of E2E), so later receipts unblock USER_PROFILE/IDENTITY. Real V1/Play stream paths avoid creating the separately pending five-minute Play operational checkpoint. Their deletion-ledger reconciliation cursors are different existing records; do not treat that as approval of the Play token-worker checkpoint.

## Minimal staged test

1. Root confirms actual artifact/IAM/environment identities for each producer, all required storage/index contracts, full inventory and Cognito mapping. Verify there are no unrelated pending deletion/withdrawal commands before enabling shared scanners; several producers are not subject-allowlisted. Keep JWT admission routes closed during worker qualification.
2. Independently qualify nonempty synthetic datasets: paginated device/recovery/abuse/outbox; History content/control/dedup and pending erasure; legacy entitlement/ownership pairs; V1 trial/paid local periods and pending CHECK reservations with purchase-global counters preserved/released exactly; Play encrypted synthetic token/reverse-binding pairs (no Google purchase or acknowledgment). These should use dedicated fixtures or a precisely scoped disposable subject; no fake receipts/verified purchase claim. Inject failures and retry against real component producers.
3. Create/select a dedicated disposable Cognito subject, prove enabled/confirmed matching PROFILE and exact username=sub; include its UUID in V1/Play engineering allowlists. Actual signup/profile fencing should be used where feasible. Do not delete the existing appreview account by inference.
4. Enable only reviewed cleanup worker paths and submit one exact fresh-auth deletion request after inventory approvals; assert durable matching REQUESTED + campaign sidecar/control, then run/observe workers and reconciliation. Verify all twelve receipts, preserved approved global purchase usage, profile/owned row absence, Cognito UserNotFound, fixed COMPLETE fence, and stale-event replay suppression. Distinguish synthetic account actual identity deletion from general historical coverage.
5. Only after this acceptance allow the public JWT admission phase; do not broaden paid/research gates or infer checkpoint retention approval.

## Concrete source hardening being prepared

account_data.validate_config currently permits ACCOUNT_DELETION_ENABLED/finalizer=true with CAMPAIGN_RECOVERY_WRITES_ENABLED=false. Root's activation overlay sets true, but source should fail closed to prevent accepting a command without its required durable recovery job. Root authorized a narrow configuration check and regression; no durable schema/IAM change. All other conclusions above are qualification/infra dependencies, not missing receipt implementations.
