# Google Play lifecycle infrastructure

SECUR4ALL-244 is delivered independently of Android hardware. This first increment
provisions only a dedicated empty Dev token table, application-encryption key and
no-copy table policy. It does not install or activate lifecycle handlers, admit
purchases, or configure Google delivery. Runtime wiring remains a separate reviewed
increment coordinated with SECUR4ALL-125.

## Storage boundary

`terraform/play-lifecycle` defaults disabled; the Dev tfvars select foundation
only. The table has PK/SK, a KEYS_ONLY GSI1 scheduling index, deletion protection,
no Streams and no PITR. `expiresAt` TTL is a backstop, not evidence of timely
erasure. Explicit expiry and account-deletion workers must be qualified before
any token writer is enabled. The caller account, region and project are fixed to
reviewed Dev. No existing table or service is modified.

Application encryption uses a dedicated rotating symmetric KMS key, separate from
DynamoDB-managed encryption at rest. Runtime envelope encryption will use
GenerateDataKey(AES_256) and Decrypt with only the fixed purpose/environment
context. The authenticated envelope contains account/token binding; those values
must not appear in CloudTrail-visible KMS context. Unused Encrypt/ReEncrypt paths
are denied. Stored tokens expire at the latest verified access end plus seven
days or account deletion; no post-deletion token or backup extension is approved.
Account-lifetime reverse billing bindings require deletion/export inventory too.

The table policy denies supported backup, PITR, export and Kinesis-copy actions.
AWS Backup's advanced StartAwsBackupJob is not governed by that table-policy
boundary: exclude this table from backup selections and deny the exact table on
all actual backup execution roles. `backup_role_names` supplies those audited
roles. The preflight found zero backup plans and zero roles trusting AWS Backup.
A tag alone is not an exclusion guarantee. Any future backup plan, role, restore
or table repointing requires renewed review before writers continue.

Run `scripts/audit_play_token_storage.py --output <protected-path>` for a fully
paginated metadata-only inventory. It does not read token/account rows. Additional
activation evidence must include actual policy/role behavior, expiry/deletion,
logging selectors and worker contract qualification. No configured CloudTrail
trails or Lake event data stores were found during this preflight; this is an
observation, not a recommendation to disable audit logging.

## Approved Google transport and remaining setup

The owner approved Pub/Sub pending-message retention of 600 seconds, no retention
of acknowledged messages, no dead-letter topic and no additional AWS raw-token
queue. Queued notifications contain purchase tokens and cannot be selectively
erased at account deletion; handlers reject deleted accounts. The setting is not
a promise of exact physical erase timing inside Google's service. Notifications
request fresh store verification; they never grant/revoke access on their own.

Read-only setup checks found Pub/Sub SERVICE_DISABLED in Google project
`trustcheck-radar` (1034373992662), no dedicated
`tcr-dev-play-push@trustcheck-radar.iam.gserviceaccount.com` identity, and no usable
project configuration-permission evidence from the existing store credential.
The owner has been asked to enable Pub/Sub. Google configuration is independent
of AWS foundation delivery; do not grant project administration to runtime store
credentials to bypass the setup boundary.

Next runtime increment: synchronous signature/audience/service-account/subscription
validated notification intake; bounded reconciliation and acknowledgment recovery;
explicit expiry/deletion and metadata-only export; monitored disabled schedules;
reviewed foreground preparation and initial ownership recovery. Unknown ownership,
stale provider evidence or incomplete cleanup must remain explicit outcomes.

## Validation and deployment evidence

The six storage Terraform cases cover disabled default, no-copy/index/crypto
boundaries, exact backup-role deny and rejected environment/role inputs. Existing
stack-helper tests cover independent state routing; no Android Actions or hardware
are involved. The actual foundation plan has exactly three creates and no updates
or deletes. Foundation PR54 was merged into `release-V01` at
`2ff06a3089ea97f152f39fcd6559418cb018ff38`. The saved plan from reviewed source
`8e5119402c23c356cad773f7de55de471eedf973` was manually applied to Dev on
2026-09-23 UTC: three creates, no changes or destroys. Plan JSON SHA-256:
`b0525bbcfc997de22bb1bbf2b37d89e27a428cc36ed828a42d79cd5a85c00bd4`.
A fresh plan then returned detailed exit code 0 (no drift).

[Metadata readback](evidence/play-token-foundation-2026-09-23/storage-audit.json)
confirmed active storage, TTL enabled, no Streams/PITR, KEYS_ONLY projection,
no backups/recovery points and no configured AWS Backup plans or execution roles.
[KMS readback](evidence/play-token-foundation-2026-09-23/kms-readback.json)
confirmed rotation and an ephemeral AES-256 data-key roundtrip using the approved
static context. Missing, wrong-purpose, wrong-environment and extra context keys
were denied. No purchase token or account data was used. These checks do not
qualify expiry/deletion or enable purchases. No lifecycle runtime was deployed.

Local validation: six storage Terraform cases and sixteen script tests passed.
Provider deprecation warnings about hash/range key declarations remain warnings.

## Primary references

- [DynamoDB resource-policy action support](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/rbac-iam-actions.html)
- [DynamoDB backup IAM](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/backuprestore_IAM.html)
- [KMS encryption context and audit logging](https://docs.aws.amazon.com/kms/latest/developerguide/encrypt_context.html)
- [Pub/Sub subscription retention](https://docs.cloud.google.com/pubsub/docs/subscription-properties)
- [Authenticated Pub/Sub push](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions)

## Closed runtime integration

The next candidate provisions three Python 3.14 ARM64 handlers from one immutable
Lambda release: authenticated ingress, reconciliation/expiry, and account-token
deletion. All runtime/authority/cleanup/preparation gates remain false, including
`PLAY_CHECKPOINT_POLICY_APPROVED`; schedules and the deletion stream mapping are
disabled. Worker/deletion schedules use one-minute cadence when later qualified.
The deletion mapping admits at most five ledger records per batch. No raw-token
AWS queue or failure destination is created.

The worker's proposed five-minute continuation row stores only canonical index
position, revision and timing. Owner approval is pending. It has no token or
ciphertext, no backups, logical expiry and account-deletion erasure. A false
policy gate prevents its use. This row is separate from the existing deletion
ledger's reconciliation cursor. TTL alone is never timely erasure evidence.

Role policies isolate encryption from deletion: deletion has no Google credential
or KMS use; foreground preparation/retention can generate a data key but cannot
decrypt. Only background reconciliation can read/decrypt retained tokens. Token
mutations require transactions and scoped key families. Inventory controls stay
read-only. Stream read permissions address only the deletion stream; ListStreams
is metadata discovery limited to us-east-1 (AWS provides no resource scope for it).

The optional `play-verification.lifecycle_storage` adds exact token dependencies
and the authenticated `/v1/purchases/google-play/prepare` route with the same JWT
scope as verify. API stage settings use separate default-false preparation
selection: deploy and read back the closed prepare route first, then select
`play_preparation_route_throttle_enabled`. The existing verification throttle
alone never adds settings for a nonexistent preparation route. It does not activate
preparation, purchases or token retention. The foreground authority role remains
Put-only; background shortening has separate Query/Update/Delete permissions.
The optional API `account_export_play_token_table_arn` grants owned-partition
Get/Query; token metadata export and full export remain disabled. Deploy matching
account-deletion/finalizer packages and requalify the required PLAY_TOKENS inventory
before enabling writers; do not declare erasure complete using the old inventory.

Content-free semantic failure/lag alarms and native errors/throttles target the
existing support@andmorethings.com SNS topic. Missing-heartbeat actions are off
until schedules are activated. Ingress is event-driven and has no missing-heartbeat
alarm. API logs exclude bodies, headers, token/account identifiers and query strings.

Google setup and actual provider delivery remain separate from an AWS deployment;
see [Google notification setup](PLAY-NOTIFICATION-SETUP.md).

Local runtime-candidate validation: 9 lifecycle/storage Terraform cases,
11 foreground verifier/preparation cases, 14 account-export cases and 19 API
recovery/route-throttle cases passed. These are mock-plan/apply tests, not live
provider delivery or token-erasure evidence. Independent review corrected the
prepare-route deployment ordering before source integration.
