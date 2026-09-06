# Campaign Intelligence Infrastructure Contract

Status: **Product-approved v1; technical and security handoffs pending** for
`SECUR4ALL-202`

This document defines the AWS capabilities and application-facing boundaries that
`SECUR4ALL-203` must provision. It is not the canonical backend JSON Schema or
OpenAPI contract.

## Stack Contract

Campaign resources are split into two independently locked Terraform states:

1. `campaign-data` owns environment KMS keys, the transient and persistent
   DynamoDB tables, queues/DLQs, deployed-model ECR repository, and resource
   policies.
2. `campaign-processing` owns Lambda roles/functions, event-source mappings,
   EventBridge schedules, log groups, metrics, alarms, and dashboards.

The existing `foundation` stack exports the completed-analysis stream/outbox
contract. `campaign-processing` consumes versioned outputs from `foundation` and
`campaign-data`. The existing `api` stack may consume a versioned read-only
campaign contract when `SECUR4ALL-209` is implemented.

Required deployment order:

```text
foundation -> campaign-data -> artifact verification -> campaign-processing -> api
```

Every output contract contains `schema_version`, `environment`, and only resource
identifiers required by the downstream stack.

Both campaign stacks are conditional. V1 sets
`campaign_intelligence_enabled=true` only in Dev; UAT and Production contain the
configuration flag but create no campaign resources until promotion is approved.

## Resource Capabilities

### CampaignPipeline DynamoDB

- On-demand billing and a customer-managed environment KMS key.
- TTL enabled on `expiresAt` but backed by explicit lifecycle deletion.
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

- Separate feature and clustering standard queues, each with a DLQ.
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
  "eventType": "campaign.feature.requested",
  "environment": "dev",
  "statisticsEventId": "00000000-0000-4000-8000-000000000000",
  "recordVersion": 1
}
```

Allowed `eventType` values in v1 are `campaign.feature.requested` and
`campaign.cluster.requested`. The consumer rejects unknown versions or extra
fields, verifies that `environment` equals its immutable deployment environment,
increments a content-free metric, and sends terminal failures to the DLQ.

### KMS and Period Keys

- Exactly two long-lived customer-managed encryption keys per enabled environment:
  one transient key shared by CampaignPipeline and its queues, and one persistent
  key for CampaignIntelligence. CloudWatch Logs and ECR use service-managed
  encryption in V1 to avoid unnecessary fixed key charges.
- One environment-specific KMS HMAC key per 14-day contributor period.
- Period keys use `HMAC_256`, `GENERATE_VERIFY_MAC`, and `HMAC_SHA_256`.
- Only the publisher/deletion bridge may call `kms:GenerateMac`.
- Only the lifecycle role may disable and schedule deletion of expired period keys.
- Terraform provisions governing roles, policies, alarms, and naming rules; the
  lifecycle service creates and retires period keys so ephemeral keys do not become
  permanent Terraform state.

### ECR

- One deployed-model repository per environment with immutable tags, enhanced
  scanning where available, lifecycle rules, and digest-only Lambda references.
- CI promotes the same approved image digest between repositories without rebuilding.
- Runtime roles cannot push, retag, delete, or download a model from another
  environment.

### V1 Exclusions

V1 must not provision OpenSearch, a NAT gateway, paid VPC interface endpoints,
provisioned Lambda concurrency, Step Functions, DynamoDB Global Tables,
cross-Region replicas, or always-on compute. Any exception requires a separate
cost estimate and explicit approval.

## IAM Contract

| Role | Allowed capabilities | Explicitly excluded |
| --- | --- | --- |
| Observation publisher | Read approved completion records, generate current-period MAC, write transient observation, enqueue opaque ID | Persistent campaign reads, account profile reads, arbitrary KMS use |
| Feature extractor | Read observation by event ID, write features, enqueue opaque ID, pull approved ECR image | Identity data, MAC generation, persistent aggregates |
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

Logs may contain operation name, schema version, model version, coarse period,
result category, duration, queue age, and AWS-generated trace identifiers. Logs,
metrics, traces, alarms, and errors must not contain event IDs, contributor tokens,
candidate/campaign IDs as dimensions, content, indicators, vectors, or identity.

Required low-cardinality counters include published, consent-suppressed,
duplicate, malformed, expired, feature-failed, cluster-failed, deletion-requested,
deletion-completed, finalization-failed, and key-retirement-failed.

## Contract Handoffs

The backend owner must return canonical schemas for:

- authoritative completed-analysis/outbox event;
- campaign observation and feature records;
- candidate and aggregate records;
- consent withdrawal and account-deletion commands;
- publication transition and audit records; and
- app-facing/internal APIs.

Each schema must include a version, maximum serialized size, required/optional
fields, rejection behavior, idempotency behavior, retention class, and an explicit
forbidden-field test. This repository will validate resource sizing, IAM,
encryption, queue behavior, and environment isolation after handoff.

The ML owner must return the maximum vector dimensions and serialized bytes,
memory/CPU/ephemeral-storage requirements, image digest/provenance rules, batching
limits, timeout, and fallback behavior before Lambda and DynamoDB sizes can be
accepted.

## Deployment Gates

- Dev: architecture approval, schemas, synthetic fixtures, Terraform tests, and
  budget alarms are required. The initial monthly campaign budget is $25 with
  notifications at 50, 80, and 100 percent.
- UAT: privacy/security signoff, deletion and time-travel tests, failure injection,
  cross-environment negative tests, and measured ML cost/performance are required.
- Production: manual GitHub environment approval, immutable artifacts previously
  exercised in UAT, go/no-go record, rollback evidence, and zero unresolved privacy
  blockers are required.

## AWS References

- [HMAC keys in AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/hmac.html)
- [KMS key deletion lifecycle](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html)
- [Using SQS with Lambda](https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-configure.html)
- [SQS message retention](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html)
- [DynamoDB TTL behavior](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html)
- [DynamoDB point-in-time recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Point-in-time-recovery.html)
