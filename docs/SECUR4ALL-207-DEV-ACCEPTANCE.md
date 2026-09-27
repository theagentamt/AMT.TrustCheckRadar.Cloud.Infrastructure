# SECUR4ALL-207 remaining Dev acceptance

This September 26, 2026 assessment supersedes historical readiness statements
only where newer evidence establishes the result. SECUR4ALL-207 remains In
Progress. No whole-period completion, key retirement, general campaign admission,
UAT deployment or retention-policy change is claimed.

## Reuse completed evidence

[SECUR4ALL-200 Dev acceptance](SECUR4ALL-200-DEV-ACCEPTANCE.md) is complete in
infrastructure release merge `32527c7c7d4fa292fdade5a1a25fd193738bf907` and Lambda
release merge `c5ef506d3e83390fad75f913f9292fdaa48c0a20`.
Its actual account deletion, twelve genuine component receipts, credential
rejection, same-email isolation, paired campaign cleanup, and composed stale-copy
quarantine can be referenced where the same source and resource assumptions apply.
These results do not prove whole-period lifecycle or research withdrawal.

Earlier [period admission](CAMPAIGN-PERIOD-ADMISSION.md),
[completion integration](CAMPAIGN-COMPLETION-INTEGRATION.md), and
[restore qualification](CAMPAIGN-RESTORE-QUALIFICATION.md) records preserve their
original artifact pins and limitations. Statements in those dated records that
account deletion is disabled or unimplemented describe that historical increment;
use the later account-deletion evidence for its current qualified scope.

## Remaining criterion map

| Dev requirement | Existing evidence to reuse | Remaining proof |
| --- | --- | --- |
| Stop contributions before closing a period | OPEN-to-CLOSING transaction guards, late cluster delivery refusal, exact inventory/generation checks | Complete family discovery, orphan/repair recovery and a stable sealed boundary; empty eventual indexes or queue counts are insufficient |
| Enforce every retention deadline | Paired locator cleanup, metadata reconstruction, per-account durable recovery and bounded publication steps | Scheduled, resumable and fair expiry across observations, features, tokens, dedupe, candidates, repair/tombstone state and persistent aggregate expiry; TTL-lag, poison and interrupted-work cases |
| Retire keys safely | Exact period metadata validation; legacy time-only retirement is unreachable | Qualified proof before disable/schedule, exact-key ownership, interrupted-response recovery, and later account/withdrawal cleanup consuming a valid retired-period proof; PendingDeletion must remain distinct from destruction |
| Complete research withdrawal | Individual consent fences and per-account cleanup components | Composed actual-producer withdrawal through withdrawn state, audit and COMPLETE command, plus delayed outbox and dead-letter replay refusal |
| Preserve privacy under restore and operational failure | Current storage/copy metadata audits, account stale-copy quarantine, alarms and runtime readbacks | Lifecycle-specific retention/copy mapping, restored period/expiry replay refusal, stuck-work detection and exercised recovery runbook; native restore and reopening remain SECUR4ALL-245 |
| Keep published data non-linkable | Threshold/dimension, frozen candidate and publication-race tests | Whole-period accounting for every pending candidate, including bounded-work refusal and recovery; no truncation-based completion |

The expired orphan/candidate cleanup path is a prerequisite to safe whole-period
sealing. Implement and review bounded increments without treating a source-only
helper as a deployed scheduler or complete erasure proof. Final retirement must
not strand future withdrawal/account deletion by removing the key before all
necessary unlinking and qualified proof are available.

## Infrastructure baseline for the orphan cleanup increment

The [read-only AWS snapshot](evidence/sec207-orphan-recovery-2026-09-26/lifecycle-readback-before.json)
at September 27 02:42 UTC records the exact lifecycle function, four inline
policies, no attached managed policies or permissions boundary, and three legacy
lifecycle schedules. The function is Python 3.14 ARM64; candidate and admission
gates are false, inventory revision is zero, and manifest/generation pins are
absent. All three schedules are disabled. Their old operation payloads do not
match the current handler, so enabling them is not a valid way to schedule the
new cleanup operation.

The observed identity-policy statements already cover the proposed pipeline
Get/Query, paired candidate/contributor deletes, and period/inventory/candidate
checks. No new permission is currently identified. This is static policy review,
not actual application authorization, SCP/resource-policy qualification or a
guarantee against later configuration changes. Existing mutable-family grants
also allow standalone/batch writes; existing tagged KMS management grants remain
present although orphan cleanup requires no KMS calls. No permission narrowing
or new key-retirement protection is claimed by this readback.

The snapshot changed no resources, read no table records and invoked no function.
Separate deletion-recovery schedules were outside this observation and unchanged.

## Qualified bounded orphan cleanup

Lambda source `68198f448f378508783925526a59cc3454137c6a` adds the operator-only
`recover_expired_orphan` lifecycle operation and coordinated version-2 repair
checkpoint handling. It reads the full bounded candidate partition before
deletion, requires exact supported expired records and owned locators, and
checks CLOSING period/generation, inventory, absent summary and checkpoint state
in every transaction. It removes at most ten pairs per call and requires a
later strong-read call before removing the final checkpoint. It never returns
whole-period completion or retirement eligibility. Legacy orphan checkpoints,
unknown/mixed/live records and partitions beyond four pages/100 rows remain
unmodified and unresolved.

Local validation passed 342 bridge tests plus nine subtests and 63 lifecycle
tests, including 27 orphan cases independently rerun by the reviewer. Final
fixture-routing validation passed six affected cases. These counts overlap;
they are not additive unique coverage claims.

The [package verification](evidence/sec207-orphan-recovery-2026-09-26/package-verification.json)
matched all 99 Python members to the frozen Git source. The
[manifest](evidence/sec207-orphan-recovery-2026-09-26/package-manifest.json) records
four coherent production archives and the separate 224114-byte test archive,
SHA256 `15b13d8a53d2a989dfb72ce4784d8fca991d63415237052a77f7503c7728346d`.

Actual isolated AWS Python 3.14 ARM64 results all passed:

| Case | Result and evidence |
| --- | --- |
| Twelve expired pairs and final checkpoint | [Bounded drain passed](evidence/sec207-orphan-recovery-2026-09-26/orphan_handler_drain.json) |
| Legacy checkpoint without trustworthy period identity | [Refused without deletion](evidence/sec207-orphan-recovery-2026-09-26/orphan_handler_legacy_refusal.json) |
| Partition containing a live contribution | [Refused without deletion](evidence/sec207-orphan-recovery-2026-09-26/orphan_handler_live_refusal.json) |
| Committed deletion with lost acknowledgment | [Fresh-state recovery passed](evidence/sec207-orphan-recovery-2026-09-26/orphan_handler_lost_ack.json) |

These cases invoke the packaged actual handler and real DynamoDB transactions.
They use synthetic inventory/clock/period metadata, dedicated fixture tables
and a fixture role. They do not qualify deployed lifecycle permissions, native
backups, real discovery/scheduling, authenticated withdrawal or key retirement.
No production archive was deployed or application gate changed.

[Independent cleanup](evidence/sec207-orphan-recovery-2026-09-26/cleanup-readback.json)
confirmed all three tables, the function and role absent. The disposable HMAC
key is PendingDeletion for October 4 UTC (October 3 local); it is not destroyed.
The [reviewed invocation wrapper](evidence/sec207-orphan-recovery-2026-09-26/invoke-fixture.py)
is retained as execution evidence, not a ready-to-run general operator tool.

Lambda source publication is pending explicit public-repository authorization
required by automatic approval review. Local implementation, package review and
isolated runtime qualification are complete for this increment; remote release
integration is not yet claimed. SECUR4ALL-207 remains In Progress for the other
Dev requirements above. Existing contribution expiry can extend later than the
period key's nominal retirement time; the complete retirement protocol must
resolve this under the approved policy before any key retirement is enabled.

## Ownership and completion

Lambda owns cleanup, publication, sealing/retirement protocols, recovery and
behavioral tests. Infrastructure owns exact IAM, schedules, monitoring,
environment isolation and scoped runtime qualification. Independent review checks
the evidence and cross-component contract. Android is not a prerequisite for
backend delivery; emulator integration can proceed against qualified contracts.

Preserve the approved 14-day period plus 7-day recovery window, observation
maximum of 72 hours, transient maximum of 21 days and approved aggregate/audit
400-day lifetime. Do not reset deadlines on retries. New retained state requires
an explicit purpose and approved lifetime; an implementation convenience does
not grant a retention exception.

Use only dedicated synthetic Dev resources for destructive qualification. Do not
disable real period keys merely to test a candidate. Record exact artifact/policy
hashes, outcomes, cleanup and residual scheduled key deletion. Existing account
and campaign admission remain outside this increment.

Later UAT execution is tracked in
[SECUR4ALL-330](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-330), which
depends on SECUR4ALL-207 and contains the linked
[release test guide](SECUR4ALL-207-RELEASE-TESTS.md).
All unfinished Dev criteria above stay in SECUR4ALL-207. Done requires reviewed
implementation, required component/Dev acceptance, runbook, pushed commits and
verified integration into remote `release-V01`, followed by tracker evidence.
