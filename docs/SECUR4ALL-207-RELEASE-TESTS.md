# Campaign lifecycle release qualification

Source story: SECUR4ALL-207. Status: planned, not executed. Target sprint:
Backend V1-5 - Release qualification. This guide moves later UAT execution only;
unfinished implementation and Dev acceptance remain with SECUR4ALL-207.

Tracker: [SECUR4ALL-330](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-330),
To Do, depends on SECUR4ALL-207. The tracker contains these full instructions so
execution does not depend on a local skill installation.

## Preconditions and exact build

1. Confirm SECUR4ALL-207 Dev criteria and relevant SECUR4ALL-245 restore/resource
   prerequisites are satisfied. Coordinate the account journey with SECUR4ALL-329;
   its deletion results alone do not qualify whole-period lifecycle.
2. Record exact infrastructure and Lambda release commits, immutable package
   versions/hashes, contract versions, AWS account/region, table/key identities,
   inventory generations and worker settings. Promote tested artifacts through
   the reviewed deployment pipeline when UAT execution is authorized.
3. Apply environment differences through reviewed infrastructure configuration.
   Do not copy Dev inventory approvals, manually open writers, or change retention
   to speed up a test. Establish the planned clock/age fixture boundaries before
   execution. Native key destruction requires the actual provider waiting period.
4. Verify actual IAM, schedules, queue/DLQ settings, alarms, source-bound inventory
   and external generation pins. Deployment success is not a behavioral pass.

## Reusable Dev evidence and remaining release work

The tested production source is `9147d545b719e54c1f967e35042bc502d79bc0f1`;
Lambda fixture/documentation head is `8d4bbbd3dae0411e3ccfcbf94573180af9c45091`.
Resolve their final release integration before promotion. See
[Dev acceptance](SECUR4ALL-207-DEV-ACCEPTANCE.md),
[operations](CAMPAIGN-PERIOD-OPERATIONS.md), and the
[immutable artifact manifest](evidence/sec207-period-dev-deployment-2026-09-27/private-artifact-publication.json).
These are a reference baseline; do not copy Dev table identities or approvals to UAT.

The committed Dev fixture entry points are
`scripts/campaign_period_lifecycle_fixture.py` (complete_replay, poison_recovery,
lost_ack, retire_then_complete) and `scripts/campaign_period_retirement_fixture.py`
(guards_and_complete_replay, lost_ack), each with prepare/run/cleanup operations
and an ownership journal. They are explicitly bound to the qualified Dev account
and dedicated resources. Do not change their account guards to call them a UAT
runner. The whole-period composition includes real DynamoDB/KMS with controlled
clocks and transport; authenticated HTTP, native queue/DLQ and backup restore
still require the assembled release cases below. Existing successful Dev fixtures
need not be repeated merely to claim UAT progress.

Before UAT execution, the release owner must supply a reviewed target-bound
runner/observer for these missing assembled paths, with a bounded clock strategy
that does not shorten real retention or key deadlines. Verify request/response
contracts against the selected Lambda version; retain the existing Android
account-deletion cleanup contract and emulator cases. Link any new defect or
runner work to its owning component. Hardware remains ATCR-148.

For fresh schedule qualification, record actual scheduled invocations separately
from any operator invocation. A two-shard-per-tick aggregate sweep takes eight
ticks to visit all sixteen shards; at the current five-minute cadence allow
45 minutes plus up to 10 minutes for metric/alarm ingestion. Do not reset the
full-pass clock or change alarm thresholds to skip first-pass validation. The
initial missing full pass may legitimately alert. Require a real completed pass,
subsequent fresh metrics, and observed alarm recovery; notification to SNS does
not itself prove support inbox receipt.

## Fixtures and cases

Use dedicated synthetic accounts and period resources, never existing customer
or appreview identities. Capture an independent unrelated-data baseline. Include
populated examples of every transient family, multiple periods, stale/legacy
records, orphan candidates, incomplete repairs, subthreshold dimensions and
pending publication. Store credentials only in private runtime inputs.

| Case | Action | Observable expected result |
| --- | --- | --- |
| Withdrawal | Invoke the actual authenticated participation withdrawal contract, then deliver delayed owned work | Future contribution is denied immediately; owned active/unfinalized data is removed within 24 hours; withdrawn/audit/COMPLETE appear only after genuine cleanup |
| Account deletion | Exercise the versioned POST/GET account-deletion contract with populated campaign contributions | Genuine campaign receipts precede completion; delayed work cannot recreate contributions; reuse SECUR4ALL-329 for the broader identity journey |
| Admission close | Close an ended period while racing publisher/cluster writes and delayed deliveries | New writes fail the exact generation/period fence; permitted cleanup can continue; no premature seal or key retirement |
| Deadline enforcement | Exercise each approved age boundary with TTL deletion deliberately absent and an interrupted bounded batch | Explicit purge/recalculation makes progress fairly, never extends deadlines, and reports backlog/incomplete honestly |
| Whole-period finalization | Process all pending candidates, orphan and repair work, including work over one invocation's bound | Every family is accounted for before sealing; no truncated or eventual-index-only proof; sparse/conflicting candidates do not become confirmed consumer claims |
| Key retirement | Use only disposable period keys with qualified sealed proof; interrupt disable/schedule acknowledgments | Exact-key recovery converges, MAC use fails after disable, no re-enable or deadline refresh; schedule uses approved minimum waiting period |
| Later cleanup | Withdraw/delete after period retirement | Valid scoped retired-period proof permits truthful completion without regenerating tokens; absent/stale proof remains incomplete |
| Queue and restore replay | Replay actual synthetic dead-letter messages and isolated stale records, coordinating native restoration with SECUR4ALL-245 | Withdrawn/deleted/expired contributions stay unavailable; restored stale generation/proof cannot reopen serving; requalification precedes reopening |
| Failure and monitoring | Inject a bounded partial failure, missed invocation and poison item | No false completion; progress/support state persists, recovery works, and privacy-safe alerts reach the configured support topic |

For every case define a bounded observation deadline and retry policy from the
selected contract. A timeout is incomplete evidence, not a pass. Preserve the
original operation identity and distinguish deliberate idempotency testing from
blindly retrying an ambiguous destructive request.

No complete UAT runner is claimed by this guide. The implementing owner must
provide the exact committed runner entry points, environment parameters,
populated fixture preparation and independent observers before execution. Verify
those against the selected release, rather than adapting hard-coded Dev helpers
through undocumented manual changes.

## Evidence and cleanup

Attach a case matrix with passed/failed/blocked/not-run results, timestamps,
artifact hashes, policy/configuration readbacks and independent observations.
Separate mocks, isolated AWS, installed UAT workers, native restoration, actual
queue delivery and provider key destruction. PendingDeletion is not destruction.
Show approved retention across tables, queues/DLQs, streams, logs, backups,
exports and any fixture files without copying content or identifiers into reports.

Route operational alerts to support@andmorethings.com. Distinguish SNS/provider
delivery from observed inbox receipt. Retain fixed reasons/counts rather than
content, tokens, contributor identifiers or account-level dimensions in telemetry.

Remove only owned synthetic fixtures, verify unrelated baseline preservation and
record pending key deletion or unresolved cleanup explicitly. On failure, follow
the reviewed recovery runbook and link defects to their component owner. Do not
re-enable a retired key or bypass stale-generation checks to obtain a pass.

This release story closes only when its required UAT cases and evidence pass.
Physical-device cases remain in mobile follow-ups (Android ATCR-148); emulators
and backend automation require no hardware. This plan authorizes no general
campaign access, UAT/Production deployment or promotion to main by itself.
