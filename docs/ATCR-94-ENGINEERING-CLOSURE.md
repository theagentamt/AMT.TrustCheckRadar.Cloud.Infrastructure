# Android account controls: retained Dev acceptance

ATCR-94 covers account export and deletion, History deletion/clear, and badge reset.
The owner assigned later manual execution to the QA team in
[ATCR-62](https://andmorethings.youtrack.cloud/issue/ATCR-62). This record separates
that work from implementation defects and automated Dev checks. It does not enable
ordinary application access or declare release readiness.

## Acceptance mapping

| Criterion | Engineering evidence and boundary |
| --- | --- |
| Authenticated, independent transports | Export candidate.3 and account deletion have typed transports. History reads, delete-one, clear and badge reset use their own contracted transport. Unconfigured services return unavailable, not a fabricated network failure. The September 13 audit describing all operations as unbound is historical. |
| Confirmation, recovery and truthful completion | Android PR41 covers durable account-deletion intent and cleanup recovery; PR42/43 cover bounded export and explicit retry. ATCR-86/87 cover History mutation journals, same-operation recovery, uncertain outcomes and generation fences. Acceptance of account deletion permits approved local cleanup; it is not a claim that all remote records have already been erased. |
| Local account cleanup | PR41 covers owned Room/encrypted stores, interrupted cleanup, late writers and session isolation. The new connected emulator case proves the actual typed request invokes the real cleaner and matching-session sign-out: the owned draft is removed, a different owner's draft survives, and the durable cleanup journal retires. It does not repopulate every local store; reuse PR41 for that matrix. |
| History and badge independence | ATCR-86/87 provide existing component/native tests for independent stores and generations. The new correction reads the existing registration store's fingerprint, never creates another identity, and fences binding/account changes before dispatch and after response. The composed native transport regression covers reads and all three mutations. Actual nonempty live-service qualification remains explicitly open in ATCR-106/107 and their detailed plans. |
| Subscription explanation and navigation | The deletion screen retains its English/Spanish non-cancellation disclosure and now opens Google Play subscription management separately. Tests cover the fixed URI, session guard, failure explanation and no deletion dispatch. This is not a purchase, cancellation or verified store transaction. |
| Backend erasure and isolation | SECUR4ALL-200/207/236 already qualify the backend components, original-operation receipts, identity removal, replay suppression and owned-data handling. Reuse that evidence; do not rerun every backend failure/restore scenario for this Android story. |

## Existing evidence reused

- Android PR41: local cleanup and recovery, source
  `564def60538af1211bb9647433cffc6c794d7294`.
- Android PR42: export candidate.3 compatibility, source
  `c2f53210f9fa0ae299decaf2db149bb571997ab6`.
- Android PR43: actual connected export, source
  `79b77b959384f5747595f01d5752b528765016b9`.
  [The Dev record](ATCR-94-CONNECTED-EXPORT-DEV.md) distinguishes real native/HTTP
  evidence, failed attempts, local tests and restored temporary access.
- [SECUR4ALL-200 Dev acceptance](SECUR4ALL-200-DEV-ACCEPTANCE.md),
  [SECUR4ALL-207 Dev acceptance](SECUR4ALL-207-DEV-ACCEPTANCE.md), and
  [SECUR4ALL-236 Dev acceptance](SECUR4ALL-236-DEV-ACCEPTANCE.md).
- Android `docs/atcr-86-history-deletion-integration.md` and
  `docs/atcr-87-badge-reset-recovery.md`: completed implementation and explicit
  deferred live/manual matrices. They must not be reported as live-service passes.

## Connected deletion evidence

The passing emulator case took 8.622 seconds. It used real Amplify authentication,
the real typed Dev deletion transport, the actual Hilt singleton journal and local
cleaner, and the full application composable. It cancelled once without dispatch,
then submitted one request. The strict report records one POST, one status GET and
one local-cleanup invocation. It verified native sign-out, an empty owned draft,
preserved other-owner draft, retired journal, and local denial without another HTTP
request after sign-out. See [the native report](evidence/android-account-controls-dev-2026-09-27/native-success.json).

The test uses a ComponentActivity composition with a DevDebug-only Hilt entry
point. It is not a MainActivity lifecycle instrumentation pass. MainActivity's
normal cold launch succeeded in 1,065 milliseconds. An ActivityScenario launch
timeout reproduced in the existing MainActivity test before test bodies and
credentials; the connected proof does not conceal or claim that instrumented
startup case as passing.

The first actual attempt stopped during Cancel after one GET and zero POSTs.
The runner had waited for request dispatch rather than completed status. A delayed
response regression reproduced the disabled-control race; the correction waits
for the actual NotRequested state. Native and strongly consistent backend checks
proved no operation/observer, cleared session, original active adult identity,
and no device rows. A separately reviewed, one-attempt password renewal created
fresh one-use credentials for the same account. No age request, registration,
account creation or deletion request was replayed. The failed attempt remains
[recorded](evidence/android-account-controls-dev-2026-09-27/native-attempt1-failed.json)
alongside [server reconciliation](evidence/android-account-controls-dev-2026-09-27/native-attempt1-server-reconciliation.json).

Automatic approval review initially prevented execution; the owner then explicitly
approved deletion of the named disposable Dev account. No existing customer
account, subscription, paid provider call or physical device was used. Credentials
passed through stdin into private no-backup storage and were consumed. Before the
single POST, the app synced its original operation record and directory; root
copied that private record through an independently reviewed, owner-bound helper.
Only counts, statuses, hashes and configuration evidence are retained publicly.

## Infrastructure and asynchronous cleanup

The reviewed Terraform plans added only this fresh subject to the three existing
Dev deletion allowlists, preserving the original entries. The two worker aliases
followed new configuration versions; package bytes, roles, IAM, routes and other
settings were unchanged. Export and History admission remained closed. Installed
environment/artifact equality and GET/POST JWT issuer, audience, scope and exact
integration were read back before execution. See [scope verification](evidence/android-account-controls-dev-2026-09-27/scope-activation.json).

The separate read-only observer pins the original setup and native operation,
applies production command/receipt validation, and checks final identity, profile
and device absence. The first observer retained nine valid receipts and then
ended with an unclassified observation error. Its cause was not established, and
that report is not a completion claim. A read-only diagnostic subsequently verified
the terminal command and twelve receipts; the unchanged observer then passed all
checks in a new report. The same original operation was COMPLETE with twelve valid
receipts, profile absence, an empty device partition, actual Cognito UserNotFound,
and unchanged runtime pins. See [final backend proof](evidence/android-account-controls-dev-2026-09-27/backend-complete.json)
and the preserved [initial observation error](evidence/android-account-controls-dev-2026-09-27/initial-observer-error.json).
No deletion retry, direct worker invocation, fabricated receipt or manual identity
removal occurred. Scheduled cleanup completed through its normal batch sequence.

Backend setup, observation and credential renewal were supervised operator helpers,
not a new unattended fixture-provisioning product. Future execution requires a
fresh reviewed fixture/configuration and engineering-owned observer. Do not reuse
these consumed credentials, disposed identity, operation or private plans. The
published Android runbook supplies the actual native runner and protected input
channel; its evidence distinguishes the real Dev case from synthetic coverage.

After completion, the independently reviewed restoration plans returned all three
cleanup allowlists to their exact original entries. Installed environments,
artifact hashes and roles matched the original baseline; export stayed disabled
with no export route. Final detailed-exit-code Terraform plans returned zero and
no changes for API, URL consumer and Play lifecycle. See
[restoration](evidence/android-account-controls-dev-2026-09-27/final-restoration.json)
and [no drift](evidence/android-account-controls-dev-2026-09-27/final-no-drift.json).
Android removed private test files and its dedicated emulator after root secured
the original operation record. No personal emulator or physical device was touched.

## Validation and integration status

The required Android quality gate passed 455 tasks with all three host suites
actually executed: 917 Dev, 844 UAT and 844 Production tests, zero failures/errors/
skips (2,605 total). The focused emulator suite passed 28 cases plus one explicit
connected opt-out skip; separate navigation and delayed-status regressions passed.
The connected pass is separate from these synthetic tests. The shared input
channel and deletion-specific helper have eight passing tests. The read-only
observer passed 18 tests normally and with optimized Python; the supervised
renewal helper passed 28 in both modes and independent review.

Android [PR44](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/44)
is merged into release-V01. Independently reviewed source
`ee7a29af6f02b2a612c0ac4563f1b4fbc3c058a0` is an ancestor of verified remote release
`f2a39196e5630a9879142e8dfc625d25d32eb727`; main remains
`2846e45811826852ed491b90e51d275294d0f1af`. The worktree is clean.
The Android runbook and manifest are
`docs/v1/android-account-privacy-engineering-closure.md` and
`docs/v1/android-account-privacy-engineering-validation.json` at that source.

Retained Dev acceptance is satisfied. The source story records final publication
and remote release verification for this evidence commit before its Done transition.
There is no new Lambda implementation or package in this increment; the existing
qualified backend artifacts were reused. General activation remains separate.

## QA and release handoff

ATCR-62 remains open in Android V1-5 - Release qualification. The QA team owns manual
UI observations, English/Spanish, human accessibility, interruptions and assembled
account-isolation cases using an engineering-supplied ready build and scoped
environment. Detailed History/badge coverage stays in ATCR-102/104/106/107.
Physical-only work stays deferred in ATCR-148. Backend release export qualification
remains SECUR4ALL-331; backend account-deletion release work remains SECUR4ALL-329.

QA must not edit runtime flags, IAM, retention or data tables to make a test run.
Engineering owns deployment readiness, disposable fixtures, automated checks and
cleanup. Unperformed manual/release cases remain pending. General activation,
UAT/Production, paid provider calls, native backup requalification and main-branch
promotion are outside this Dev closure.
