# History lifecycle infrastructure

Owner: SECUR4ALL-223. Runtime owner: SECUR4ALL-226 in the Lambda workspace.
Status: deployed to Dev on 2026-09-14 with the schedule and runtime disabled.
UAT/Prod remain disabled. This is not lifecycle or customer-feature acceptance;
see `docs/HISTORY-DEV-DEPLOYMENT.md` for verified deployment evidence.

## Ownership and dependencies

State: `<state_key_prefix>/<environment>/history-processing.tfstate`.
Reads versioned contracts from `foundation` and `history-data` in the same
prefix/environment. Disabled configurations read neither state and create no
AWS resources. Enabled plans reject mismatched table names, account/region ARNs,
schema versions and disabled data contracts.

This stack provisions one Python 3.12 arm64 lifecycle Lambda, a scoped role,
14-day log group, five-minute EventBridge rule and invocation permission. It
does not expose HTTP endpoints, alter conversation-analysis, configure account
bootstrap, or create queues, streams, VPCs or data buckets. The existing artifact
bucket is used with `releases/<release_id>/history_lifecycle.zip`, an explicit
S3 object version and base64 SHA-256 source hash. Local ZIP hashes are not proof
that a release has been uploaded.

Release acceptance note (2026-09-14): uploaded release
`0fad0cc500372bba5e66b08f90a743c5fb557bb2` lacks mandatory runtime retention-floor
validation and must not be selected for deployment. Local successor `68dd8df`
contains that correction. Its full release
`68dd8dff55bdb2c857cca00133ee3530de767fa7` has now been uploaded and pinned in the
disabled Dev worker after explicit deployment and Dev storage-policy approval.

IAM allows only the content/control operations, exact expiration/pending GSIs,
and analysis-abuse replay redaction required by the lifecycle handback. Leading
keys constrain environment checkpoint and record families. The function cannot
Scan tables or access campaign resources. Logs use Embedded Metric Format, so
no general CloudWatch PutMetricData or SNS publishing grant is required.

## Provisioning and activation

- `lifecycle_deployment_enabled` controls resource existence. It requires an
  immutable artifact and separate promotion approval in UAT/Prod. Turning this
  off after provisioning requests destruction; it is not an operational switch.
- `lifecycle_active` independently enables the schedule and runtime cleanup.
  It requires an explicitly accepted runtime policy and SNS alarm destination.
  Keep it enabled while accepted data or unfinished erasure/completion work
  remains. A write-side kill switch must not abandon cleanup.
- `runtime_policy` has no numeric defaults: approved mutation receipt days,
  earliest expiry/checkpoint bootstrap hour (Unix seconds), per-sweep item/query
  caps, reconciliation hours, erasure batch size and completion age/recheck
  intervals must be supplied. These are not inferred from synthetic tests.
- Dedup retention comes from the data policy in seconds and must convert
  exactly to whole days and cover at least 90-day History plus its 24-hour
  cleanup window. This is a safety lower bound, not approval of a duration or
  proof of longer outage/restore coverage. Tombstone retention and mutation receipt
  retention remain distinct decisions; neither is silently reused for another.
- Current Lambda bounds are 3..1000 items, 40..1000 expiration bucket queries,
  1..168 reconciliation hours and 1..25 items per erasure batch. Limits bound
  handler work, not total AWS requests: retries, checkpoint writes, replay
  redaction and index operations also consume capacity.

Runtime: 256 MiB, 60-second timeout, reserved concurrency one. EventBridge sends
only `{"schemaVersion":1,"operation":"sweep"}`, retries twice within 300 seconds;
Lambda asynchronous retries once within 300 seconds. Durable table work must
survive exhausted delivery or processing attempts. These caps require a bounded
load/erasure acceptance test before activation, not automatic increases.

All unrelated read/write/replay/mutation/recognition flags on this worker are
false. That does not configure the separate producer's durable-replay latch.

## Monitoring

An active worker gets six lifecycle alarms (heartbeat, failure, truncated work,
stuck completion, overdue erasure, expiration checkpoint lag) and two Lambda
alarms (Errors/Throttles). The missing-success heartbeat breaches after two
five-minute periods. Lifecycle metrics have only `Environment` as a dimension.
SNS delivery must be verified separately; a valid ARN does not prove delivery.

See `docs/HISTORY-OPERATIONS.md` for readiness, restore and incident requirements.
Read/mutation/producer metrics and early SLA-warning thresholds remain separate
work; these eight alarms are not the complete feature's monitoring suite.

## Release sequence

1. Approve remaining policy and contract decisions in SECUR4ALL-185/ATCR-84.
2. Resolve Lambda lifecycle recovery/configuration review and account
   bootstrap/deletion/export hooks. Record verified immutable artifact versions
   and manifest for the final accepted code, superseding older releases as needed.
3. Review and explicitly authorize same-environment foundation/history-data
   plans, then history-processing. Use separate provisioning and activation
   reviews. A processing-only workflow assumes data was already applied.
4. Prove notification delivery, TTL-independent erasure, interrupted cleanup,
   restore reconciliation and bounded-load behavior before accepting data.
5. Separately wire and accept read/mutation routes and producer IAM/config.

The deployment workflow accepts `history-processing` or `all` scope; existing
workflow behavior also plans foundation and applies it in apply mode. For a
strictly processing-only reviewed plan, use `scripts/terraform.sh plan dev
history-processing` with the required state environment variables. Main pushes
can deploy Dev automatically: do not push/merge as a substitute for approval.

## Local tests

`terraform init -backend=false`, `terraform validate`, and `terraform test`.
Tests mock AWS providers and both upstream state contracts; test `apply` runs
are mock execution, never cloud provisioning. No active Dev test was performed.
