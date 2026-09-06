# ADR-001: Campaign Privacy Boundary and Lifecycle

- Status: Proposed
- Story: `SECUR4ALL-202`
- Date: 2026-09-05
- Owners: AWS infrastructure, with product/privacy and security approval required

## Context

Campaign intelligence must identify recurring scam patterns without creating a
user graph or retaining source submissions as analytics. The system still needs
temporary deduplication, contributor counting, poisoning resistance, consent
withdrawal, and account-deletion support. Those requirements mean temporary
pseudonymity is necessary, but it must end on a deterministic schedule.

## Decision

### Boundary

The campaign boundary starts at an asynchronous publisher consuming the
authoritative completed-analysis transition. The publisher may momentarily see
source identity and the approved sanitized analysis fields. Before writing to a
campaign table or queue, it must replace identity with a period-scoped
contributor token and replace request identity with a random statistics event ID.

Campaign resources must never contain email, phone number, Cognito subject,
account/profile ID, device identifier, IP address, request ID, raw screenshot,
OCR body, original message, filename, local path, access token, or precise user
event timestamp.

### Period and Cohort

- Aggregation uses fixed 14-day UTC periods.
- `periodId` is `floor(epochSeconds / 1209600)`, anchored to the Unix epoch.
  The internal period ID is not exposed by the app-facing API.
- A candidate may be promoted only after contributions from at least 10 distinct
  contributor tokens in the same period.
- One contributor supplies at most one vector to a campaign centroid per period.
- At most three submissions from one contributor may affect a campaign submission
  count in a period. Further submissions are accepted for user analysis but are
  suppressed from campaign statistics.
- Any public dimension with fewer than 10 distinct contributors is omitted.
- App-facing APIs return submission and contributor count bands rather than exact
  counts. Initial bands are `10-24`, `25-49`, `50-99`, `100-249`, and `250+`.
- Durable timestamps use ISO week buckets. Exact processing timestamps remain
  operational metadata only and are never copied to durable campaign records.

The threshold and bands are privacy defaults, not ML similarity thresholds.
Product/privacy must approve them before UAT.

### Event Identity

The completed-analysis transaction creates one UUIDv4 statistics event ID and
stores it in the authoritative outbox. It is not derived from a request, account,
device, or content. Retries reuse that ID. Campaign aggregates never retain it.

### Contributor Token

Each environment and period uses a dedicated AWS KMS `HMAC_256` key with
`GENERATE_VERIFY_MAC` usage and the `HMAC_SHA_256` algorithm. The token
derivation input uses domain separation and the canonical internal account ID:

```text
HMAC(period-key, "campaign-contributor:v1\0" || canonical-account-id)
```

Only the publisher/deletion bridge can call `kms:GenerateMac`. The raw key is
never exportable. The campaign processor receives only the base64url token. The
key, token, and resulting records are pseudonymous while the key is usable and
must never be described as anonymous.

The key remains enabled through the 14-day period and a 7-day recovery window so
consent withdrawal and account deletion can derive the token and remove active
contributions. At recovery close, the lifecycle job disables the key and schedules
KMS deletion with the minimum seven-day waiting period. Disabled keys cannot be
used to regenerate tokens during pending deletion.

This replaces the earlier Secrets Manager raw-HMAC-secret direction. KMS HMAC
avoids exposing raw key material and gives auditable use and deterministic
disablement. `SECUR4ALL-203` must be updated before implementation.

### Retention and Deletion

| Data class | Maximum retention | Backup policy |
| --- | --- | --- |
| Sanitized observation | Feature handoff plus 24 hours; hard TTL 72 hours | No backup or PITR |
| Feature vector/fingerprint | Period end plus 7 days; maximum 21 days | No backup or PITR |
| Contributor token and dedupe item | Period end plus 7 days; maximum 21 days | No backup or PITR |
| Unconfirmed candidate/contribution ledger | Period end plus 7 days; maximum 21 days | No backup or PITR |
| SQS source queue | 4 days | No backup |
| SQS dead-letter queue | 14 days; opaque IDs only | No backup |
| Confirmed aggregate and coarse rollups | 400 days | DynamoDB PITR enabled |
| Privacy-safe application audit records | 400 days | DynamoDB PITR enabled |
| Content-free CloudWatch logs | Dev 14, UAT 30, Production 90 days | Service retention only |

DynamoDB TTL is a cleanup mechanism, not a deletion deadline. The lifecycle
Lambda performs explicit deletes and verifies completion before the deadline.

Queue messages contain only an opaque event ID, environment, schema version,
record version, and operation. Consent withdrawal or deletion tombstones and then
deletes the referenced table item. A queued or dead-lettered ID therefore cannot
resurrect content; consumers must treat missing or suppressed records as a
successful no-op.

During the active or recovery window, deletion removes observations, features,
tokens, dedupe items, and unfinalized contributions and recalculates affected
candidates. Finalization occurs only after the recovery window. Once the key is
disabled and the aggregate passes the cohort threshold after recalculation, the
aggregate is retained without a relinking mechanism.

### Environment Isolation

Dev, UAT, and Production use separate Terraform state, KMS keys, DynamoDB tables,
queues/DLQs, Lambda roles/functions, log groups, schedules, alarms, and deployed
model-image repositories. No runtime role has cross-environment permissions.
Synthetic or explicitly licensed fixtures are used outside Production. Production
events cannot be replayed into non-Production.

### Search Architecture

The first release uses DynamoDB candidate indexes and bounded Lambda-side scoring.
OpenSearch or another vector index requires a separate privacy review and story.
An evaluation is triggered when any two conditions hold in UAT or Production:

1. p95 candidate retrieval returns more than 500 candidates per observation for
   seven consecutive days.
2. p95 candidate retrieval and scoring exceeds 750 ms for seven consecutive days
   at approved target load.
3. Projected monthly DynamoDB plus clustering Lambda cost exceeds 75 percent of a
   fit-for-purpose managed vector alternative for two consecutive months.
4. Approved multilingual quality targets cannot be met with bounded candidate
   retrieval.

Crossing a threshold does not authorize deployment. It only triggers an ADR and
privacy/cost review.

## Consequences

- Account-linked campaign cleanup is possible only before finalization and key
  disablement. After that point there is no retained account link to follow, and
  only a thresholded non-linkable aggregate may remain.
- Transient data cannot use backup restoration as a recovery strategy. Queue replay
  and reconstruction from still-authorized source events provide recovery.
- Opaque queue messages require workers to read current table state and make stale,
  deleted, or suppressed work a successful no-op.
- Periodic KMS key creation, disablement, and deletion require lifecycle automation
  and privacy-safe alarms.
- Product/privacy, backend, ML, and security approvals remain blocking inputs.

## AWS References

- [HMAC keys in AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/hmac.html)
- [Scheduling KMS key deletion](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html)
- [DynamoDB TTL behavior](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html)
- [DynamoDB point-in-time recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Point-in-time-recovery.html)
