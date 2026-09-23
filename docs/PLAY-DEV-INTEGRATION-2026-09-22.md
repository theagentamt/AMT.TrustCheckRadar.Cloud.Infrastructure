# Closed Dev Google Play integration

Scope: SECUR4ALL-244/195, Android ATCR-91/111; lifecycle SECUR4ALL-125 remains separate.

The owner authorized coordinated Dev implementation/deployment. The new modern
purchase endpoint uses existing Cognito authentication and only a published live
alias, with a separate API-stage burst 4/rate 2 throttle. Native Lambda errors and
throttles target the existing support@andmorethings.com SNS subscription. No token
or request body is added to access logs. All authority/purchase gates remain false,
allowlist empty, and cleanup schedules/stream disabled. No store purchase is made
by this infrastructure change.

Seven ordinary authority writers exclude the V1#CONTROL inventory partition.
Recovery uses dedicated V1#CHECKPOINT transactional Update permission, matching
Lambda PR39. Existing old cursor rows were observed; the new worker starts a
bounded traversal from the beginning without touching old rows. Per-row CAS and
idempotence remain. This is not a cleanup full-pass qualification. Deletion-ledger
checkpoint writes are separate, Update-only, with an exact progress-field list;
its inventory records cannot be modified.

Android PR37 supplies the owner-confirmed tester prerequisites and a pending test
matrix. No canonical-package install, shared gate activation or purchase is
claimed. The exact Dev account must be privately selected before its subject is
allowlisted; the canonical installation must register its own device binding.

Deployment evidence and exact validation counts are appended after plan review
and execution. Source integration, deployment, activation, and live acceptance
are distinct. Neither story is Done merely because a closed Lambda is installed.

## Reviewed source and validation

- Android PR37 merged `01dcf01322e4794b801beb86db613a2d1549636f`.
- Lambda PR39 merged `9f2f8da8bc6d706e28d162c0f7e1f950a0618146`;
  immutable artifact source `28b4da19f321e6dc98ce2fc8b4e71632451b4362`.
- Nine immutable archives were published and verified by exact-version download;
  this deployment installs five: verifier plus existing URL consumer, lease
  recovery, entitlements, and authority deletion. Modern export, message,
  recovery-consumer and feedback roots are not installed by this increment.
- Local Terraform validate and 151 mock cases passed across seven affected roots;
  62 script tests, formatting and whitespace checks passed.
- Saved plans: API 1 stage update; resolver 1 SNS-policy update; URL consumer
  4 policy + 4 function + 4 alias updates; verifier 12 creations. No deletions.
  Hashes and resource addresses are recorded in
  [plan evidence](evidence/play-dev-plan-review-2026-09-22.json).
- Artifact pins and dependency metadata are in
  [publication evidence](evidence/play-dev-artifacts-2026-09-22.json).

Disabled AWS handler smoke tests verify loading and closed responses only. The
Google provider dependencies load lazily, so closed smoke does not prove a live
Google purchase request or native cryptographic dependency execution.

AWS custom-policy simulation passed 25 positive/negative cases for the four
resolved worker policies: account transactions and cursor updates allowed;
inventory mutation, direct writes, and invalid checkpoint fields denied.
[Simulation evidence](evidence/play-dev-iam-simulation-2026-09-22.json) is not a
live DynamoDB transaction test. Verifier policy gets a separate post-install
simulation once the new log ARN is resolved.

## Actual Dev deployment and bounded verification

Infrastructure PR49 merged `87a1184edd8552c04cfeabfb7408f125274b9191`.
The initial stage throttle apply failed with AWS 404 because the route did not yet
exist. No stage change was applied. The exact reviewed resolver, accounting and
verifier plans then succeeded. A freshly reviewed stage-only plan applied the
throttle after the closed route existed. Future runs must use that dependency
order; the new route briefly inherited the API default while all runtime gates
remained closed.

[Live evidence](evidence/play-dev-deployed-2026-09-22.json) records five exact
artifact hashes, Python 3.14 ARM64 aliases, empty-event disabled responses,
access-token JWT routing, unauthenticated HTTP 401, burst 4/rate 2 throttle,
closed schedules/stream, two configured support alarms, and five additional
positive/negative verifier IAM simulation cases. These are closed-runtime tests;
no real purchase, account grant, acknowledgment or provider dependency execution
was performed. Alarm delivery/transition has not been exercised by this increment.

SECUR4ALL-244/195 and ATCR-91/111 remain In Progress: authenticated test-subject and
canonical-device qualification, coordinated cleanup/inventory readiness, and the
actual license-test purchase/restore/retry matrix are still pending. Background
renewal/refund/grace/revocation remains SECUR4ALL-125. Its newly approved source
work is separate and not included in deployed artifact source `28b4da19`.

All four post-deployment Terraform plans returned detailed exit code 0 (no drift).
[Drift evidence](evidence/play-dev-no-drift-2026-09-22.json). Live versions are
verifier 1, URL consumer 6, lease recovery 6, entitlements 6, authority deletion 5.
