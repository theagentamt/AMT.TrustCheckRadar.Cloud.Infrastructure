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

The owner approved Pub/Sub pending-message retention of600seconds, no retention
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
or deletes. Deployment and readback will be recorded separately; a plan is not an
applied or activated runtime.

## Primary references

- [DynamoDB resource-policy action support](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/rbac-iam-actions.html)
- [DynamoDB backup IAM](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/backuprestore_IAM.html)
- [KMS encryption context and audit logging](https://docs.aws.amazon.com/kms/latest/developerguide/encrypt_context.html)
- [Pub/Sub subscription retention](https://docs.cloud.google.com/pubsub/docs/subscription-properties)
- [Authenticated Pub/Sub push](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions)
