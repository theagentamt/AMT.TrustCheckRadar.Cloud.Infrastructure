# SECUR4ALL-207 restore and runtime qualification

This work qualifies current storage metadata and isolated completion behavior.
It does not establish historical erasure, approve an inventory, restore customer
data, or enable campaign processing or account deletion.

## Current storage evidence

The bounded [metadata audit](evidence/campaign-restore-2026-09-24/storage-metadata.json)
observed the five exact Dev tables in account 107827791950/us-east-1. All listed
native backups, AWS Backup recovery points and exports were empty. Campaign
outbox/pipeline PITR is disabled; intelligence, users and deletion-ledger PITR
is enabled with 35-day recovery. None of those current tables reports restore
lineage or replicas. TTL is enabled on expiresAt except the deletion ledger,
which intentionally retains fences without TTL.

These are separate control-plane observations, not a frozen snapshot or proof
that copies never existed. ListExports has a 90-day history window and cannot
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

The bounded [CloudTrail management-history audit](evidence/campaign-restore-2026-09-24/control-history.json)
found no matching backup creation/deletion, restore, export, import or table deletion
for the five current table identities from their earliest current creation time
(2026-09-04 UTC) through the audit. Seven event-name traversals completed without
unclassified records. Other table deletions are counted separately, without names.
This is a regional management-event observation; it does not cover item-level
copies, earlier deleted tables or other accounts/regions. The exact executed
[dated script](evidence/campaign-restore-2026-09-24/control-history-audit.py) is retained
with its source hash. No CloudTrail event payloads or identities are persisted.

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

The [queue metadata readback](evidence/campaign-restore-2026-09-24/queue-metadata.json)
observes the encrypted clustering queue with four-day retention and its encrypted
DLQ with 14-day retention. All current approximate backlog counts are zero. No
message was received or redriven; this does not establish historical delivery or
replay safety.

## Isolated runtime fixture contract

The infrastructure runner creates three on-demand DynamoDB tables with fixed PK/SK,
a Python 3.14 ARM64 function with reserved concurrency 1 and timeout 60 seconds, one role and one HMAC_256
key. All names use a 12-hex random run ID under amt-campaign-completion-qual-.
Exact tags bind cleanup and runtime inputs. No table backups, streams, schedules,
API routes, log grants, provider access or production-resource grants are added.
The role permits only fixture table setup/cleanup and completion operations plus
DescribeKey/ListResourceTags/GenerateMac on the fixture key. Because the runner
seeds fixtures, this role is broader than a future production completion role;
these tests establish runtime semantics, not production least-privilege acceptance.
The runner uses one synthetic HMAC key for two modeled retained periods; it does
not qualify actual key rotation, historical destruction or native backup restore.

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
region, names and all ownership tags using explicit checks that work under python -O.

## Retained-period observation

The [fresh registry/key audit](evidence/campaign-restore-2026-09-24/period-registry.json)
again observes period 1478 RETIRED with its HMAC key PendingDeletion, and period 1479
ENABLED with its key Enabled. Both metadata/tag correspondences match. The audit
never derives contributor tokens or modifies key state. The retired period still
cannot satisfy the candidate's ENABLED-key proof. No original command, inventory
minimum period or approval timestamp is rewritten to avoid that failure.

## Remaining historical acceptance

- Complete lineage for all historical/current writers, legacy schemas and copies.
- Prior-period erasure evidence, including the unqualified retired period 1478;
  PendingDeletion is not destruction and missing HMAC derivation is not erasure.
- Qualified publication suppression and aggregate anonymity after restore.
- Safe key/tombstone retirement and prevention of legacy age-only cleanup paths.
- Actual coordinated handler/package/IAM integration and operational recovery.

The completion candidate must reject missing, stale or changed evidence. Passing
synthetic tests cannot establish these historical facts. Keep 207 In Progress
until its own remaining acceptance is complete; mobile devices are not a blocker.


## Verified AWS runtime results

Lambda [PR57](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/57)
source `ea9b6361f879ed3ee0420e6024d569c2e2f025b1` is integrated into release-V01 at
`46c12275d0fd4a116d8526eff487bed2b8a5e3dd`. The exact qualification archive
`ebf372912956cbecff37bdd31f73251085cb1b079e6cd0a3d32cf0fbbc4f1f5f` (42,789 bytes,
21 Python members) was independently reviewed and executed on the disposable
Python 3.14 ARM64 Lambda. The [package manifest](evidence/campaign-restore-2026-09-24/package-manifest.json)
binds each member to source. Existing Dev function packages were not changed.

All [28 actual AWS cases](evidence/campaign-restore-2026-09-24/runtime-results.json)
passed. Cases cover account/withdrawal completion, duplicate/lost acknowledgment,
concurrent completion, overlapping withdrawal, stale profile/ledger/pipeline and
inventory/control/job state, retained-key registry failures, post-completion
locator resurrection, replay expiry, proof/writer races, delayed recovery producer,
resource/environment rejection and budget cutoff. Races and lost acknowledgments
are deliberately injected around actual DynamoDB/KMS operations; this is not
uncontrolled network-fault or production writer acceptance. Modeled retired-key
cases change registry metadata rather than disabling a live period key.

Positive replay now reacquires fresh partition/tombstone/key proof and performs a
condition-check-only transaction against exact durable evidence. Fresh clock and
expiry checks before and after that transaction reject receipts/audits that expire
during verification. Lost verification acknowledgment fails closed; an ambiguous
completion mutation can reconcile only through the same fresh verification path.
No replay refreshes retention or rewrites a completed command. Terminal whole-account
acknowledgment still cannot independently claim campaign erasure.

Local source validation passed 212 combined SDK/Moto cases, 17 lifecycle cases,
and six ordinary bridge cases plus nine subtests. The final 49-case runner suite
is overlapping validation, not additional unique coverage. Independent review
verified all packaged source bytes and production app.py remains unwired.

The [cleanup readback](evidence/campaign-restore-2026-09-24/cleanup-readback.json)
independently confirms all three tables, function and role are absent. The fixture
key is PendingDeletion, scheduled for 2026-10-02 UTC; it is not yet destroyed.
The [Dev readback](evidence/campaign-restore-2026-09-24/dev-runtime-readback.json)
confirms unchanged affected function code/configuration, four disabled schedules,
three disabled mappings and eight alarms with actions disabled. Live deletion and
recovery enrollment/execution remain disabled. The fixture journal records the
complete resource lifecycle without customer records.

This completes the scoped current-metadata audit and isolated completion-runtime
qualification. Full historical erasure, native restore admission/reconciliation,
all publication/retirement paths, and coordinated production-handler integration
remain open under SECUR4ALL-207. No marker is approved by these results.
