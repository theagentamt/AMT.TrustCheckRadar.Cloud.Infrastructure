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
