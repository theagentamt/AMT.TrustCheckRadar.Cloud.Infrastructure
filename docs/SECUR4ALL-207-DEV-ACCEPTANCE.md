# SECUR4ALL-207 Dev acceptance

Current assessment: September 27, 2026. SECUR4ALL-207 remains In Progress until
the final deployed observations and public Git integration are verified. The
selected production source is `9147d545b719e54c1f967e35042bc502d79bc0f1`; Lambda
fixture/documentation head is `8d4bbbd3dae0411e3ccfcbf94573180af9c45091`.
General campaign research remains closed. Account deletion retains the original
SECUR4ALL-200 subject scope and approval inventory; export remains disabled.
UAT/Production deployment and physical testing have not been performed.

The dated sections below preserve intermediate evidence and limitations. Their
closed/unapplied statements describe those phases, not the final selected Dev
configuration. See the current criterion map and final deployment section for
the completion boundary. A synthetic seal, scheduled key deletion and completed
key destruction are distinct; no historical or application-period erasure is
inferred from an empty index.

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

## Current criterion map

| Retained Dev requirement | Evidence and qualified scope | Completion boundary |
| --- | --- | --- |
| Stop contributions and account for every family before sealing | Reviewed paired work/control protocol, exact resource/source inventory, orphan recovery, publication race/110-contributor SDK tests, and actual AWS composed 42-target lifecycle with poison and lost-ack recovery | Implementation/component acceptance passed; live scheduled preservation and full-pass observations recorded below |
| Enforce original deadlines fairly and explicitly | Actual early-deadline and full indexed drain, TTL-independent synthetic targets, fixed recovery cap; deployed separate period and aggregate schedules with real index/cursor execution | Full aggregate pass and subsequent freshness alarm recovery must be observed before Dev acceptance is complete |
| Retire exact owned keys safely and preserve later cleanup | Actual computed seal → guarded disable/schedule seven days → replay → account AND withdrawal completion without KMS; independent cleanup and separate lost-response retirement case | Disposable-key behavior passed; existing future keys remain enabled until their original recovery deadlines; PendingDeletion is not destruction |
| Complete withdrawal and refuse delayed work | Actual Python 3.14 ARM64 producer/withdrawal fixtures reach withdrawn/audit/COMPLETE and reject delayed outbox/cluster replay | Component scope passed; authenticated assembled journey and native queue redrive remain SECUR4ALL-330 |
| Restore and operational failure remain fail-closed | Scoped source/generation proof checks, prior SECUR4ALL-200 stale-copy quarantine, actual poison/lost-response recovery, control-plane copy inventory and lifecycle runbook | Actual scheduled alarm/action observation recorded below; native backup restore and reopening remain SECUR4ALL-245, assembled release execution SECUR4ALL-330 |
| Published data stays non-linkable | Threshold/dimension and late-tombstone race SDK tests; bounded candidate accounting, fail-closed poison/refusal, actual expired anonymous aggregate deletion preserving a future aggregate | Component scope passed; no general publication/research activation claimed |
| Infrastructure and release handoff are durable | Exact source/version/hash pins, 109-case actual IAM qualification, reviewed conditional bootstrap, Dev configuration, local Terraform/helper tests, operational and release guides | Final no-drift verification passed; independent final review, commit, public push and verified release-V01 integration are required before Done |

Use [the operations runbook](CAMPAIGN-PERIOD-OPERATIONS.md) for fixed retention,
recovery and alert interpretation. Existing account deletion is reused only for
its already-qualified component assumptions; it does not substitute for the
new whole-period fixtures. No failed or unperformed Dev test is delegated to UAT.

## Historical baseline for the orphan cleanup increment

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

The owner approved public publication. Lambda PR73 is merged into remote
`release-V01` at `3d1a2a225422556631b18636eee10a3eba47d645`, containing reviewed
head `a1be075f4112560dfee4a2ad73122203b2365fc9`. Infrastructure PR101 is merged
at `a96ee0708ac11e861624882546e907677de4156c`, containing reviewed head
`01c83923f80eb2f7f3749ca11a05da553a0e615e`. Both ancestry checks passed after
fetching the remote release. This increment is integrated; SECUR4ALL-207 remains
In Progress for the other Dev requirements above. Existing contribution expiry can extend later than the
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
Any unfinished retained Dev criteria stay in SECUR4ALL-207. Done requires reviewed
implementation, required component/Dev acceptance, runbook, pushed commits and
verified integration into remote `release-V01`, followed by tracker evidence.


## Composed withdrawal acceptance — September 27 UTC

Frozen Lambda commit `9bf336d3a39861925d5a7578e3a6de65bf3c2784` adds only the
isolated fixture, its tests and build/dispatch wiring. Four local SDK/Moto tests
passed and were independently rerun. All 103 packaged Python members matched
frozen Git bytes and compiled. The separately packaged four production archives
were unchanged by this fixture increment.

The actual Python 3.14 ARM64 fixture ran all three cases successfully using real
DynamoDB transactions:

- [Withdrawal through durable recovery, withdrawn state, audit and COMPLETE](evidence/sec207-withdrawal-2026-09-27/actual_withdrawal_complete_replay.json).
- [Lost producer acknowledgment followed by idempotent recovery](evidence/sec207-withdrawal-2026-09-27/actual_withdrawal_lost_ack.json).
- [Delayed outbox and cluster replay leaves completed withdrawal unchanged](evidence/sec207-withdrawal-2026-09-27/actual_withdrawal_delayed_replay.json).

This is the actual consent producer and cleanup implementation within an isolated
fixture. HTTP authentication, queue/stream transport and candidate discovery are
injected; it is not native SQS dead-letter redrive, current production-role IAM
qualification, or general campaign activation. The [manifest](evidence/sec207-withdrawal-2026-09-27/package-manifest.json)
and [independent verification](evidence/sec207-withdrawal-2026-09-27/package-verification.json)
bind archive SHA256 `d312252a6a1512597a232e505391f04624fefa3f22d9847ccb1dd43a06c51615`.

[Independent cleanup readback](evidence/sec207-withdrawal-2026-09-27/cleanup-readback.json)
confirms the three synthetic tables, test function and role absent. The disposable
HMAC key is PendingDeletion for October 4 UTC, not destroyed. No existing account,
application data, production archive or activation setting changed.

## Historical whole-period infrastructure preparation

The new optional preparation separates `PERIOD_WORK#` and `WORK_LOOKUP#` paired
records from `PERIOD#` security registries and `PERIOD_WORK_CONTROL#` counters.
Runtime cannot write `INVENTORY#` approval markers. Lifecycle progress uses separate
`PERIOD_SWEEP#` and `PERIOD_RETIRED_PREFIX#` partitions. DynamoDB IAM cannot constrain
sort keys or require application conditions; source must condition existing
controls, exact pair identity and every approval/generation guard. Existing broad
target grants remain explicit and are not narrowed by the new work policy.

Managed work policies avoid the aggregate inline policy limit. Read-only plans
render policies of 2,258 characters for ordinary campaign workers, 3,431 for
lifecycle and 2,618 for each API worker, below the account's 6,144-character limit.
Fresh metadata confirms sufficient attachment slots. Exact resource checks reject
an outbox ARN from another account even when consent migration is not selected.

All preparation flags remain false, manifest/TableId pins empty, the five-minute
`reconcile_periods` schedule disabled, and its alarm actions disabled. Preparation
cannot create approval markers or bootstrap controls. New alarms detect missing
heartbeat, failure, unverified work, stalled progress and stale full-pass progress.
The existing privacy-deadline alarm is retained; a successful alarm deployment
alone cannot establish that application metrics are emitted.

The API conversation-analysis role is a deliberately retired writer with an
explicit DynamoDB-write deny. The added Allow does not override it. No current
message-analysis producer has been identified as a caller of the old outbox
producer. Inventory must record this path as disabled; this work does not enable
research ingestion.

Local validation passed 49 campaign-processing Terraform tests and 143 API tests.
After the additional exact-resource fix, all four focused period-work tests passed.
These overlapping counts are not a combined unique-test claim. Plans are read-only;
no new lifecycle infrastructure or code has yet been applied.


## Isolated AWS period-key retirement — September 27 UTC

Frozen Lambda source `e388184e8936da970c05d395353e4d12e8d1a3b9` passed both
[guard/replay](evidence/sec207-period-retirement-2026-09-27/guards-result.json)
and [lost-response recovery](evidence/sec207-period-retirement-2026-09-27/lost-ack-result.json)
cases using local Python 3.14 with actual AWS DynamoDB and KMS. Each used its own
two disposable tables and one HMAC key. Disabled gates and missing proof refused
key mutation; successful retirement disabled the key and scheduled the minimum
seven-day deletion window. GenerateMac was rejected after disable and scheduling.
Reconciliation after two injected lost acknowledgments and later replay left the
completed result unchanged.

The fixture creates a synthetic sealing proof; it does not establish live Dev
inventory, deployed Lambda behavior, application-role permissions or permission
to retire existing application keys. Independent source review passed 70 selected
SDK tests. The infrastructure runner's seven tests include preservation of the
ownership journal when replacement fails.

[Guard cleanup](evidence/sec207-period-retirement-2026-09-27/guards-cleanup.json)
and [lost-response cleanup](evidence/sec207-period-retirement-2026-09-27/lost-ack-cleanup.json)
confirm all four disposable tables absent and both keys PendingDeletion for
October 4 UTC. PendingDeletion is not evidence of completed key destruction.

Current full Terraform validation passed 56 campaign-processing tests and 146 API
tests. These supersede the earlier overlapping counts. Application preparation
and activation remain unapplied pending all-writer, resource and IAM qualification.


## Composed indexed lifecycle — September 27 UTC

Exact reviewed Lambda `9147d545b719e54c1f967e35042bc502d79bc0f1` passed three
actual AWS DynamoDB/KMS cases under local Python 3.14:
[complete/replay](evidence/sec207-period-lifecycle-2026-09-27/complete-result.json),
[poison recovery](evidence/sec207-period-lifecycle-2026-09-27/poison-result.json),
and [committed delete with lost acknowledgment](evidence/sec207-period-lifecycle-2026-09-27/lost-ack-result.json).
Each used five owned tables, six actual producer events and 42 indexed targets.
Three early-deadline ticks and four/five drain ticks produced real SEALED evidence;
later account and withdrawal completion made no KMS call, and replay was unchanged.
The poisoned record prevented sealing until explicitly repaired within the fixture.
A seeded anonymous expired aggregate was removed while a future aggregate remained.

Clocks, inventory approvals and command inputs are synthetic; SQS/CloudWatch
transports are captured. These runs do not prove threshold publication, native TTL
timing, deployed role authorization, all aggregate discovery, provider key
destruction or application activation. Publication's 110-contributor and late
tombstone race are separate SDK/Moto evidence. Actual disposable key retirement
is separately qualified above. All fifteen test tables are absent; the three
fixture keys are PendingDeletion for October 4 UTC, not destroyed.

The eight Python 3.14/ARM64 [packages](evidence/sec207-period-lifecycle-2026-09-27/manifest.json)
were [independently verified](evidence/sec207-period-lifecycle-2026-09-27/independent-verification.json):
283 Git-backed Python members plus one exact generated export wrapper, all Python
members compiled, two export native libraries verified ELF64/AArch64. This is
static package verification, not Lambda runtime acceptance. The legacy analysis
writer remains disabled by its existing DynamoDB deny; building its future
compatible archive does not authorize reactivation.


## Computed seal through retirement and later cleanup

The fixture-only Lambda revision `81ae81a152eef30a903e23eff4d12da75b780c08`
adds the missing end-to-end component composition without changing production
source `9147d545`. The actual AWS
[retire-then-complete result](evidence/sec207-period-lifecycle-2026-09-27/retire-then-complete-result.json)
computes the seal through indexed drain, disables and schedules its dedicated
owned key for seven days, verifies rejected MAC use and unchanged retirement
replay, then completes both account deletion and withdrawal without KMS. Delayed
replay is unchanged. The retirement step uses actual provider wall time; other
fixture clocks, inventory and transport are synthetic.

[Independent cleanup](evidence/sec207-period-lifecycle-2026-09-27/retire-then-complete-independent-cleanup.json)
confirms the five disposable tables absent and the key PendingDeletion for
October 4 UTC. It does not claim key destruction or retirement of application keys.
Fourteen local fixture SDK tests passed normally, under Python optimization, and
in independent review.

## Dev installation, bootstrap and runtime — September 27 UTC

Seven production packages from `9147d545` were installed under a verified paused
writer boundary. The legacy conversation-analysis package and explicit write deny
were preserved. The intelligence ExpirationIndex was added in place with KEYS_ONLY
projection. Source/version/hash pins are in the
[private artifact publication record](evidence/sec207-period-dev-deployment-2026-09-27/private-artifact-publication.json).
Private artifact publication is separate from public GitHub publication.

The external reviewed manifest binds the exact source, eight functions and role
policies, three actual table identities, fixed generation and original rows.
Its work inventory SHA256 is
`31695c1ad9ac9d0b9382cbfd9a50dc535dcb1b03f2dbe7ad64fc612484790ef0`.
The single 16-action conditional bootstrap was acknowledged and
[independently matched to the expected entire bounded snapshot](evidence/sec207-period-dev-deployment-2026-09-27/independent-bootstrap-readback.json).
An additional [operator readback](evidence/sec207-period-dev-deployment-2026-09-27/independent-operator-readback.json)
confirmed the original tombstones, deadlines, inventory minimums and old retired
registry were preserved. This is not an atomic whole-table-snapshot or historical
copy-absence claim.

The [109-case actual IAM qualification](evidence/sec207-period-iam-2026-09-27/qualification.json)
used fresh assumed roles and dedicated tables; the final run passed and its
fixtures were removed. It covers work/control/cursor projections, not every KMS,
SCP, or intelligence-index behavior. Actual installed scheduled index queries and
cursor progress provide the separate runtime evidence. Earlier failed qualification
attempts remain documented rather than being rewritten as passes.

After restoration, all eight exact function configurations matched their reviewed
plans. Identity-free actual handler smokes returned 401 UNAUTHORIZED for account
deletion and the expected 503 SERVICE_NOT_ENABLED for disabled account export.
They do not prove an authenticated modern locator export or a new customer deletion.
The original SECUR4ALL-200 HTTP subject scope and inventories were retained.

Both genuine five-minute schedules reported heartbeat and zero failures without
root invoking lifecycle manually. Initial observations show period full-pass
progress, future-only backlog of three, no due work or deletions, and unchanged
original data hashes and enabled keys. The first incomplete aggregate pass raised
the expected freshness alarm. CloudWatch recorded a successful action to SNS;
topic-level delivery was observed, but individual support inbox receipt was not
verified. Completion of all sixteen aggregate shards and subsequent alarm recovery
remain pending until the final readback is appended here.

Final local validation passed 58 processing, 148 API, 5 campaign-data and 3
campaign-API Terraform tests, plus 95 infrastructure helper tests. These are local
mocked/unit results, distinct from actual AWS qualification and scheduled execution.
The final configuration is persisted under `environments/dev`. All four final
[read-only plans show no changes](evidence/sec207-period-dev-deployment-2026-09-27/final-no-drift.json).
The guarded retirement flag is enabled under the original future deadlines; all
[eight final configurations match](evidence/sec207-period-dev-deployment-2026-09-27/final-runtime-config.json).
Public release integration is still required before marking Done.

Later assembled release qualification remains open in SECUR4ALL-330 using
[the release guide](SECUR4ALL-207-RELEASE-TESTS.md). Android physical testing stays
in ATCR-148 and does not block this backend story.


Four separately recorded, bounded
[explicit aggregate continuation calls](evidence/sec207-period-dev-deployment-2026-09-27/explicit-aggregate-continuation.json)
completed the first sixteen-shard pass after four genuine scheduled ticks. Each
call used the unchanged handler event and rechecked exact revision/source/environment,
three table identities, empty intelligence/outbox, the full stable non-progress
pipeline hash and future enabled keys. Only the aggregate cursor changed; no target
was deleted. All calls returned heartbeat1 and zero failure/deletion/unverified/
overdue counters. The [reviewed runner](evidence/sec207-period-dev-deployment-2026-09-27/explicit-aggregate-continuation-runner.py)
durably journaled every intent, disabled Invoke retries and stopped immediately
when a positive completed-pass timestamp was observed. This does not claim eight
naturally scheduled ticks. The next genuine scheduled continuation and natural
alarm recovery remain separately observable completion requirements.
