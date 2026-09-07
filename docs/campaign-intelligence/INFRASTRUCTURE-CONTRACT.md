# Campaign Intelligence Infrastructure Contract

Status: **Product-approved v1; technical and security handoffs pending** for
`SECUR4ALL-202`

This document defines the AWS capabilities and application-facing boundaries that
`SECUR4ALL-203` must provision. It is not the canonical backend JSON Schema or
OpenAPI contract.

## Stack Contract

Campaign resources are split into three independently locked Terraform states:

1. `campaign-data` owns environment KMS keys, the transient and persistent
   DynamoDB tables, the clustering queue/DLQ, and resource policies.
2. `campaign-processing` owns Lambda roles/functions, event-source mappings,
   EventBridge schedules, log groups, metrics, alarms, and dashboards.
3. `campaign-api` owns the trends and reviewer Lambda roles/functions, integrations,
   routes, permissions, alarms, and API dashboard. It adds routes to the existing
   environment API and creates no domain or API Gateway API.

The existing `foundation` stack exports the completed-analysis stream/outbox
contract. `campaign-processing` consumes versioned outputs from `foundation` and
`campaign-data`. The existing `api` stack may consume a versioned read-only
campaign contract when `SECUR4ALL-209` is implemented.

Required deployment order:

```text
foundation -> campaign-data -> base artifact verification -> api
           -> campaign artifact verification -> campaign-processing
           -> campaign-api -> edge
```

Every output contract contains `schema_version`, `environment`, and only resource
identifiers required by the downstream stack.

Both campaign stacks are conditional. V1 sets
`campaign_intelligence_enabled=true` only in Dev; UAT and Production contain the
configuration flag but create no campaign resources until promotion is approved.

## App Feature Contract Boundary

The sanitized analysis request may contain one `appFeatures` object only when the
user has granted campaign consent. The object has exactly these fields:

```json
{
  "schemaVersion": 1,
  "extractorVersion": "android_rules_1",
  "languageId": "en",
  "taxonomyBucket": "advance_fee",
  "vector": [0.125, -0.25],
  "lexicalFingerprint": ["0123456789abcdef"],
  "signalIds": ["payment_request"],
  "indicatorIds": ["domain_hash_1"],
  "confidence": 0.9
}
```

The compact JSON encoding is limited to 32 KiB. `vector` contains 1-384 finite
numbers in `[-1.0, 1.0]`; `confidence` is finite and in `[0.0, 1.0]`.
`lexicalFingerprint` contains at most 32 unique lowercase 16-character
hexadecimal hashes. `signalIds` and `indicatorIds` contain at most 16 unique
stable identifiers each. `extractorVersion` is a non-empty UTF-8 string of at
most 64 bytes. Language and taxonomy values are expandable stable
`lower_snake_case` identifiers of at most 64 characters.

The analysis Lambda validates before committing the outbox record, and the
publisher independently validates before writing transient data or enqueueing
clustering work. Both reject missing or unknown fields, booleans presented as
numbers, duplicate list values, unsupported versions, non-finite or out-of-range
numbers, malformed identifiers, and oversized payloads. Raw indicators, images,
attachments, and OCR payloads are prohibited. An `ocr` source type records only
that local app processing occurred.

## Resource Capabilities

### CampaignPipeline DynamoDB

- On-demand billing and a customer-managed environment KMS key.
- TTL enabled on `expiresAt` but backed by explicit lifecycle deletion.
- `ExpirationIndex` is a sparse, keys-only index. Expiring records set
  `GSI3PK=EXPIRATION` and numeric `GSI3SK=expiresAt`; the lifecycle worker queries
  through the current epoch and deletes the base-table items in bounded batches.
- Streams use `NEW_AND_OLD_IMAGES` only when required for deterministic cleanup;
  stream consumers must not log records.
- PITR, AWS Backup, exports, and replicas are disabled.
- Resource policy and IAM deny cross-environment access.
- No direct account identifier is a table key, attribute, tag, metric, or log field.

Required logical access patterns:

| Access pattern | Proposed key shape |
| --- | --- |
| Observation/features by event | `PK=EVENT#<statsEventId>`, typed `SK` |
| Retry dedupe by event | `PK=EVENT#<statsEventId>`, `SK=DEDUPE` |
| Deletion by contributor and period | `GSI1PK=CONTRIB#<period>#<token>` |
| Candidate lookup | `GSI2PK=PERIOD#<period>#BUCKET#<taxonomy-bucket>` with bounded sort prefixes |
| Contribution by candidate | `PK=CANDIDATE#<candidateId>`, `SK=CONTRIB#<token>` |
| Lifecycle sweep | sparse index by expiration bucket, never by account |

Projection must be `KEYS_ONLY` or `INCLUDE` with an explicit allowlist. `ALL`
projection is prohibited for deletion and candidate indexes.

### CampaignIntelligence DynamoDB

- On-demand billing, a distinct customer-managed environment KMS key, PITR, and
  deletion protection in Production.
- Contains only confirmed aggregate metadata, clipped centroids, coarse rollups,
  bounded indicator summaries, publication state, and privacy-safe audit records.
- No contributor token, event ID, request ID, individual vector, raw/redacted body,
  direct identifier, or precise user timestamp is permitted.
- App-facing queries use a sparse publication index partitioned by state and coarse
  period. Internal transitions use conditional writes and an append-only audit item.

### Queues

- One clustering standard queue with a DLQ. No server feature queue exists.
- Customer-managed KMS encryption, 4-day source retention, 14-day DLQ retention,
  `maxReceiveCount` of 5, partial batch responses, and visibility timeout at least
  six times the Lambda timeout plus any batching window.
- Queue policies accept messages only from the exact environment publisher role
  or approved AWS service source ARN.
- Messages contain no content, indicator, vector, contributor token, or identity.

Normative envelope shape:

```json
{
  "schemaVersion": 1,
  "eventType": "campaign.cluster.requested",
  "environment": "dev",
  "statisticsEventId": "00000000-0000-4000-8000-000000000000",
  "recordVersion": 1
}
```

The allowed `eventType` value in v1 is `campaign.cluster.requested`. The consumer
rejects unknown versions or extra fields, verifies that `environment` equals its
immutable deployment environment, increments a content-free metric, and sends
terminal failures to the DLQ.

### KMS and Period Keys

- Exactly two long-lived customer-managed encryption keys per enabled environment:
  one transient key shared by CampaignPipeline and its queues, and one persistent
  key for CampaignIntelligence. CloudWatch Logs use service-managed encryption in
  V1 to avoid unnecessary fixed key charges.
- One environment-specific KMS HMAC key per 14-day contributor period.
- Period keys use `HMAC_256`, `GENERATE_VERIFY_MAC`, and `HMAC_SHA_256`.
- Only the publisher/deletion bridge may call `kms:GenerateMac`.
- Only the lifecycle role may disable and schedule deletion of expired period keys.
- Terraform provisions governing roles, policies, alarms, and naming rules; the
  lifecycle service creates and retires period keys so ephemeral keys do not become
  permanent Terraform state.

### V1 Exclusions

V1 must not provision OpenSearch, a NAT gateway, paid VPC interface endpoints,
provisioned Lambda concurrency, Step Functions, DynamoDB Global Tables,
cross-Region replicas, or always-on compute. Any exception requires a separate
cost estimate and explicit approval.

## IAM Contract

| Role | Allowed capabilities | Explicitly excluded |
| --- | --- | --- |
| Observation publisher | Read approved completion records containing validated app features, generate current-period MAC, write transient observation, enqueue opaque clustering ID | Persistent campaign reads, account profile reads, arbitrary KMS use |
| Cluster aggregator | Read transient candidates/features, conditionally update candidates and aggregates | Identity data, MAC generation, source analyses |
| Lifecycle processor | Delete transient records, finalize periods, disable/retire keys, emit audit metrics | Account profile reads, source content, app publication changes |
| Deletion bridge | Derive active-period tokens and request targeted cleanup | Persistent aggregate enumeration, feature extraction |
| Campaign read API | Read confirmed publication index and aggregate items | Transient table, review transitions, exact small-cell counts |
| Campaign reviewer | Authorized state transitions and bounded summaries | Transient observations, identities, tokens, individual vectors |

No role may read both account identity data and persistent campaign intelligence.
Infrastructure tests must inspect effective policies, not only Terraform source.

V1 authorizes exactly one named human reviewer principal per environment. The
initial reviewer is the product owner. Shared credentials are prohibited. Review,
publication, suppression, merge, and split actions require a reason and a
privacy-safe immutable audit item. Emergency suppression is limited to that same
reviewer principal until a separately approved operational role is introduced.

## Taxonomy Contract

The taxonomy uses language-neutral stable identifiers with English and Spanish
display labels. Labels may be expanded or corrected without changing an
identifier or requiring a schema-major version. New identifiers may be added in a
backward-compatible schema-minor version. Removing an identifier, changing its
meaning, or changing the data type of a taxonomy dimension requires a new schema
major version.

Every dimension includes `other` and `unknown`. Clients must render unknown future
identifiers safely and must not reject a response only because a newer label or
identifier is present. The backend owner retains the canonical taxonomy artifact
and localization fixtures; this repository validates only its infrastructure and
compatibility requirements.

## Logging and Metrics Contract

Logs may contain operation name, schema version, app feature version, coarse period,
result category, duration, queue age, AWS-generated opaque trace identifiers, and
AWS service event timestamps. Those trace identifiers and timestamps remain only
in short-lived operational logs. Logs, metrics, traces, alarms, and errors must
not contain application request/event IDs, contributor tokens, candidate/campaign
IDs as dimensions, content, indicators, vectors, or identity.

Required low-cardinality counters include published, consent-suppressed,
duplicate, malformed, expired, app-feature-invalid, cluster-failed, deletion-requested,
deletion-completed, finalization-failed, and key-retirement-failed.

## Contract Handoffs

The backend owner must return canonical schemas for:

- authoritative completed-analysis/outbox event;
- campaign observation records with validated app-produced features;
- candidate and aggregate records;
- consent withdrawal and account-deletion commands;
- publication transition and audit records; and
- app-facing/internal APIs.

Each schema must include a version, maximum serialized size, required/optional
fields, rejection behavior, idempotency behavior, retention class, and an explicit
forbidden-field test. This repository will validate resource sizing, IAM,
encryption, queue behavior, and environment isolation after handoff.

The app owner must return the feature schema, maximum vector dimensions and
serialized bytes, extraction-version rules, platform parity evidence, and
fallback behavior before the Lambda allowlist and DynamoDB item bounds can be
accepted. AWS treats every app-produced feature as untrusted input.

## Deployment Gates

- Dev: architecture approval, schemas, synthetic fixtures, Terraform tests, and
  budget alarms are required. The initial monthly campaign budget is $25 with
  notifications at 50, 80, and 100 percent.
- UAT: privacy/security signoff, deletion and time-travel tests, failure injection,
  cross-environment negative tests, and measured app feature quality are required.
- Production: manual GitHub environment approval, immutable artifacts previously
  exercised in UAT, go/no-go record, rollback evidence, and zero unresolved privacy
  blockers are required. Its product-approved campaign budget ceiling is $50 with
  notifications at 50, 80, and 100 percent.

## AWS References

- [HMAC keys in AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/hmac.html)
- [KMS key deletion lifecycle](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html)
- [Using SQS with Lambda](https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-configure.html)
- [SQS message retention](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html)
- [DynamoDB TTL behavior](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html)
- [DynamoDB point-in-time recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Point-in-time-recovery.html)
