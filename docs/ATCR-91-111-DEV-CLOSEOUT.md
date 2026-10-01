# Google Play verification Dev closeout

Date: 2026-09-30

Android work: [ATCR-91](https://andmorethings.youtrack.cloud/issue/ATCR-91),
[ATCR-111](https://andmorethings.youtrack.cloud/issue/ATCR-111)

Pending provider qualification: [ATCR-112](https://andmorethings.youtrack.cloud/issue/ATCR-112)

Pending physical-device qualification: [ATCR-148](https://andmorethings.youtrack.cloud/issue/ATCR-148)

## Completion boundary

ATCR-91 and ATCR-111 deliver the Android-to-backend verification implementation
and its closed Dev infrastructure. They do not activate paid access or claim a
Google Play transaction passed. The Android client uses the modern authenticated
`POST /v1/purchases/google-play/verify` contract, accepts access only after the
backend returns a durable grant, and acknowledges through Play only after that
grant. The backend owns package, product, base-plan, account, active-device,
ownership, replay, funded-period and usage validation.

The ordinary app remains closed. A license-test candidate requires an explicit
Android Dev build opt-in, the canonical
`com.andmorethings.trustcheckradar` package and the existing registration setup
opt-in. That purchase opt-in does not enable URL analysis, trial activation or
any UAT/Production service. The backend still requires a separately reviewed,
subject-scoped Dev activation before it can call Google or mutate authority.

## Deployed Dev infrastructure readback

On 2026-09-30, both `play-verification` and `play-lifecycle` Terraform plans
returned **No changes** against AWS account `107827791950` in `us-east-1`.

- `trustcheckradar-dev-v1-play-handoff:live` resolves to immutable version 2,
  Python 3.14 on ARM64, with code SHA-256
  `2sCKdiQE4NaS7cdUeYcWj6TwdtT4CXa6bM8133yb8aw=`. Reserved concurrency is 2.
- `POST /v1/purchases/google-play/verify` and `/prepare` require the JWT scope
  `aws.cognito.signin.user.admin`. API Gateway may invoke only the exact live
  alias, account and route. An unauthenticated verification request returned 401.
- Both routes have detailed metrics, burst 4 and rate 2 throttles. The verifier
  error and throttle alarms were `OK` and target the existing support alert topic.
- Catalog identity is pinned to package `com.andmorethings.trustcheckradar`,
  product `trustcheck_radar_pro_monthly`, base plan `pro-monthly`, period `P1M`.
- Runtime activation remains closed: `PLAY_HANDOFF_ENABLED=false`,
  `PLAY_PREPARATION_ENABLED=false`, `PLAY_LIFECYCLE_ENABLED=false`,
  `AUTHORITY_ENABLED=false`, test purchases are required and the subject
  allowlist is empty.
- Lifecycle ingress and worker run Python 3.14 and remain closed with the same
  empty subject allowlist. Their infrastructure, encrypted token store, schedules,
  alarms and Pub/Sub identity exist without processing general lifecycle events.
- The historical `POST /purchase-handoff` route remains a disabled migration
  boundary. It is not the Android V1 purchase-verification route and cannot grant
  V1 paid authority.

No provider call, purchase, acknowledgment, entitlement mutation or allowance
change was made during this readback.

## Automated evidence

Lambda [PR 84](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/84)
integrated reviewed source `f51395e2fff0e3f60dd6ba214902af62552365be`
into `release-V01` at `97aa6eb2d2b869e4e1bd220dfb8c53e5637291fc`.
The closeout suites passed 49 focused package, contract and proof tests, 281
authority/ownership/handoff/lifecycle tests, the isolated `v1_play_handoff`
package-import regression and Python compilation. The implementation preserves a
single conditional durable transaction, request-digest replay handling, ownership
isolation, fixed funded-period usage, acknowledgment retry and delete/restore
accounting.

Android [PR 52](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/52)
integrated reviewed source `06cb0899193013346931173da53824af3697302e`
into `release-V01` at `778d2b7f457c851d9b011d474254666cc11cc5c5`.
Its default matrix passed 2,696 host tests: Dev 956, UAT 870 and Production 870.
The explicit canonical-package candidate passed 31 focused tests and an
independent focused rerun, assembled successfully, and recorded APK SHA-256
`d5b52e19255b6d9e1efc8237213a64059b5ac962765adda9ada3bec94fb72453`.
Lint, three-flavor static compilation, formatting, secret, repository-policy,
environment, hardening and transport checks passed. Default builds stay closed;
URL/trial routes stay closed; UAT and Production remain unavailable; and the
account/session/device fences and authoritative access refresh remain intact.

## Remaining execution

ATCR-112 remains open for the Play license-test checkout and restore matrix. It
must record the exact Android, Lambda and infrastructure versions; a scoped Dev
subject; Play-installed or eligible emulator setup; checkout, cancel, pending,
already-owned restore, wrong account, lost callback, duplicate proof, network
failure and acknowledgment retry; and the authoritative snapshot after each
settled result. Fixture or emulator UI evidence must not be reported as an actual
Google provider transaction.

ATCR-148 remains open for physical hardware, real TalkBack speech and device/OEM
lifecycle coverage. Renewal, grace, hold, cancellation, refund, revocation and
RTDN reconciliation remain in ATCR-92 and its existing backend dependencies.
These follow-ups qualify the assembled release; they do not reopen the completed
ATCR-91/111 implementation boundary.
