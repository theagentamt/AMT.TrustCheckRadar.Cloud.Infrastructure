# Inactive Google Play verification candidate

This isolated Terraform root belongs to SECUR4ALL-244 and supports the new
SECUR4ALL-195 Lambda contract. The root defaults to disabled. UAT/Production remain disabled; the Dev file now
selects an immutable package and authenticated route for closed-gate qualification.

An explicitly selected immutable Dev package can provision a Python 3.14/ARM64
`v1_play_handoff.app.lambda_handler` behind a `live` alias. The candidate has
29-second timeout, concurrency two and no asynchronous retries. Both
`PLAY_HANDOFF_ENABLED` and `AUTHORITY_ENABLED` are hardcoded false; the synthetic
subject allowlist is empty, catalog qualification is explicitly recorded, and real purchases
are rejected by the required test-purchase setting. No caller-supplied environment
map or activation switch can override those controls.

The role uses existing Users, device bindings, deletion ledger and purchase
authority tables. It can read identity/control fences and commit only
transactional PutItem actions under the specified authority/ownership prefixes.
The mutation prefix `V1#*#*` includes account and purchase-usage rows but excludes
the authoritative `V1#CONTROL` inventory marker. It cannot update either
inventory control, scan/query/delete storage,
invoke another Lambda or chain roles. Two exact existing AWSCURRENT secrets are
readable: the authority HMAC key ring and Google Play service account. This root
does not create credentials, secret values, tables, tokens or a new retention
policy. Purchase-linked usage has the owner's separately approved retention
contract and requires coordinated backend accounting/deletion implementation.

The owner selected `com.andmorethings.trustcheckradar`, product
`trustcheck_radar_pro_monthly` and base plan `pro-monthly` remain the existing
source catalog identifiers. The bounded catalog audit returned HTTP 200 with an
active P1M US base plan at $4.99. This does not prove purchase/acknowledgment
permissions or actual tester qualification. Refer to
[the setup record](../../docs/GOOGLE-PLAY-VERIFICATION-SETUP.md).

The mobile contract is `POST /v1/purchases/google-play/verify`. Optional routing
requires the exact Dev API/$default stage, Cognito issuer/audience and access-token
scope, with same-account permission limited to the live alias and method/path.
The owning API root supplies burst 4/rate 2 throttling. Publishing this closed
route does not authorize purchases; engineering subjects, inventory, cleanup,
provider and authenticated acceptance still require qualification. The old purchase endpoint and its denial
boundary remain separately owned by `terraform/api`.

Optional native runtime error/throttle alarms use only the existing support
topic. Its owning resolver stack has a default-false
`play_alarm_notifications_enabled` setting authorizing exactly those two
CloudWatch ARNs. It must be enabled in a separately reviewed plan before alert
delivery is claimed. These alarms do not represent provider error,
acknowledgment recovery, RTDN, daily reports or complete lifecycle monitoring.
Those remain explicit SECUR4ALL-125/244 dependencies.

State is independent: `trustcheckradar/dev/play-verification.tfstate`.
Automatic deployment excludes this root. Use the scoped helper and an exact
reviewed saved plan for any later authorized Dev installation. Main-only CI
validates the root; release-branch work uses local checks. No Android Actions.
