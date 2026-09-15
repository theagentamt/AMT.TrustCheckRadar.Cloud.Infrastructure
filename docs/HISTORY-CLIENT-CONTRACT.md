# History and Badges client contract

Decision date: 2026-09-14. Scope: Dev. Approved product/security requirements;
not yet deployed endpoints. Lambda owns the versioned JSON schemas; infrastructure
owns routing, IAM, storage and release. Candidate contract 1.0.0 is published in
Lambda source commit `d93d56cdba1632264f1fd0f0fa7ba090310aec05`:
[route/catalog manifest](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/d93d56cdba1632264f1fd0f0fa7ba090310aec05/contracts/history/v1/contract-set.json)
and [JSON schemas](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/d93d56cdba1632264f1fd0f0fa7ba090310aec05/contracts/history/v1/api-schemas.json).
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
routes remain pending deployment and authenticated tests.

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

A clear-History acknowledgment can be:

```json
{
  "schemaVersion": 1,
  "contractVersion": "1.0.0",
  "operationId": "b564f1ae-d21b-4c4b-9a18-9b8584a168fc",
  "operation": "clear_history",
  "status": "PENDING",
  "acceptedAtEpoch": 1789420800,
  "historyGeneration": 1
}
```

Mutation `PENDING` returns HTTP 202; `COMPLETE` returns HTTP 200. Acceptance
does not assert that physical cleanup already completed. Retrying must preserve
the operation ID and exact operation/target, not generate a fresh UUID.

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

AWS SSO expired during this work. No activation has been performed under this
approval yet; user sign-in renewal is needed before deployment can continue.
