# History and Badges client contract

Decision date: 2026-09-14. Scope: Dev. Approved product/security requirements;
Dev endpoints are deployed but feature-gated off. Lambda owns the versioned JSON schemas; infrastructure
owns routing, IAM, storage and release. Candidate contract 1.0.0 is published in
Lambda release `8d25e19b691d82caf630edc7ebd84c0b45de0c5c`:
[route/catalog manifest](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/8d25e19b691d82caf630edc7ebd84c0b45de0c5c/contracts/history/v1/contract-set.json)
and [JSON schemas](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/8d25e19b691d82caf630edc7ebd84c0b45de0c5c/contracts/history/v1/api-schemas.json).
Dev integration acceptance is still required before shipping mobile calls.

## Identity and authorization

Send both headers on every call:

```http
Authorization: Bearer <Cognito access token>
x-device-binding-fingerprint: <current registered binding fingerprint>
```

The fingerprint must match the caller's active server-side binding; it is not
an alternative identity credential. Never send
`userId`, `accountId`, `sub`, email or a DynamoDB partition key to select a user.
The server derives identity from the verified access token's `sub`. Any profile
lookup needed for eligibility uses that same server-derived identity.

API Gateway validates JWT signature, issuer, client audience and lifetime.
History routes require the `aws.cognito.signin.user.admin` access-token scope
issued by the native Cognito sign-in flow. This is not AWS account administrator
permission. Lambda additionally checks `token_use=access`, exact issuer/client,
expiration and scope in Gateway-verified claims. Decoding an unverified JWT is
not authentication. ID tokens are not accepted for these APIs.

The server also enforces active device binding and authoritative account/deletion
status. Bootstrap must not recreate a deleted account. Every lookup, including a
request ID in the path, is scoped to the authenticated subject. A request ID is
not proof of ownership. Unsupported or account-targeting fields are rejected.

Lambda roles serve multiple users: IAM restricts tables and key families but
does not itself enforce per-user isolation. Handler authorization, subject-derived
keys, transactions and cross-user tests are mandatory. No mobile DynamoDB
credentials, direct database access or tokens in URLs/logs are permitted.

## Routes

Existing Dev base: `https://api-dev.andmorethings.net`. These additional History
routes were deployed on September 16 UTC but remain disabled pending authenticated
tests and cleanup acceptance. See HISTORY-DEV-RELEASE-2026-09-16.md.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/v1/users/history/bootstrap` | Idempotent initialization for an eligible account |
| GET | `/v1/users/history` | Retained completed assessments, newest first |
| GET | `/v1/users/history/{requestId}` | One retained assessment owned by the caller |
| GET | `/v1/users/history/export` | Paginated export of the caller's retained History |
| GET | `/v1/users/progress` | The caller's badge progress |
| DELETE | `/v1/users/history/{requestId}` | Delete one assessment; preserve badges |
| DELETE | `/v1/users/history` | Clear History; preserve badges |
| POST | `/v1/users/progress/reset` | Reset badges; preserve History |

History export is not complete account-data export. A History-only deletion fence
is not a full-account deletion endpoint. Authoritative account-deletion integration
is an activation prerequisite.

The Lambda manifest also defines `DELETE /v1/users/history/account` for History
data only. Infrastructure intentionally does not expose that extra route here;
mobile must not use it as "Delete account" or assume it is available.

Bootstrap body:

```json
{"schemaVersion":1}
```

Delete/clear/reset body; preserve the same canonical UUIDv4 operation ID on retry:

```json
{"schemaVersion":1,"operationId":"b564f1ae-d21b-4c4b-9a18-9b8584a168fc"}
```

List/export accept only `limit` and `cursor`; other listed reads accept no query
parameters. The request ID is the original analysis identifier, preserved across
retries. It matches `^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$`.

## Reads and refresh

- Page size: 20 default, 50 maximum requested. Pages can contain fewer records.
- Complete serialized response: at most 262144 UTF-8 bytes, including envelope,
  invalidation metadata and next cursor.
- Opaque cursors expire after 900 seconds and are bound to the caller and History
  generation. Do not parse, edit or reuse across accounts or invalidation.
- Retain assessment, request ID, source type and server acceptance/completion
  times. No submitted conversation, screenshot or snippet in History.
- Source types: `pasted_text`, `ocr`, `mixed`. OCR is performed on the phone;
  the source label does not authorize image uploads or server-side OCR.
- Assessment bounds: summary 4096 UTF-8 bytes, each signal/action text 1024 UTF-8
  bytes, at most 20 entries per bounded assessment list.
- Read envelopes include `schemaVersion`, `contractVersion`, `serverTimeEpoch`,
  `historyGeneration` and `recognitionGeneration`. `serverTimeEpoch` is Unix
  seconds; item acceptance/completion fields ending `EpochMs` use milliseconds.
- Amplify obtains/refreshes access tokens; never send refresh tokens to History.
  On authentication failure, attempt supported session refresh once. If refresh
  is rejected/revoked, return to sign-in. Offline/transient failures must not
  trigger destructive local/server mutations.
- Clear encrypted caches on logout/account changes. Reconcile invalidation on
  reconnection before displaying stale cached content. Disconnected devices
  cannot receive immediate remote erasure.

## Response examples

Illustrative successful list response, not a live account read:

```json
{
  "schemaVersion": 1,
  "contractVersion": "1.0.0",
  "serverTimeEpoch": 1789420800,
  "historyGeneration": 0,
  "recognitionGeneration": 0,
  "items": []
}
```

Each list item contains `requestId`, `sourceType`, `acceptedAtEpochMs`,
`completedAtEpochMs` and `assessment`. Assessment contains its own
`schemaVersion: "1.0"`, `requestId`, `scamScore` (0-100), `riskLevel`
(`low`, `medium`, `high`), `confidence` (0-1), `summary`, `signals` and
`recommendedActions`. Detail returns `item` instead of `items`. Export adds
`exportFormat: "application/vnd.amt.trustcheckradar.history.v1+json"`.
`nextCursor` is optional and absent at the end; do not require a null field.

Progress uses the common read envelope plus `qualifyingChecks`,
`awardedBadgeIds` and `badges`. Each of the three badge objects contains `id`,
`threshold`, `titleKey`, `descriptionKey` and boolean `awarded`.

A clear-History acknowledgment from published Lambda `c0396535` is:

```json
{
  "schemaVersion": 1,
  "contractVersion": "1.0.0",
  "operationId": "b564f1ae-d21b-4c4b-9a18-9b8584a168fc",
  "operation": "clear_history",
  "status": "COMPLETE",
  "completedAtEpoch": 1789420800,
  "historyGeneration": 1
}
```

The three deployed mutation operations return HTTP 200 / `COMPLETE`. For clear,
this acknowledges a generation change and queued erasure, not physical cleanup.
The source-only History account-data deletion operation can return 202/PENDING;
it is not exposed by this infrastructure and is not full-account deletion.
Retries preserve the operation ID and exact operation/target, subject to the
receipt-retention limitation below. Do not invent a status polling endpoint.

### Published mutation behavior and gaps

Verified against Lambda main `c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca` and
V1 contractVersion `1.0.0`; these are source observations, not live acceptance.

| Operation | Fields emitted beyond the common receipt | Meaning of COMPLETE |
| --- | --- | --- |
| `delete_one` | `completedAtEpoch`, `targetRequestId` | Current active locator content/replay erased atomically, or a no-op when absent/non-current; not a full-storage erasure audit |
| `clear_history` | `completedAtEpoch`, `historyGeneration` | History generation advanced and erasure job queued; badges preserved |
| `reset_progress` | `completedAtEpoch`, `recognitionGeneration` | New empty recognition generation; History preserved |

Common fields are schemaVersion, contractVersion, operationId, operation and
status. The frozen JSON schema requires only those common fields: it does not
conditionally require timestamps, target or generation. Do not describe the
stronger source behavior as a schema guarantee. Mobile can conservatively reject
an incomplete/mismatched receipt as unconfirmed; it must not invent missing
values, declare physical purge, or issue a replacement mutation automatically.

History read/export/bootstrap/delete/clear/reset enforce valid access-token
claims, active eligible profile, deletion fence and active binding. They do not
currently require a recent `auth_time`. A confirmation dialog or device biometric
is not server fresh-auth proof. The separate, disabled consumer recovery and
account-deletion request candidates check signed `auth_time` within 300 seconds,
plus `iat` consistency and bounded future skew. That rule is not an approved
History requirement or a working full-account export contract. Token refresh
does not substitute for a new sign-in satisfying the server freshness rule.

Same-subject operation-ID replay returns the original stored receipt for the
same operation/target; a different operation/target conflicts. Replayed times
and generations describe the original result, not current account state. Never
roll back fresher local generations from an old receipt. Current `_receipt`
does not check expiresAt: an expired-but-present receipt can replay, while a
physically removed seven-day receipt makes the ID look new. Reusing it can
clear/reset newer data. Stop automatic recovery at the conservative receipt
window; retain the uncertain outcome and require explicit resolution/new intent.
There is no public mutation-status API or expired-ID rejection guarantee.

The accepted requestId pattern permits literal `export`. GET
`/v1/users/history/export` is the static export route, so that ID cannot be
retrieved through the existing detail URL. URL encoding is not a supported
workaround. [API Gateway selects the most-specific route](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-routes.html).
New mobile IDs can use UUIDs, but that does not fix already accepted IDs or
change the server contract. Do not relabel/delete legacy IDs.

Proposals, NOT published contract changes: add operation/status-conditional
receipt schemas; define safe expired-operation handling and recovery; add an
unambiguous detail route such as `/v1/users/history/items/{requestId}` while
preserving legacy routes. The route requires coordinated Lambda dispatch,
Terraform route/invoke permission and consumer-contract changes before use.
Any new History fresh-auth requirement needs its own approved policy and contract.
These source/schema/fixture changes can be developed locally without provisioning
the temporary acceptance environment, but must not be reported deployed or tested
against real users until separately released and accepted.

Source references:
[mutation service](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca/src/history_mutation_api/service.py),
[mutation handler](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca/src/history_mutation_api/app.py),
[published schema](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca/contracts/history/v1/api-schemas.json),
[History authorization](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca/src/shared_history/security.py).

Lambda error envelope:

```json
{"error":{"code":"UNAUTHORIZED","message":"A verified Cognito access token is required.","retryable":false}}
```

HTTP mapping: 400 invalid request; 401 authentication; 403 forbidden/device
binding; 404 unavailable owned record; 409 conflict; 503 disabled/unavailable;
500 internal failure. Do not parse `message` as a stable error code. Gateway
rejections can occur before Lambda and need not use the Lambda error envelope;
clients must handle the HTTP status even when that envelope is absent.

## Badges and storage

Completed assessment content lives in the History content DynamoDB table.
Server-authoritative badge progress lives in the separate History control table.
The app displays returned progress; it cannot award badges or change counters.

| ID | Qualifying checks | Localization keys |
| --- | --- | --- |
| `checks_1` | 1 | `badges.checks_1.title`, `badges.checks_1.description` |
| `checks_5` | 5 | `badges.checks_5.title`, `badges.checks_5.description` |
| `checks_20` | 20 | `badges.checks_20.title`, `badges.checks_20.description` |

Count distinct server-accepted completed checks, not confirmed scams. Same-ID
retries never award twice. Deliberate submissions under new IDs count as new
checks; no extra content fingerprint is retained for badge deduplication.
Reset advances the recognition generation. Delayed completions from submissions
accepted before reset cannot immediately re-award progress. EN/ES text belongs
in the versioned catalog. No risk-based points, payment or scan-allowance effects.
History, badges and campaign consent remain independent controls.

## Retention and deletion

History expires 90 days after server completion; reading/retrying does not extend
it. Deleted/expired content is immediately excluded from reads and must leave
active content/replay stores within 24 hours. DynamoDB TTL alone cannot prove
that deadline: a tested cleanup worker and monitoring are required.

Approved Dev settings: 7-day point-in-time recovery windows for both History
tables; 120-day minimal dedup/deletion metadata; 7-day mutation receipts. These
do not authorize assessment text in metadata or changes to other shared-table
backup policies. Backups expire separately, and restores must reapply deletions
before traffic is served. Badge progress has its own reset/account-deletion
lifecycle, not the content expiry clock.

## Activation requirements

1. Complete the product-level account-deletion producer. The Lambda owner
   confirmed no existing endpoint/worker writes the fixed
   `ACCOUNT#<sub>/ACCOUNT_DELETION` request. The History consumer, fences and
   cleanup cannot originate a user account-deletion request; SECUR4ALL-200 remains
   a real dependency, not a completed story.
2. Review candidate schemas, catalog and tests against deployed behavior.
3. Immutable artifacts and reviewed Dev Terraform plans.
4. Confirmed alert delivery and active lifecycle cleanup.
5. Disposable-user authenticated tests: cross-subject isolation, token checks,
   device binding, retries, reset/delete races and erasure.

AWS CLI authentication was renewed and deployment completed. No activation has
been performed. Approval to release History/Badges separately from incomplete
full-account data management, disposable-account tests and live cleanup/alert
acceptance remain outstanding.
