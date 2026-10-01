# Indexed campaign lifecycle operations

This runbook accompanies SECUR4ALL-207 and the Lambda
`docs/campaign-period-lifecycle-runbook.md`. The selected application source is
`9147d545b719e54c1f967e35042bc502d79bc0f1`. Deployment and behavioral acceptance
must be read from the dated evidence; this document alone does not enable work
or establish completion. General research ingestion remains closed.

## Source, inventory and deployment boundary

The reviewed inventory covers eight installed functions. Seven compatible
artifacts are independently pinned: account data, account export, observation
publisher, cluster aggregator, deletion bridge, lifecycle, and campaign review.
Conversation analysis retains its older coordinated migration artifact and an
explicit DynamoDB-write deny. Its work flag remains false. Do not describe the
prepared new analysis archive as installed, or enable that retired writer alone.

Use staged Terraform plans against `environments/dev`: pause API participants,
processing and review with existing artifacts first; independently read back
zero reserved concurrency, disabled mappings/schedules and closed gates. Add the
aggregate expiry index, install the seven reviewed artifacts while paused, then
verify all installed code hashes and table identities. Preserve the existing
account-deletion inventory, exact HTTP subject scope and unrelated API artifacts.
Never use the quiescence phase as a new account-deletion approval.

The external operator inventory binds complete bounded strong reads of pipeline,
outbox and intelligence to the deployed source, roles, table IDs and closed
writer configuration. `scripts/bootstrap_campaign_period_work.py` defaults to
read-only planning. Its apply requires the exact reviewed manifest/plan, a
serialized privileged-writer boundary and a drained interval of the maximum
published function timeout plus 60 seconds. It freshly rechecks the snapshot
and closure, journals intent, and submits one conditional transaction. It does
not make an arbitrary whole-table scan atomic. A privileged copy, restore or
concurrent operator write invalidates the boundary and requires requalification.

The current work inventory includes periods 1479 and 1480. The independent
account-locator minimum remains 1480. The older retired 1478 registry is preserved
and excluded under the earlier clean-start assessment; it is not converted into
new sealing or historical-erasure proof. Never derive approval from an empty
index, repair counters manually, invent a missing registry, or refresh deadlines.

An ambiguous bootstrap response requires independent marker/control/index
readback using the original intent and plan. Do not blindly rerun bootstrap.
Restore compatible cleanup capacity only after that readback. Lifecycle and key
retirement are separate gates. Future period creation uses the existing reviewed
create-only initializer process before admission; this worker cannot create keys.

## Scheduled work and support signals

Two separate five-minute Scheduler events target the pinned lifecycle handler:

```json
{"schemaVersion":1,"environment":"dev","operation":"reconcile_periods"}
```

```json
{"schemaVersion":1,"environment":"dev","operation":"reconcile_aggregates"}
```

The old lifecycle schedules stay disabled. Period ticks select at most two
numeric periods and perform bounded indexed work; aggregate ticks visit at most
two of sixteen expiry shards with bounded pages. Separate invocations prevent
period work from starving aggregate expiry. Retries retain original identities
and deadlines. GSI discovery is not erasure proof: expiry checks use strong target
reads and conditional transactions, and period sealing requires authoritative
work/control/proof checks.

Metrics use `TrustCheckRadar/Campaign` and only the `Environment` dimension.
Heartbeat means an invocation reached its reporting point, not completed erasure.
Failure and unverified-work alarms require investigation even when heartbeat is
present. Progress/full-pass age alarms expose stale bounded progress; the first
aggregate pass can legitimately report no completed pass until all sixteen
shards have been visited. Do not manufacture a zero metric to silence that state.
Observed deadline misses do not claim discovery of every unknown historical copy.

The raw progress-age metric includes future-dated retained work. Its alarm uses
`IF(overdue>0,age,0)` with observed deadline misses and maximum backlog age in the
same five-minute environment window. This prevents ordinary future-only backlog
from paging support. It does not prove that the same overdue record stalled for
an hour. The separate unverified-work, failure, heartbeat and full-pass alarms
remain necessary, including for malformed work rejected before its deadline can
be validated. This uses documented
[CloudWatch conditional metric math](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/using-metric-math.html).

For failure, preserve source, resource IDs, generation, original operation and
fixed reason/count diagnostics. Check source/role/resource drift and the relevant
bounded cursor before retrying the unchanged operation. Unsupported or malformed
records stay unresolved and must not be skipped to obtain a seal. Review any
repair against the original producer contract and retention clock. A successful
replay must be confirmed through actual target/control/proof readback.

Alarm actions target the existing campaign SNS topic with the confirmed
`support@andmorethings.com` subscription. Record alarm evaluation/action history
and SNS delivery separately; neither proves that a person read the email.
Synthetic alarm qualification must be labeled and must not corrupt application
records or alter real key deadlines. No user content, identities or tokens belong
in alarm dimensions or evidence.

## Retention and residual copies

| Surface | Approved or observed boundary | Operational meaning |
| --- | --- | --- |
| Sanitized observation | At most 72 hours, also capped by period recovery | Explicit deletion; TTL is defense in depth |
| Features, tokens, dedupe, candidates and repair/tombstone work | At most 21 days, capped by the fixed period recovery deadline | Work/lookup metadata retains the target's original deadline |
| Period | 14 days plus 7 days recovery | Closing stops admission; draining and qualified sealing precede key retirement |
| Non-linkable aggregate and privacy-safe audit | 400 days | Explicit indexed expiry; existing PITR copies are separately bounded |
| Anonymous aggregate progress | 24-hour cursor lifetime | Contains only shard and public aggregate continuation; does not extend target life |
| Period security/progress proof | Minimal non-account period/generation/counter evidence | Remains available for truthful later cleanup; is not user contribution history |
| Campaign queues / DLQs | Current control-plane retention: 4 / 14 days | Delayed delivery must independently reject withdrawn/deleted/expired work |
| DynamoDB stream | AWS-controlled stream retention; observed outbox NEW_IMAGE | Processing gates and replay fences remain required |
| Campaign function logs | Current retention: 14 days | Metadata-only diagnostics; retention setting is not content inspection |
| Pipeline / outbox backup | PITR disabled; no backups/exports listed in the bounded audit | Current inventory does not prove all historical or external-copy absence |
| Intelligence / account recovery stores | Existing PITR up to 35 days where recorded | Restore requires new reviewed generation/resource binding before reopening |
| Local qualification files | Synthetic records or metadata-only evidence | Never persist live content, credentials or purchase tokens in the repository |

Key retirement disables the exact owned HMAC key and schedules the minimum
seven-day deletion wait only after eligible qualified sealing. `PendingDeletion`
is not destruction. Never re-enable a retired key for testing. Current period
1479 recovery ends October 1 UTC and 1480 recovery ends October 15 UTC; early
retirement is prohibited. Native backup restore/reopening is SECUR4ALL-245.

## Completion and release handoff

Use `docs/SECUR4ALL-207-DEV-ACCEPTANCE.md` for the retained Dev criterion-to-evidence
map and dated deployment evidence for actual state. Local fixtures, real AWS SDK
tests, deployed handlers, schedules, alarm delivery, Git integration and release
readiness are distinct. Both repositories must be pushed and integrated into
`release-V01` before the story is Done. The open SECUR4ALL-330 and
`docs/SECUR4ALL-207-RELEASE-TESTS.md` retain later assembled UAT execution. Physical
Android testing remains in ATCR-148 and does not block independent backend work.
