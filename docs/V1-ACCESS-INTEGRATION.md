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

The four modern functions remain Python 3.14/ARM64, with empty engineering
allowlists and disabled execution gates. Their live aliases are consumer 4,
entitlements 4, recovery 4 and deletion 3. The completed nine-function
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
