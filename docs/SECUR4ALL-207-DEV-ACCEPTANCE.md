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
