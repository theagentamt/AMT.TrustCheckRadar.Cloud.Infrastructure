# V1 authoritative access integration

Tracking: [SECUR4ALL-230](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-230),
[ATCR-92](https://andmorethings.youtrack.cloud/issue/ATCR-92) and
[SECUR4ALL-242](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-242).

The owner approved parallel backend and Android work on 2026-09-21. Existing
shared accounting and access contracts are reused. This increment connects
Pricing/Settings to modern authority and hardens snapshot consistency; it does
not implement store lifecycle ingestion or grant general customer access.

## Verified infrastructure boundary

Read-only AWS inspection on 2026-09-21 confirmed the following in Dev account
`107827791950`, region `us-east-1`:

| Mobile operation | Existing route | Owning Terraform root |
| --- | --- | --- |
| Read authoritative access | `GET /v1/access` | `terraform/url-consumer` |
| Explicitly activate trial | `POST /v1/access/trial` | `terraform/url-consumer` |

Both routes require the configured Cognito JWT issuer, audience and
`aws.cognito.signin.user.admin` scope. They invoke the `v1-entitlements:live`
alias with a 15-second integration timeout. Neither route invokes the legacy
`/entitlements/snapshot` handler. There is no `/v1/users/access` route.

Before this update, the four modern functions were Python 3.14/ARM64, with empty
engineering allowlists and disabled execution gates. Their live aliases were
consumer 4, entitlements 4, recovery 4 and deletion 3. The completed nine-function
[research runtime migration](DEV-RESEARCH-RUNTIME-MIGRATION.md) is a separate
deployment; it did not install a new version of these four functions.

Exact route and version/hash metadata is recorded in
[the minimized read-only report](evidence/v1-access-surface-2026-09-21.json).
The inspection did not invoke a provider, issue a grant or modify an account.
Both routes also rejected requests without authentication with HTTP 401. This
verifies the unauthenticated boundary only; no signed-in access or trial
activation was exercised. All eight existing mocked Terraform cases for the
access root passed, including route scoping and closed activation defaults.

The access/trial role already supports scoped identity-fence reads,
transaction-only V1 authority writes and access to the current authority HMAC
key ring. It has no provider invocation grant. Snapshot hardening uses this
existing storage and permission boundary; no new table, secret or route is
required for the proposed increment.

## Contract and acceptance boundaries

- Lambda owns the schema-1 `contracts/v1-access/v1` contract and authoritative
  snapshot semantics. Android must bind an immutable reviewed contract and use
  the existing routes; an unavailable service cannot fall back to retired
  FREE/PRO balances as current authority.
- The approved limits remain 200 completed checks per paid subscription period
  and a seven-day, ten-completed-check trial starting at explicit activation.
  A snapshot refresh cannot activate a trial or replenish allowance.
- Paid, trial and complimentary authority must remain distinct from device
  eligibility, usage reservations and temporary service failure. Account-bound
  built-in checks remain available without cloud-service access.
- Partial, failed and inconclusive checks do not deduct allowance. Retries and
  reconciliation preserve at most one deduction for a completed logical check.
  Neither Android nor a display refresh creates or repairs a grant.
- Backend regressions and Android local/emulator validation must be reported
  separately from authenticated Dev, real Play and physical-device acceptance.

## Remaining dependencies

| Dependency | Work still required |
| --- | --- |
| SECUR4ALL-125 / SECUR4ALL-195 / SECUR4ALL-244 | Verified Google Play lifecycle, durable purchase ownership and restoration; a typed paid-writer interface alone does not provide live paid access. |
| SECUR4ALL-232 | Real authenticated complimentary operator adapter and audit/retention acceptance; mobile callers cannot grant complimentary access. |
| SECUR4ALL-241 and account privacy work | Historical authority/key inventory, accounting reconciliation, complete account deletion and cleanup continuity. The runtime migration itself is already deployed. |
| SECUR4ALL-242 | Review final immutable packages, compatible consumers and saved Dev plan before deploying changed runtime source. Preserve closed gates until their actual activation prerequisites are met. |
| ATCR-114 / ATCR-112 / ATCR-148 | Live snapshot/store and final physical-device/accessibility qualification under their existing scopes. |

Publication, release-branch integration, runtime deployment and feature
activation are separate states. Development targets `release-V01`; automatic
CI remains main-only. Reviewed manual Dev infrastructure/Lambda Actions are
authorized; Android Actions remain excluded.

## Reviewed runtime update

Lambda [PR37](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/37)
integrated source `8700d234e17ac9155bf6566f9ddcbd5bc8341146` into `release-V01`.
Its four public access schema/fixture files are byte-identical to the previous
contract. Validation passed 1,769 ordinary tests plus 232 subtests and 263
SDK/Moto authority tests, including 39 new corruption/race cases. Eight affected
archives were built; only the four functions owned by this Terraform root were
selected for the disabled Dev update.

The [publication manifest](evidence/v1-access-publication-2026-09-21.json)
records exact S3 object versions and hashes. Downloaded bytes matched each
record. Its generic `app.lambda_handler` identifies the available packaged shim;
the installed nested entitlement/deletion handlers are preserved and were also
checked directly. Local archive imports do not substitute for target-runtime
acceptance.

The baseline Dev plan had no drift. The saved candidate plan contains only four
Lambda code updates and their four alias updates, with no creates, deletes,
replacement, IAM changes or activation. Runtime configuration, existing nested
handlers, empty subject allowlists, disabled schedules and stream mapping stay
unchanged. The [minimized plan record](evidence/v1-access-install-plan-2026-09-21.json)
includes the saved-plan digest and exact configured handlers. This plan record
alone is not evidence that installation or activation occurred.

## Completed installation and Android integration

Infrastructure [PR45](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/pull/45)
integrated source `943645385afee7a1b0f245a732bf66e8f9c482cd` into `release-V01`.
The independently reviewed saved plan was then applied manually to the isolated
Dev access root: eight in-place updates, zero additions and zero deletions. The
post-apply plan reported no drift. This update did not use GitHub Actions.

The [target-runtime verification](evidence/v1-access-runtime-2026-09-21.json)
confirms consumer/recovery/entitlements version 5 and deletion version 4, exact
published hashes, Python 3.14/ARM64, unchanged handlers and concurrency. All
execution flags remain false; subject allowlists remain empty. Both maintenance
schedules and the deletion stream mapping remain disabled.

All four final empty-event alias checks returned the expected disabled response
without a Lambda `FunctionError`. The verifier corrected an alias lookup and an
error-envelope assertion; seven empty disabled invocations occurred in total.
These checks verify package loading and the closed handler paths. No signed-in
check, trial grant, billing, research or customer deletion was exercised, and no
provider call occurred on these inspected paths.

Android [PR35](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/35)
integrated source `427f48b46c50940698fc70b053356f72344db1cf` into `release-V01`
at `69bbade6f38198540692183e7c1a80a5947b6d25`. Pricing and Settings now reuse
the modern access snapshot, with account/generation guards, explicit reserved
versus completed counts, neutral unavailable wording and no legacy balance
fallback. Source validation passed all 147 local gate tasks, 2,443 host tests and
15 emulator cases. Line/branch coverage is 92.89%/85.73%. Independent review
verified the immutable contract and 33 recorded hashes. No Android Actions ran
for this work; the application service gate remains disabled.

This completed the snapshot implementation and disabled installation increment.
At that point, the broader SECUR4ALL-230 and ATCR-92 stories remained In
Progress for the live authority, paid lifecycle and qualification dependencies
listed above. Their unperformed acceptance cases were not declared passed or
silently deferred.

## ATCR-92 source-completion audit

The 2026-09-30 ATCR-92 audit rechecked all three owning Dev Terraform roots
against `release-V01`: `url-consumer`, `play-verification` and
`play-lifecycle`. Each live plan reported **No changes**. The local suites passed
68, 11 and 32 cases respectively. The first sandboxed test attempt could not
start the downloaded AWS provider process; the same suites passed when rerun
individually with the normal host execution boundary. No resource or account
was changed by this audit.

AWS readback confirmed Python 3.14 for the entitlements, Play handoff, lifecycle
ingress and lifecycle worker functions. The following controls remain closed:

- `V1_ENTITLEMENTS_ENABLED=false`, `AUTHORITY_ENABLED=false` and an empty
  entitlements subject allowlist;
- `PLAY_HANDOFF_ENABLED=false`, `PLAY_PREPARATION_ENABLED=false` and an empty
  Play handoff subject allowlist;
- `PLAY_LIFECYCLE_ENABLED=false`, `PLAY_CHECKPOINT_POLICY_APPROVED=false` and
  an empty lifecycle subject allowlist; and
- the one-minute lifecycle worker schedule is `DISABLED`.

The Google Play notification surface still consists of the exact authenticated
`POST /v1/notifications/google-play` JWT route. A reachable authenticated route
does not imply that lifecycle processing is active while the runtime gates and
worker schedule remain closed.

This is the intended boundary for Android source completion. ATCR-92 may use
deterministic Android and Lambda regression evidence for implementation
acceptance, while authenticated Dev, Google Play sandbox and physical-device
execution remain in ATCR-114, ATCR-112 and ATCR-148. Those release-test stories
must cover renewal, active deferral/grace, cancellation through expiry, hold,
paused/suspension policy, completed pending purchase, refund/revocation,
out-of-order notification handling, restored purchases, stale/offline snapshots
and balance refresh after every server-confirmed chargeable action. They must
record the exact mobile, Lambda and infrastructure release heads and distinguish
provider evidence from fixtures.

No infrastructure source correction or activation was justified by this audit.
Activation requires a separately reviewed Dev plan and the outstanding lifecycle
policy/provider gates; it must not be inferred from ATCR-92 source completion.
