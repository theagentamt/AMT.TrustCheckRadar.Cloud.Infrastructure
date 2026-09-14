# History and Badges operations

Owner: SECUR4ALL-223 (infrastructure), with SECUR4ALL-224/225/226 (Lambda).
Status: Dev storage and a disabled lifecycle worker were deployed on 2026-09-14;
see HISTORY-DEV-DEPLOYMENT.md. No live feature/erasure acceptance or activation
is claimed. Monitoring is not deployed; UAT/Prod remain disabled.

Current Dev approval: both tables use 7-day PITR; minimal dedup/deletion metadata
has an approved 120-day lifetime; mutation receipts are approved for 7 days.
The receipt setting awaits the complete runtime-policy configuration. Remaining
contract, account lifecycle, restore and operational acceptance gates below still
apply. Later release status supersedes historical local-only handback notes.

## Readiness and privacy gates

Before accepting customer data, require all of the following evidence:

- SECUR4ALL-185/ATCR-84 approval for numeric backup, dedup, tombstone and cursor
  retention; final schema/catalog/qualification rules and repeated-content
  policy. Synthetic Terraform test values are not production configuration.
- Immutable Lambda manifests and passing contracts for durable completion,
  same-ID replay, deletion/reset, account isolation and legacy result recovery.
- One environment-specific plan with explicit table, index, role, API,
  schedule, artifact and notification destinations. Confirm account/region and
  current principal with the user's CLI credentials, never browser login here.
- A confirmed SNS subscription and publish policy allowing CloudWatch alarms
  from the intended account/region. A syntactically valid topic ARN is not
  delivery proof. Use an existing approved topic, not an unapproved mailbox.
- Low-volume synthetic notification and recovery tests, independently approved.
  Do not provoke throttling in shared Dev or send real assessments to test
  observability. Do not run paid model calls without explicit bounded approval.
- Full account-deletion/export and restored-backup erasure integration. The
  foundation deletion ledger and a campaign bridge are not substitutes.

History retains only the privacy-reviewed original assessment, source, server
completion time and approved operational fields. Never copy submitted text,
snippets, images, original entities, tokens or device fingerprints into logs,
alarm descriptions, ticket attachments or test artifacts. Metric dimensions are
resource names, not account/request IDs. No Contributor Insights key logging.

## Implemented storage monitoring

Opt-in `monitoring = { alarm_topic_arn = "<approved same-region standard SNS ARN>" }`
requires provisioned History data and an explicit destination. Null creates no
alarms or dashboard. Existing tables may be provisioned without this option,
but that is NOT a production-readiness claim or approval to activate ingestion.

Two metric-math alarms sum five explicit resource series each: content table,
control table, each ExpirationIndex, and control PendingLifecycleIndex. The
read alarm uses ReadThrottleEvents; the write alarm uses WriteThrottleEvents.
Any event during a five-minute interval raises the corresponding alarm; recovery
also notifies. Missing throttle metrics are non-breaching because idle resources
may not publish events. This is not a worker-heartbeat check.

The environment-specific history-storage dashboard shows the individual
read/write series to locate the bottleneck. Base-table metrics do not include
GSI throttle events. For future SystemErrors alarms, use TableName AND Operation;
a TableName-only SystemErrors series does not receive DynamoDB data. Reference:
[AWS metric dimensions](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/metrics-dimensions.html).

The configuration creates two alarms evaluating ten underlying metric series
and one dashboard, not a complete service-monitoring suite. Include metric-math
billing, the dashboard, table/index operations, storage and approved PITR in the
cost estimate before enabling. Do not infer cost from alarm count alone.

## Throttle or persistence incident

1. Identify the environment and exact alarm/resource. Confirm scope without
   retrieving customer records. Check read versus write and the affected GSI.
2. Inspect low-cardinality request/error rates, Lambda concurrency and approved
   account rate limits. Distinguish retry storms, hot partitions, index limits
   and a broader AWS incident. SDK retries can mask transient storage errors.
3. Preserve original analysis request IDs and payload binding. Do not replay
   completed analyses as new scans, manually award badges, or delete dedup rows.
4. Reduce optional traffic using the eventual runtime controls or caller
   backoff; do not disable the data provisioning flag. Continue lifecycle
   cleanup for retained data. Never raise capacity or concurrency automatically
   to silence an alert; review demand, costs and a scoped plan first.
5. Confirm the alert recovers and notification reaches its destination. Record
   resource names, release IDs, counts, timing and outcome, not content.

## Runtime monitoring (implemented, not deployed)

### Local handback review

The Lambda owner returned commits `3f7c9b8`, `cd66909`, `e7f3531` and
`0fad0cc500372bba5e66b08f90a743c5fb557bb2` on the unpushed
`codex/sprint-7-history-badges` branch. The owner reports separately authorized
artifact-only publication of release `0fad0cc500372bba5e66b08f90a743c5fb557bb2`
to the Dev artifact bucket, with versioned objects and matching SHA-256 metadata.
No functions or infrastructure were deployed or activated. Exact S3 object
versions still need to be collected and checked before setting Terraform inputs.
Do not select that uploaded release for deployment: it lacks the mandatory
retention-floor validation. The Lambda owner supplied local successor `68dd8df`
with matching write/lifecycle/mutation guards and reports 223 tests plus 91
subtests passing (campaign_contracts excluded locally for missing jsonschema).
That successor is not uploaded. An authorized new immutable release of `68dd8df`
or a later reviewed descendant must supersede `0fad0cc`; never overwrite the old
release or substitute a local checksum for a verified S3 object version.
The runtime handback specifies
`{"schemaVersion":1,"operation":"sweep"}` every five minutes and EMF namespace
`AMT/TrustCheckRadar/History`. Lifecycle dimensions are Environment only; API
metrics use Environment and one of six fixed Operation values.

The agreed heartbeat is LifecycleSweepSuccess=1 per successful sweep, including
an empty sweep; missing success must breach after two five-minute periods.
Failure, saturation, overdue erasure and stuck completion counts must alert.
Age metrics use Seconds and counts use Count; incomplete observations must not
emit a fabricated zero age. `history-processing` now implements these six
lifecycle alarms and Lambda Errors/Throttles alarms, behind disabled deployment
and activation gates. They are not deployed or operationally accepted.

Infrastructure review returned these lifecycle corrections to the Lambda owner:

- Expiry traversal needs durable, bounded pagination/checkpoints beyond a moving
  lookback. Pending completion observations must not repeatedly monopolize the
  first page and starve later erasure jobs. Prove recovery after outages/backlog.
- Clear/expiry cleanup must explicitly erase content-bearing short replay and
  staged-result copies; DynamoDB TTL alone cannot meet active purge within 24h.
  Test cleanup with TTL deliberately doing no physical deletion.

The later handbacks add durable checkpoints, replay redaction, current-hour
rechecks and rolling reconciliation of recently closed hours. The latest
handback addresses failure ordering and TTL-first deletion:
ACTIVE REQUEST locators independently enter PendingLifecycleIndex at content
expiry, and retain their work marker until replay redaction succeeds. The Lambda
owner reports regressions covering both failures and 220 passing tests plus 89
subtests (campaign_contracts excluded because local jsonschema is unavailable).
The new CompletedRetentionPurges metric is informational, not a success-heartbeat
replacement. These reported tests are not live erasure acceptance evidence.

The retention-floor configuration correction is implemented in infrastructure
and Lambda successor `68dd8df`: both reject dedup retention below 90 days plus
24 hours. Terraform requires exact whole-day conversion; Lambda requires an
explicit positive integer day count. Lambda boundary regressions reject 89/90
days and accept 91 with otherwise complete configuration. Final numeric retention
and longer outage/restore coverage remain explicit policy decisions; the safety
lower bound does not approve 91 days as the production policy.

Final IAM must reflect the corrected algorithm. Transaction grants use the
underlying PutItem/UpdateItem/DeleteItem/ConditionCheckItem actions constrained
by dynamodb:EnclosingOperation=TransactWriteItems, not an invented standalone
transaction permission. The data policy uses integer seconds while the current
Lambda accepts dedup/mutation days; finalize an exact policy mapping without
silent rounding or conflating tombstone and receipt retention.

### Runtime signal acceptance

The lifecycle signal names/units are wired from the handback. Full feature
acceptance still requires the following evidence and remaining API/producer
monitoring, not just eight configured lifecycle/function alarms:

| Signal | Acceptance requirement |
| --- | --- |
| Completion persistence failures | Distinguish durable RESULT_READY from failed commit and prove repair without a second charge |
| Pending completion/erasure age | Report oldest outstanding age in seconds, including jobs not processed this run; zero only after a successful empty check |
| Lifecycle success heartbeat | Missing successful scheduled runs must alert; a function returning normally is insufficient if work failed |
| Read/mutation authorization failures | Low-cardinality error class and environment; never identity/fingerprint/request dimensions |
| Lambda errors/throttles | Scope each actual function and separate transient retry from permanent contract failure |
| Erasure SLA | Escalate well before 86,400 seconds, and separately flag any breach; owner-approved warning threshold/cadence pending |

Do not create a DLQ alarm for a queue that does not exist: the agreed initial
design uses synchronous completion and durable control-table erasure jobs.
If invocation delivery uses EventBridge retries or a DLQ later, inventory their
payload and retention explicitly. Never invent a projector lag metric.

## Erasure or expiration incident

1. Preserve the immediate account/generation write fence and read exclusion.
   Stop new writes to an affected account when required; do not reopen deleted
   content merely to make a replay succeed.
2. Query the bounded PendingLifecycleIndex next-attempt buckets using the
   approved repair handler. ExpirationIndex queries enumerate due hour/shard
   buckets; pagination and durable checkpoints must recover jobs older than a
   short lookback. Do not Scan the whole table or expire unfinished erasure jobs.
3. Re-read authoritative state before conditional cleanup because GSIs are
   eventually consistent. Prevent a late worker from deleting a new generation.
4. Use the approved same-job retry/repair operation only. It must remove all
   content-bearing active copies (History, replay, staged result and any event
   content) within 24 hours of deletion/expiry, retaining only approved minimal
   dedup metadata. TTL is eventual cleanup, not proof of SLA compliance.
5. Validate with a disposable account: no deleted assessment via direct lookup,
   pagination, same-ID analysis replay, delayed completion or old-event repair.
   History clear must not reset Badges; badge reset must not count pre-reset
   submissions. Report failures and residual copies, never fabricated success.
6. Record missed deadlines and escalate to the privacy/product owner. Offline
   devices cannot be remotely erased while disconnected; force invalidation
   reconciliation on reconnect before displaying stale retained records.

## Restore and rollback

Backups are not exempt from the user promise. Before any restore:

1. Record the approved recovery window, selected point, affected environment,
   release/schema versions and deletion metadata retained for reconciliation.
2. Restore to isolated, non-serving tables with no production/mobile access,
   active event sources, ingestion or automatic schedules.
3. Reapply authoritative erasure intent and generation cutoffs newer than the
   backup across History, replay/control and account-deletion state. If the
   evidence has expired or cannot establish which data was erased, do not
   serve the restore; obtain an approved recovery disposition.
4. Expire out-of-retention content and test cross-account/read/replay/mutation
   behavior using synthetic data. Verify restore configuration including TTL,
   indexes, encryption, backup policy, capacity caps and monitoring.
   Before serving, reset EXPIRATION and RECONCILIATION checkpoints for both
   tables to the earliest restored expiry. Drain backlog and complete a full
   reconciliation cycle with no residual erasures. The normal rolling window
   alone cannot recover arbitrarily old restored records. This procedure needs
   a tested repair tool and recorded evidence, not ad hoc production writes.
5. Only after privacy/security acceptance may a reviewed plan change serving
   references. Securely retire temporary data under the approved policy.

For a bad software release, roll back only to a tested artifact compatible with
the active storage schema and deletion fences. An old pre-History Lambda might
ignore durable tombstones or double-charge after replay expiry; it is not a safe
rollback solely because it once deployed successfully. Do not roll back data or
erase control records to restore apparent availability.

`history_data_enabled=false` requests resource destruction after provisioning;
it is never an operational stop switch. Disable runtime ingestion separately
and leave cleanup running. No destructive command or restore is authorized by
this runbook.

## Handback evidence

Keep a release record with environment, approved policy reference, exact
source/artifact and plan IDs, deployed route availability, data and runtime
monitoring state, confirmed notification delivery, successful and injected
failure/recovery tests, erasure/restore outcomes, costs and named remaining gaps.
Report separately: provisioned, API deployed, security/lifecycle validated,
Android/iOS integration accepted. SECUR4ALL-223 remains open until its remaining
runtime wiring and acceptance criteria are complete.
