# History data stack

SECUR4ALL-223, first implementation milestone. This stack provisions data only.
It does not activate History collection, recognition, API routes or deletion.
Dev was provisioned on 2026-09-14 with owner-approved 7-day PITR and 120-day
minimal dedup/deletion metadata policy. UAT/Prod remain disabled. No History
ingestion or API activation was performed. See `docs/HISTORY-DEV-DEPLOYMENT.md`.

## Ownership and ordering

The stack owns two on-demand DynamoDB tables and their sparse lifecycle indexes.
It consumes no other remote state, preventing a dependency cycle. Future API
completion wiring can consume history-data and foundation; the separately owned
History API/lifecycle stack can then consume api, foundation and history-data.
The scheduled Lambda worker will provide purge/repair, not TTL alone.

Both tables are encrypted using DynamoDB's AWS-owned key. The provider's
`server_side_encryption.enabled=false` selects that key, not plaintext storage.
There are no customer-managed KMS keys, streams, queues, buckets or model calls.
Production table deletion protection is unconditional when provisioned.

The table and each index have conservative on-demand caps (25 read and 10 write
units/second by default). These are independent resource ceilings, not global
budget enforcement or user scan allowances. Query/transaction fan-out, storage,
indexes and PITR still require a volume-based cost estimate before activation.

## Storage monitoring

An optional `monitoring` object enables read/write metric-math alarms covering
both tables and all three GSIs, plus an environment-scoped dashboard. It requires
data enabled and an explicit existing standard SNS topic ARN in the same region.
Null creates no monitoring resources; all saved environments use null. Confirm
topic ownership, delivery permissions and subscriber delivery before activation.

Each alarm sums five resource-specific metric series. The dashboard exposes
those individual series so index throttling is not mistaken for table capacity.
No custom per-user metrics are emitted. Storage throttle monitoring is not
lifecycle/erasure or end-to-end availability monitoring. Runtime metric names
and schedules still need the Lambda owner's final contract.

The [operations runbook](../../docs/HISTORY-OPERATIONS.md) covers readiness,
throttling, deletion backlog, safe restore/rollback and required release evidence.

## Agreed Lambda resource contract

Confirmed with the Lambda owner on 2026-09-13:

| Resource | Keys and purpose |
| --- | --- |
| `trustcheckradar-{environment}-history-content` | PK = `USER#<sub>#HISTORY#<historyGeneration>`; SK = `COMPLETE#<13-digit completedAtEpochMs>#<requestId>` |
| `trustcheckradar-{environment}-history-control` | PK = `USER#<sub>`; SK prefixes `STATE`, `REQUEST#`, `MUTATION#`, `PROGRESS#`, `ERASURE#`; cursor handle record layout pending final runtime contract |
| Both: `ExpirationIndex` | `expiryBucket` (S), `expiresAt` (N), KEYS_ONLY |
| Control only: `PendingLifecycleIndex` | `lifecycleBucket` (S), `lifecycleAt` (N), KEYS_ONLY |

Content expiry bucket: `HISTORY#<UTC YYYYMMDDHH>#<shard 00-15>` with a deterministic
request-ID shard. Lifecycle bucket: `PENDING#<shard 00-15>`, with next-attempt time
in epoch seconds. The Lambda owner must finalize control expiry-bucket prefixes
and cursor metadata before runtime activation; the schema permits sparse items.
TTL uses numeric epoch seconds in `expiresAt`. Assessments are never projected
into GSIs. Strongly consistent History reads use the base account/generation
partition, newest first; direct lookup uses the control locator.

The control table contains private account-linked metadata and progress, not
anonymous data. Do not apply dedup TTL to all progress records. Deletion jobs
must remain discoverable until repaired, rather than expiring prematurely.

The output `downstream_contract` contains schema/environment, table names/ARNs,
index definitions and the approved 90-day/24-hour/no-snippets/no-points baseline.
Null resource fields and `enabled=false` mean no resources are provisioned.
These output values do not prove Lambda enforcement or endpoint readiness.

## Hard gates

`history_data_enabled` defaults false. Enabling it requires a non-null
`storage_policy` with approval boolean, approval reference, explicit content and
control PITR days (0 disables; 1-35 enables), and positive whole-second dedup and
tombstone retention. There are intentionally no policy defaults. UAT/Prod also
require `promotion_approved=true`. Variable validations stop plan/apply, unlike
warning-only Terraform check assertions.

The synthetic test values are NOT approved policy. Additional runtime gates
remain: mutation/cursor retention, final schemas/limits, lifecycle/erasure,
assessment privacy controls and repeated-content badge qualification.

This flag is a provisioning control, NOT a kill switch: changing it to false
after provisioning requests table destruction. Future runtime flags must stop
collection/reads independently while preserving data and lifecycle work.

## CI and release

Terraform CI initializes without a backend and runs mock-provider tests. The
provider lockfile includes official Mac ARM and Linux AMD64 checksums.

The deployment workflow includes history-data in `all` and exposes a dedicated
`history-data` scope. That workflow still processes foundation first, following
the existing data-scope convention. All environment defaults remain disabled.
No workflow run, commit, push, main merge or live apply is authorized by this
implementation milestone. A main push touching Terraform can auto-deploy Dev.

After explicit approval, use the existing helper with `history-data` and the
appropriate environment/state bucket, or the reviewed workflow plan mode.
Review table/index/backup actions before applying an identical plan. Do not
include secrets or actual account content in Terraform variables or state.

Remaining SECUR4ALL-223 work: narrowly scoped runtime IAM (including required
index Query permissions), immutable artifact checks, guarded API integrations,
scheduled lifecycle invocation, alarms/runbooks, final cost estimate and approved
live security/lifecycle evidence. Lambda artifacts agreed so far:
`history_read_api.zip`, `history_mutation_api.zip`, `history_lifecycle.zip`, all
`app.lambda_handler`; `conversation_analysis.zip` remains the synchronous
completion producer. No projector is needed for the chosen transaction design.
