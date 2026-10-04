# SEC340 scoped Dev governed History qualification

**Status: normal Android English/Spanish Dev phases passed; story In Progress.**
Backend, reader/cache and the completed explanation → History → real restart →
direct reopen phases passed. Exactly two normal-app checks completed and charged
once each; reads/reopen caused no additional evaluation or charge. Current trial
limit/used/reserved/remaining is 10/5/0/5. Failed harness attempts remain below;
qualification spans reviewed windows and is not one clean four-phase run. Final
source integration and approved Dev rollback (or an explicit owner scope change)
remain pending.

This increment qualifies candidate.3 rules-only message processing and candidate.1
governed History for one existing dedicated reusable synthetic Dev account.
UAT/Production, physical hardware, paid store transactions, AI and Google/provider
execution are outside this test window. The account and original trial clock are
preserved. Typed receipts keep their original settlement + 604800-second deadline;
the authority table currently has `expiresAt` TTL enabled and its disclosed
35-day PITR window. No original messages, URLs, images, proofs or identity values
belong in this evidence package.

## Qualified runtime and deployment

- Infrastructure main: `990e66e8c0b8a9dcc2dcb114745b015655f4e43f`, main CI
  [37144270354](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/37144270354).
- Lambda main: `6d9ae503b7d4e36a16a4cfc6bee2c939b988c723`, main CI
  [37142525442](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/actions/runs/37142525442),
  immutable publication
  [37142703658](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/actions/runs/37142703658).
- Dev CI/CD applies: index `37141414785`, access-only `37142537394`, inactive
  reader `37143161640`, rules-only message/History `37143163547`, and one-account
  list/detail reader `37146970010`. All passed exact-plan guards, configuration
  readback and zero drift. Reader `live` version 2 has no weighted routing.
- Exact S3 versions/checksums were independently read back. The URL-consumer ZIP
  was published as part of the four-package publication but was not installed or
  enabled by this increment. Provider gates remain blocked and the evaluator
  denies URL-assessment invocation/provider-secret access.

## Passed backend behavior

`backend.json` contains aggregate-only evidence. English and Spanish each ran once
through the corrected dedicated-reusable runner: 38 HTTP requests, four settled
History results (two complete/charged once and two inconclusive/uncharged).
Prepare/submit replay, same-proof reconciliation, stable full result sets, fresh
client list/direct reopen, immutable original accounting and fixed result deadlines
passed. The trial moved exactly from used/reserved/remaining 1/0/9 to 3/0/7.
No trial activation/reset, account creation/deletion or paid/complimentary grant
was requested. Exact post-run authority reads confirmed eligibility/history and
counters; no scans or writes were performed by those audits.

Exact filtered CloudWatch log-window counts were consumer 16, evaluator 4, reader
18, access 4 and URL assessment 0, with zero fixture, credential-field or
operation-proof sentinel matches. Separately, CloudWatch Errors and Throttles
metrics reported zero. These establish four
original evaluator dispatches; retries/reconciliation/reopen did not redispatch
or consume additional checks. No AI or external reputation call occurred.
CloudWatch's minute metric buckets were incomplete at the initial readback and
are not presented as exact invocation proof; timestamp-filtered logs are primary.

A separate seven-request read-only edge pass verified limit-one pagination and
distinct cursor pages; malformed/tampered cursors returned 422, missing
Authorization 401, wrong owned-device fingerprint 403, and a valid-format missing
owned result 404. It performed no other-account lookup or mutation. Counters
remained 3/0/7. An independent 23-runtime metadata comparison for the message apply preserved
all 21 sampled unrelated Dev configurations; only the two intended message
runtimes changed from the pre-message baseline. The separately provisioned and
activated reader was verified through its own CI/CD readback.

## Passed Android reader/cache component qualification

`android-reader.json` records the two bounded live Dev attempts on API35.
The first attempt made exactly seven GETs: two decoded pages, four decoded
details and the decoded retry response before its cursor assertion. It
validated all four strict result/detail records, then stopped before cache write because the test incorrectly required
opaque cursor byte stability. Failure cleanup removed private inputs and test
storage. This is retained as a failed test attempt, not a backend defect or pass.

The reviewed correction requires stable records/order/generations and monotonic
server time while permitting a fresh bounded opaque cursor. Its 311-task local
gate and independent review passed. Published commit
`42a6a566f82995ae1f4e95ae17088a286cf95791` has exactly the reviewed
`5a018a568e79b3e56fdbfe9320668129c1c0aeb1` source tree. Final documentation-only review head
`a225287f6fe3d2c29d2edf041f08a23da422a5fc` was integrated through Android PR67
into `release-V01` at `fffe7a0edce4ae66954a35ebadd0ba085dea1274`.
No Android main/CI change occurred.

The second attempt passed two pages, four details and one retry within seven
GETs. A separate, credential-free instrumentation process reopened all four
records from the product AndroidKeystore-encrypted Room cache; PID inequality
verified separate processes, with no PID retained in evidence. Device test input,
DB, key, marker and report plus host input were removed. Both attempts totaled 14 GETs and made no
submission or account/device mutation; a fresh exact authority audit still
reported used/reserved/remaining 3/0/7.

This proves the production reader/strict decoder/cache components. It does not
prove the normal signed-in UI, Amplify authentication and device-store journey.

## Chronological Android setup, failures and subsequent qualification

At the start of this chronology, normal message-to-History submission, restart
and reopen were pending. The
owner approved real UI sign-in and one actual device-registration dispatch using
the retained emulator's existing native binding. The account, app data and
original trial are preserved; setup submits no analysis.

The reviewed normal-app runner is published in Android
[PR68](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/68), targeting
`release-V01`. At that stage it remained unmerged while live qualification was incomplete;
its normal Dev phases have since passed, and final source integration is pending.
The following attempts are failures or diagnostics, not acceptance passes:

- The first setup stopped at `PRE_ON_CREATE`, before input consumption or any
  authentication/registration. The corrected launch-intent handling preserves
  only MAIN/LAUNCHER identity while removing incoming payloads. Three focused
  API35 launch/share/privacy checks and a serialized 491-task all-variant gate
  passed. A preceding parallel build hit a lint/Hilt generated-file race; an
  unchanged whole-class off-screen sign-up checkbox assertion is separate test
  maintenance, not a passed case.
- Two subsequent setup attempts stopped at normal UI sign-in, before device
  activation. Credential fidelity was checked privately against raw Compose
  `InputText`, never transformed password text. Fresh same-account Cognito
  authentication and clock/client-flow diagnostics passed. Android's existing
  revoked refresh session prevented a new sign-in.
- Reviewed runtime correction `e443286703910fcf0be1124cb3427577daa77185`
  performs existing local, non-global sign-out only after the SDK explicitly
  reports an unauthenticated session, then one fresh sign-in. Unavailable
  sessions stop without cleanup; normal restore remains read-only. Focused
  authentication tests, 993 Dev unit tests and the applicable serialized gate
  passed. The next correctly flagged immutable APK attempt passed real UI
  sign-in and expected-account/native-binding checks, then stopped at a test
  message-route selector. Its valid session was retained.
- A mistakenly overwritten, unflagged APK stopped at the build guard before
  private input or authentication. Subsequent runs use hash-verified, immutable
  flagged APK copies, not mutable build outputs.
- Reviewed hash-only authenticated resume at `dd6baaca918c24e5caf7d0ac1799404f3ca206c9`
  passed account/binding/empty-draft checks but stopped before activation because
  the test required a below-viewport control to be displayed before scrolling.
- Reviewed `34b5ed3ca10f362b0c6232fb530edbf505560a41` fixes that test ordering and
  permits cleanup only of its exact synthetic setup draft. Its 109-task flagged
  gate and independent source/artifact reviews passed. The retained valid
  session was resumed; explicit device confirmation was clicked, then setup
  stopped while its stage label remained `switch-response` after about 13 seconds.
  Strict reread of the original marker later confirmed `activationResponseObserved=true`: the SWITCH UI tag had been observed before a subsequent assertion failed.
  The earlier stage-based response-false inference was incorrect. No retry or analysis was
  dispatched. The fuse permits at most one registration; its final cleanup
  resets the local dispatch observation, so the actual server outcome requires
  authoritative readback. The original setup still failed; observation of its SWITCH UI tag is not a pass
  for the subsequent active-access/draft-cleanup assertions.

Repeated nine-item projected consistent-read prechecks before activation found
unchanged pointer/bindings, authority and original trial at used/reserved/remaining
3/0/7. A read-only post-attempt audit confirms a committed switch exactly once: pointer
generation +1, target ACTIVE without expiry and old binding INACTIVE, with exact
authority/trial preservation at 3/0/7. The original Android marker confirms the decoded SWITCH UI response was observed.
The host attempt file incorrectly inferred response-false from the stale stage;
that file is preserved unchanged with a separate correction. The backend audit
did not consume an HTTP response, so its conservative response-outcome field
is distinct from Android UI observation. The committed-state and retention-timing
checks are unaffected by this correction.
The independently reviewed timed-state audit also passed: deactivation occurred
within the preserved 13-second attempt and old-binding expiry is exactly
deactivation + 180 days. Both post-attempt audits made nine projected reads and
no scans/writes. The later normal-app read-only reconciliation passed as
described below; registration will not be repeated. No complete original setup
qualification or normal English/Spanish submission is claimed yet. Reviewed reconciliation head
`1410885259877c960e1ed4a90ea5656455bc6be2` uses dedicated hash-only staging,
preserves the prior switch plan/result/attempt evidence, and arms a zero-registration
fuse. Six host fixture tests, the flagged 109-task gate and independent exact
source/artifact review passed. Its report contains current observations only;
the original failed setup and observed SWITCH UI are separately hash-bound to
source evidence. The first current-only read-only reconciliation at that head failed after 132
seconds at its final home-navigation expectation. Expected session/account/native
binding, active access, absence of activation control and exact synthetic-draft
match passed before normal discard. Product discard intentionally clears capture
state without navigating Home; the harness assumed navigation. No registration,
authentication, reset or analysis was requested. The reviewed correction at `10118fab45ea0dee272ec05fd3c28d54b4a6f0e9`
verified empty raw input and used the normal Back action before awaiting Home.
The first attempt remains failed with partial observations. The corrected
read-only reconciliation passed in 11.435 seconds: expected account/native
binding, active access, no activation control, exact owned draft cleanup, zero
registration and zero analysis. Its report describes current-run observations
only. The normal harness correction at `1135da5213301857aa8b834fcad1f8fbc7a9cfd7`
respects History virtualization and waits for Current refresh completion. Its
flagged 109-task gate and independent exact source/APK review passed. The first
English window stopped after 4.095 seconds at baseline History navigation, before
submission; Spanish was not started. Exact-window readback found zero consumer,
evaluator, History, access and URL invocations, zero sensitive/proof matches and
zero Errors/Throttles. The success expectation was retained and correctly failed;
it was not changed to make this aborted run pass. A four-item consistent-read
audit confirmed the original trial/authority remains 3/0/7. The independent source and actual immutable APK review passed for navigation
correction `a4705f0549bfecd446b998c38bef8720b8be9f48`, with a flagged 109-task
local gate. Its unique displayed selectable drawer node excludes the duplicate
Home shortcut; closed substages and failure categories reveal no private content.
Its new bounded English attempt failed at `message-review-input` with the
closed category `ASSERTION`, before submit; Spanish was not started. Exact
readback found one baseline History invocation and one access invocation, zero
consumer/evaluator/URL invocations, zero sensitive/proof matches and zero
Errors/Throttles. The original success expectation correctly failed; a fresh
four-item authority audit remained 10/3/0/7. A no-network API35 rehearsal passed at candidate
`ed6bab1a4f6af1f95b8c1b945f3e55bf7ca0748e` in 3.283 seconds: governed
Message services fake, History-to-Home composition, unique empty raw input,
prepare-review, disabled submit until speaker choice, enabled submit without
clicking, and exact-owned draft discard. Its flagged 109-task gate passed;
final independent source/immutable APK review passed at docs-only descendant
`c347fb58bc7cb593194b8091fae97821e5d7ebfb` before another normal window.
At the inspection stage, current-account read-only classification passed as
described below; cleanup of the later failed-run draft was still pending. The first inspection candidate was rejected before live execution because opening a new
editor would not resolve a pending stored-draft Restore dialog. The replacement
uses a test-only read of the current-account encrypted record without store
pruning or mutation. Only a safe, unexpired, screenshot-free record may enter
normal Restore; unsafe metadata or absent Restore UI stops untouched. A missing
record establishes persisted absence directly, rather than inferring absence
from a newly reset editor. Stored bytes must remain unchanged across inspection. Replacement source
`2936f6ab75fa489482965a56630ca477c852dbe8` passed host fixture 7/7,
metadata/preservation 3/3, normal Restore UI 1/1 and absent-draft UI 1/1,
the flagged 109-task gate, and independent source plus actual immutable APK
review. Its app APK is byte-identical to the previously reviewed runtime.
The first invocation was skipped before execution because required runner
arguments were absent. After exact source/DEX command validation, one real
inspection executed from 00:36:43 to 00:36:45 UTC on October 4: `EMPTY`, grounded
in current-account persisted-record absence before/after. Expected account/native
binding and unchanged sealed state passed, without Restore, cleanup, registration
or analysis. Root independently validated the strict consumed report. Exact-window
operational counts were all zero, with no sensitive/proof matches or Errors/Throttles;
the original normal success expectation correctly remained false/not applicable.
Four projected authority reads preserved 10/3/0/7. This qualifies current-account
inspection only, not blanket preservation or the normal analysis journey. A later normal English invocation executed one test but stopped at
`preconditions` before authority consumption or submission because its earlier
test failure marker still existed. Fixed-name inventory confirmed restart and
success files absent. The new marker remains source-exact in a separate host
copy; an initial canonical host copy had only added a trailing newline and is
retained separately, without claiming byte equivalence. Root validated the
source-exact marker before allowing removal of only that matching app test
artifact. The account draft/domain data were untouched. A fresh four-item
authority audit preserved 10/3/0/7. This stopped attempt omitted actual window
recording, so operational logs are NOT_RUN and no invocation counts are claimed.
Complete phase preflight and timestamp recording are required before a new GO. Earlier invalid fake-access and rehearsal-selector failures were
local test-fixture failures, with no backend calls. More specific closed input
stages preserve the historical failure cause as unknown. Neither of those first two normal attempts had submitted a logical check. The assembled journey is
retained Dev acceptance; mocks and the separate reader/cache component run do
not substitute for it.

The scoped gates are currently enabled for this dedicated account only. All
three inactive rollback plans are prepared at the reviewed infrastructure revision;
owner approval and actual apply/readback remain pending. Do not claim rollback,
empty admission lists, removed temporary selection or SEC340 completion until
those actions are performed or the owner explicitly changes the retained scope.

Cross-account lookup, waiting 15 minutes for
cursor expiry and waiting seven days for physical TTL removal were not executed
live. Approved local contract/SDK fixtures cover cross-account/device-generation
isolation, cursor tamper/binding and logical result expiry/deletion suppression.
Cursor expiry is source-enforced, but no explicit 900-second expiry regression
or live expiry wait is claimed in this evidence. Later assembled release/provider/UAT work
remains in SECUR4ALL-334, ATCR-62/108; physical cases remain ATCR-148.

A subsequent fully preflighted normal attempt had a root-recorded start before
execution and a finalized actual end. English executed one test and stopped at
`message-review-dispatch` / `ASSERTION`, after entering its owned synthetic draft.
That stage combined scroll/enabled assertion/click; its `submissionClicked=false`
marker alone did not prove backend absence. Exact timestamp-filtered readback
subsequently confirmed consumer/evaluator/URL 0, baseline History 1 and access 1,
no sensitive/proof matches and Errors/Throttles 0. Four projected authority reads
again preserved 10/3/0/7. No check reached the consumer; Spanish/reopen were not
started. The exact UI sub-operation remains unproven. Test-only closed substages,
a delayed-access/no-network click rehearsal, bounded enabled-state synchronization
and separately reviewed cleanup of only that unsubmitted synthetic draft were
then prepared. Root subsequently preserved the actual app failure marker and independently
verified it byte-identical to the retained host copy; no newline discrepancy
exists for this dispatch-stop marker. No runtime API or policy change is inferred
from this failure.

The reviewed test-only correction at `61bdc981d1677f3a5cb51e6948d3a09498131262`
passed its 109-task flagged gate, nine host tests and independent source/actual
APK review. Delayed access is rehearsed with an enabled speaker selection and
exactly one local fake submit. The actual application APK remains unchanged.
An initial cleanup staging attempt stopped before authorization write because
the host audit fixture placed three authority flags at the wrong level. The
host-only correction `6ea0efd0d3771a6bda3927e666821101c312fd3e` passed nine host
tests, independent review and validation against the actual preserved audit.
No APK rebuild was necessary for that host-only change. Original failed-run
source/APK pins, raw and canonical marker hashes, original account/native hashes,
strict exclusive saved-time bounds and cleanup-executor pins remain separate.
At that stage, live cleanup and the bounded normal journey were still pending.

One reviewed cleanup invocation executed and failed closed at
`snapshot-exact-owned-draft`, before Activity launch, Restore or Discard. It was
not retried. Subsequent independent direct file-existence observations established
current-account persisted-draft absence; cleanup is therefore unnecessary. This
does not turn the failed invocation into cleanup success or establish why the
earlier entered text was not persisted. Exact-window operational readback confirmed all function and application counts
zero, zero Errors/Throttles and sensitive/proof/provider matches. Four projected
authority reads preserved 10/3/0/7. The original normal success expectation
correctly remained false/not applicable. Only byte-matched preserved test failure
markers may be removed before fresh normal input staging; domain data are unchanged.

The subsequent bounded normal window admitted its first real English check.
Submission executed one test and passed completed explanation plus History
persistence. The app was force-stopped and restarted; one English reopen test
then failed at `direct-detail`. Spanish was not started and the completed English
message was not resubmitted. Exact-window counts were consumer 2, evaluator 1,
reader 4, access 4 and URL 0, with zero Errors/Throttles and sensitive/proof/provider
matches. Four projected authority reads confirmed 10/4/0/6. The immutable full
normal expectation correctly remained false. Source inspection found that the
first detail wait expected a legacy-only heading; governed History renders a
different title. A test-only correction was then reviewed to reopen the same completed
result without another analysis charge.

The reviewed governed-title correction `467399b582f7ba5159b8087c3f66f641f648fd4f`
passed a real-screen local rehearsal, its 109-task flagged gate and independent
source/actual APK review. A read-only reopen then failed at `preserved-authority`
because the previous failed test had restored the original Device language
preference while this phase required explicit English. It stopped before History;
Spanish and new analysis did not run. Exact-window function/application counts
and error/proof/provider/sensitive metrics were all zero; authority stayed
10/4/0/6. Both original and separately reviewed remaining-phase expectations
correctly remained false. A minimal test-only locale recovery was then reviewed,
with the original completed result and restart marker preserved.

## Release-test operator handoff

Later release/UAT execution stays open in SECUR4ALL-334 and ATCR-62/108;
physical-only cases stay in ATCR-148. These items do not waive unfinished Dev
normal-app acceptance or post-test rollback. Use the Android repository's
`docs/atcr-163-governed-history.md` and the infrastructure
`docs/GOVERNED-HISTORY-DEV.md` at the selected integrated commits.

Before execution, qualify the exact immutable packages, runner, signer, Dev
endpoint, candidate.3 message contract and governed History candidate.1 contract.
Fresh activation requires reviewed CI/CD plans and their exact approvals; do not
reuse this test's digest against a different revision. Preserve the approved
synthetic account, trial clock and native binding. Stage hash-only authority with
`provision-reconcile` when the binding is already active. Do not use the switch
provisioner or generic cleanup helper to reset retained evidence. No registration,
account deletion or provider execution is implied by a History test.

Run the verified `ConnectedGovernedHistoryAppJourneyTest` submit and reopen
methods with every required connected/phase/language/baseline/class argument.
Inspect all fixed test marker names before a new submit; old markers must first
be preserved and matched byte-for-byte. Record a private actual start before GO
and a distinct finalized start/end window on every outcome. Require one executed
test and strict phase evidence, not just an exit code or an assumption skip.
Force-stop the app between submit and reopen and stage fresh hash-only input.
A completed English check in a failed later test is not resubmitted: preserve
its restart marker, correct and review the read-only phase, and reopen that same
result. Verify the requested locale and restore the original preference.

Independently audit exact-window invocations and projected authoritative counters.
Require one evaluator/settlement/History entry/charge per complete new check, zero
new charge on reads, immutable original accounting and result deadline, and no
original content in History. Keep failed-window actuals and success expectations
unchanged; if phases resume in a new window, pin a separate reviewed assessment
and explicitly account for extra read-only GETs. On uncertainty stop and audit
before another phase. Provider sandbox, cross-account live execution, actual
cursor-expiry waits, physical TTL observation and physical accessibility remain
separate pending qualification cases where not already executed.

The final locale correction `9b60308deb1954620a8bc432760b065f697c4296`
passed two focused API35 tests, the serialized 491-task repository gate and
independent source/actual APK review. It reapplies and explicitly verifies the
requested preference before Home/History and restores the original preference
in `finally`; no new runtime or test-host Activity was added. The actual
application APK remained byte-identical. The remaining bounded window completed
all three phases, each executing one test: existing English result read-only
reopen, one Spanish completed submission/History entry, then real force-stop/
restart and Spanish direct reopen. Root independently validated both strict
content-free success reports. English submission belongs to the earlier partial
window; no English resubmission occurred, and this is not presented as one clean
four-phase window. Final independent operational/authority audit passed the separately reviewed
remaining-phase assessment: current consumer 2, evaluator 1, reader 6, access 5
and URL 0. Cumulative normal activity is consumer 4, evaluator 2, reader 10 and
URL 0; the two extra History reads belong to the failed first reopen. All
Errors/Throttles and sensitive/proof/provider matches were zero. Four projected
authority reads confirmed 10/5/0/5, with the original trial/eligibility preserved.
The original full-normal expectation remains byte-unchanged and false for these
partial windows; it is not rewritten as success. The phase-specific assessment
and its exact external hashes were independently reviewed. Final platform
locale readback verified the original Device preference. Only the byte-matched
test reports/inputs were removed; account/domain/native/History/receipts/session
state stayed intact. No rollback or story completion is claimed yet.
