# SEC340 scoped Dev governed History qualification

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
`5a018a568e79b3e56fdbfe9320668129c1c0aeb1` source tree and is in Android PR67,
which targets `release-V01`. No Android main/CI change occurred.

The second attempt passed two pages, four details and one retry within seven
GETs. A separate, credential-free instrumentation process reopened all four
records from the product AndroidKeystore-encrypted Room cache; PID inequality
verified separate processes, with no PID retained in evidence. Device test input,
DB, key, marker and report plus host input were removed. Both attempts totaled 14 GETs and made no
submission or account/device mutation; a fresh exact authority audit still
reported used/reserved/remaining 3/0/7.

This proves the production reader/strict decoder/cache components. It does not
prove the normal signed-in UI, Amplify authentication and device-store journey.

## Still pending

The distinct Android normal-app submission-to-History, restart and reopen
journey is not yet run. Its early upgrade-only emulator preflight stopped before
submission: Amplify is signed out, and the saved local binding does not match the
dedicated fixture. Temporary hash-only inputs/reports were removed; no binding
registration, trial activation, reset or analysis occurred. The safe next setup
action is under read-only review. A fixture binding replacement would require
explicit authorization. This remains retained Dev acceptance. Mock/UI fixture
tests and the connected reader/cache
component run cannot substitute for this assembled journey.

The scoped gates are currently enabled for this dedicated account only. All
three inactive rollback plans are prepared at the reviewed infrastructure revision;
owner approval and actual apply/readback remain pending. Do not claim rollback,
empty admission lists, removed temporary selection or SEC340 completion until
those actions are performed or the owner explicitly changes the retained scope.

Cross-account lookup, actual device-generation rotation, waiting 15 minutes for
cursor expiry and waiting seven days for physical TTL removal were not executed
live. Approved local contract/SDK fixtures cover cross-account/device-generation
isolation, cursor tamper/binding and logical result expiry/deletion suppression.
Cursor expiry is source-enforced, but no explicit 900-second expiry regression
or live expiry wait is claimed in this evidence. Later assembled release/provider/UAT work
remains in SECUR4ALL-334, ATCR-62/108; physical cases remain ATCR-148.
