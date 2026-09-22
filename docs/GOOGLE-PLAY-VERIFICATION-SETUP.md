# Google Play verification setup

Work: SECUR4ALL-195, ATCR-91 and SECUR4ALL-244. This setup record supports the
Android-first implementation. No billing activation is implied by source work.

## Information needed from the owner

1. The testing track, if any. The owner confirmed the existing package
   `com.andmorethings.trustcheckradar`; do not request another package decision.
2. Whether subscription product `trustcheck_radar_pro_monthly` and monthly base
   plan `pro-monthly` are configured and active at the approved US price of
   $4.99. These identifiers are present in source; Console configuration remains
   unverified.
3. Whether a Google account has been enrolled as a license tester and whether
   a matching build is available on its test device. No account password is
   needed by the implementation team.
4. Whether a service account already has the necessary Play Console access.
   Share configuration identifiers only; place credential material directly in
   the approved secret container after its existence and format are verified.

Source defines three different Android package identities:

| Android flavor | Application ID |
| --- | --- |
| Dev | `com.andmorethings.trustcheckradar.dev` |
| UAT | `com.andmorethings.trustcheckradar.uat` |
| Production | `com.andmorethings.trustcheckradar` |

The owner confirmed an existing Play Console app registered as
`com.andmorethings.trustcheckradar` and approved keeping that identity. An explicit
DevDebug Play-test build option can use this application ID while retaining the
Dev backend and Cognito configuration; ordinary Dev, UAT and production defaults
remain unchanged. This is a license-tester sideload option, not a signed
Play-track release. Use a separate test profile/device: it cannot coexist with
another app using that package, and its debug signature cannot update a
Play-signed installation. Do not uninstall an existing installation or erase its
data to work around that boundary. The new backend candidate must validate the
confirmed package, product and base plan together.

## Google configuration

Enable the Google Play Developer API in the selected Google Cloud project;
an existing project may be reused. Create or select a dedicated service account
and invite its email through Play Console Users & Permissions. Google's Billing
API setup lists permissions to view financial/order data and to manage orders
and subscriptions. Scope app access to the selected package where supported.
The Web Risk API key is a separate credential and cannot replace this OAuth
service account setup. Follow Google's current
[Developer API setup](https://developers.google.com/android-publisher/getting_started).

License testers can use test payment methods and can sideload a matching debug
build; a public release is unnecessary. A test track is useful for validating
store installation. Track membership alone does not make a purchase a license
test. Verify the selected tester account and test payment method before real
purchase acceptance. See
[Google's billing test guidance](https://developer.android.com/google/play/billing/test).

## AWS credential boundary

The repository declares the secret container
`trustcheckradar/dev/google-play-service-account`. After AWS SSO was restored,
read-only metadata confirmed that the container exists and has an `AWSCURRENT`
version. Its ARN is
`arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/google-play-service-account-F89Y5G`.
A bounded read-only audit on 2026-09-21 confirmed valid credential format and
successful OAuth authentication. The fixed subscription catalog request returned
HTTP 403 with `SERVICE_DISABLED`: the Android Publisher API is disabled in the
credential's project, `trustcheck-radar`. The owner has been asked to enable the
[Google Play Developer API](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?project=trustcheck-radar).
The catalog, Play Console permissions, license tester enrollment, test track,
purchase/order/acknowledgment access and RTDN delivery remain unverified. No new
credential or key rotation is needed to address this particular disabled-API
response. Do not put a service-account private key in chat, source, Terraform
variables, plans or logs.

Provider credentials belong only to the backend verification role. Android
supplies a purchase proof to the authenticated backend and does not receive
Google service-account credentials. Preserve the retired endpoint's denial
boundary; new verification is a separately gated candidate.

## Decisions and acceptance still open

- Restoring to a new account after deletion is approved, subject to fresh
  verification and preventing simultaneous ownership. The owner also explicitly
  approved preserving used checks with a minimal purchase-linked usage record
  through the funded period end plus seven days for reconciliation, without
  messages, URLs or the deleted account ID. Existing backups may retain it up to
  35 days longer. Shared accounting, deletion, restoration, expiry and user-facing
  disclosures must implement this together before activation; policy approval
  is not evidence that those changes are complete.
- Exact funded monthly periods must come from verified store data. Grace,
  deferral and shortened entitlement validity require explicit handling; never
  infer a monthly boundary from lifetime subscription start time.
- Real purchase verification, acknowledgment, renewal/refund reconciliation,
  restoration, account/device isolation and store/physical-device qualification
  remain distinct from local fixture tests and disabled deployment.

Current official protocol references:
[purchase security](https://developer.android.com/google/play/billing/security),
[order lookup](https://developers.google.com/android-publisher/api-ref/rest/v3/orders/get),
[subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions).

## Source validation

The inactive infrastructure candidate passed seven mocked Terraform tests; the
resolver topic integration passed twelve. All 62 infrastructure script tests,
Actionlint, shell syntax and diff checks passed. These are source checks, not
store purchase or deployed acceptance. The
[evidence record](evidence/play-verification-source-candidate.json) distinguishes
provider observations, default-disabled controls and outstanding qualification.
