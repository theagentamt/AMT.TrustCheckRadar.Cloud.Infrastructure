# SECUR4ALL-207 restore and runtime qualification

This work qualifies current storage metadata and isolated completion behavior.
It does not establish historical erasure, approve an inventory, restore customer
data, or enable campaign processing or account deletion.

## Current storage evidence

The bounded [metadata audit](evidence/campaign-restore-2026-09-24/storage-metadata.json)
observed the five exact Dev tables in account107827791950/us-east-1. All listed
native backups, AWS Backup recovery points and exports were empty. Campaign
outbox/pipeline PITR is disabled; intelligence, users and deletion-ledger PITR
is enabled with35-day recovery. None of those current tables reports restore
lineage or replicas. TTL is enabled on expiresAt except the deletion ledger,
which intentionally retains fences without TTL.

These are separate control-plane observations, not a frozen snapshot or proof
that copies never existed. ListExports has a90-day history window and cannot
prove old S3 objects are gone. The audit does not cover deleted/recreated tables,
other table names, regions/accounts, manually copied items or external dumps.
It reads no table items, backup payloads or export objects. Unavailable or bounded
observations cannot become successful empty inventories. Seven local tests cover
identity, denial, pagination, metadata projection and deadline behavior.

Source: [DynamoDB ListExports](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_ListExports.html).
DynamoDB's native backup list excludes AWS Backup-managed backups, so both
services are queried independently; see [ListBackups](https://docs.aws.amazon.com/cli/latest/reference/dynamodb/list-backups.html).

The owner reports [no known manual copies or restores](evidence/campaign-restore-2026-09-24/owner-history-statement.json).
This narrows known external locations; it does not independently qualify past
writer versions, retired periods or erasure.

## Restore admission stays closed

Any restored table is quarantined: do not point runtime environment variables,
Terraform remote-state contracts, IAM permissions, API integrations, mappings or
schedules at it. Do not copy restored records back into live tables to bypass
this boundary. A restore must not reuse or republish an old VERIFIED_COMPLETE
marker as new approval. All completion, locator, recovery and account inventory
pins require independent requalification after reconciled restore evidence.

Restoring users and ledger independently can rewind consent, deletion fences,
recovery counts or completion proof. Restoring aggregate data can undo later
suppression. Restoring the pipeline can resurrect contributors or omit tombstones.
Reconciliation must use authoritative current account/deletion evidence and
complete writer/period coverage before a separate reviewed admission change.
There is no automatic restore admission or reconciliation implementation in this
increment; these restrictions are the operational boundary, not a claim that an
administrator cannot bypass exact-resource IAM.

AWS restores to a new table and requires separately configuring IAM, streams,
TTL and other settings: [restore settings](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.Tutorial.html).
An actual native restore drill, if needed, must use synthetic backup data and a
new quarantined fixture. Replaying a constructed snapshot is a behavior test,
not evidence that AWS restored a backup.

## Isolated runtime fixture contract

The infrastructure runner creates three on-demand DynamoDB tables with fixed PK/SK,
a Python3.14 ARM64 function with concurrency1/timeout60s, one role and one HMAC_256
key. All names use a12-hex random run ID under amt-campaign-completion-qual-.
Exact tags bind cleanup and runtime inputs. No table backups, streams, schedules,
API routes, log grants, provider access or production-resource grants are added.
The role permits only fixture table setup/cleanup and completion operations plus
DescribeKey/ListResourceTags/GenerateMac on the fixture key. Because the runner
seeds fixtures, this role is broader than a future production completion role;
these tests establish runtime semantics, not production least-privilege acceptance.

The complete source ZIP and source commit are hash-pinned. One allowlisted case
is invoked at a time. Only sanitized case outcomes are retained. Synthetic marker
rows explicitly model approved invariants; they do not create or approve any
real inventory. Fixtures are removed after testing. The disposable KMS key must
be scheduled for deletion with its seven-day minimum, reported as PendingDeletion
until actual destruction. Never report it as already destroyed.

Preparation journals are written before creating the key. Failed preparation
requires cleanup using the same journal/run ID. Ambiguous key creation is resolved
only through bounded exact-tag discovery; zero/multiple matches or incomplete
traversal remains an unresolved cleanup condition. Cleanup validates account,
region, names and all ownership tags using explicit checks that work under python-O.

## Remaining historical acceptance

- Complete lineage for all historical/current writers, legacy schemas and copies.
- Prior-period erasure evidence, including the unqualified retired period1478;
  PendingDeletion is not destruction and missing HMAC derivation is not erasure.
- Qualified publication suppression and aggregate anonymity after restore.
- Safe key/tombstone retirement and prevention of legacy age-only cleanup paths.
- Actual coordinated handler/package/IAM integration and operational recovery.

The completion candidate must reject missing, stale or changed evidence. Passing
synthetic tests cannot establish these historical facts. Keep207 In Progress
until its own remaining acceptance is complete; mobile devices are not a blocker.
