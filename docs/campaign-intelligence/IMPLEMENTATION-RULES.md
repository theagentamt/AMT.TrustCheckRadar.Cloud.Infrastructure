# Campaign Intelligence V1 Implementation Rules

- Story: `SECUR4ALL-202`
- Approval date: 2026-09-06
- Decision owner: Product owner
- Status: Approved product baseline; technical handoffs remain open

These rules are normative for V1. Changes require a versioned decision record and
updated evidence from the affected owner. This repository implements only the AWS
infrastructure portions of the rules.

## Taxonomy

- Machine identifiers use stable `lower_snake_case` values.
- English and Spanish labels are stored separately from machine identifiers.
- Labels may be added or corrected without breaking clients.
- New identifiers require a schema-minor version.
- Removing an identifier or changing its meaning requires a schema-major version.
- Every dimension includes `other` and `unknown`.
- V1 dimensions cover scam category, claimed organization, requested action,
  payment method, emotional tactic, channel, language, risk, confidence, and
  bounded indicators.
- Full phone numbers, wallet identifiers, usernames, and URLs are never published.
  Reviewed domains may be published only after the 10-contributor threshold.

## Data Contracts

- Every contract carries `schemaVersion` and internal producers reject unknown
  fields.
- Queue envelopes contain only environment, operation, random event ID, record
  version, and schema version.
- Account identifiers, Cognito subject IDs, application/user-supplied request IDs,
  device IDs, IP addresses, raw content, OCR text, screenshots, and application
  timestamps are prohibited. AWS-generated opaque trace IDs and service event
  timestamps may exist only in short-lived operational logs; they are never
  stored in campaign records, metrics, alarms, or API responses.
- Transient identifiers and contributor tokens remain in transient storage only.
- Persistent records contain only confirmed aggregates, taxonomy identifiers,
  count bands, coarse weeks, clipped centroids, workflow state, and privacy-safe
  audit data.
- App-facing APIs expose confirmed campaigns only.
- Pagination tokens are opaque, bounded, expiring, and tamper-resistant.

`SECUR4ALL-213` owns the canonical JSON Schema or OpenAPI artifacts and bilingual
taxonomy fixtures. Infrastructure consumes those versioned artifacts but does not
implement them here.

## App Feature Extraction

- Feature extraction always runs in the app, never in AWS server infrastructure.
- The app sends a bounded, versioned feature object with the already-sanitized
  text used by an opted-in analysis.
- The service treats app-produced features as untrusted input and validates the
  schema version, types, dimensions, numeric ranges, taxonomy identifiers, and
  maximum serialized size before writing the outbox.
- No feature-extractor Lambda, model container, ECR repository, Bedrock call,
  SageMaker endpoint, GPU, or runtime model download is permitted.
- App model/version metadata is transient provenance, not an infrastructure
  deployment input and not a public campaign dimension.
- A lexical/taxonomy fallback may create a review candidate but cannot
  automatically publish a campaign.

The V1 `appFeatures` object contains exactly these fields:

| Field | V1 bound |
| --- | --- |
| `schemaVersion` | Integer `1` |
| `extractorVersion` | Non-empty UTF-8 string, at most 64 bytes |
| `languageId` | Stable `lower_snake_case` identifier, at most 64 characters |
| `taxonomyBucket` | Stable `lower_snake_case` identifier, at most 64 characters |
| `vector` | 1-384 finite numbers, each between `-1.0` and `1.0` |
| `lexicalFingerprint` | At most 32 unique lowercase 16-character hexadecimal hashes |
| `signalIds` | At most 16 unique stable identifiers |
| `indicatorIds` | At most 16 unique opaque derived identifiers; never raw indicators |
| `confidence` | Finite number between `0.0` and `1.0` |

The canonical compact JSON representation must not exceed 32 KiB. Boolean
values are not numbers. Missing or unknown fields, duplicate list values,
unsupported versions, non-finite values, malformed identifiers, dimension
mismatches, and out-of-range values fail closed. `sourceType=ocr` means only that
OCR occurred locally in the app; images and raw OCR payloads never enter the API.

`SECUR4ALL-205` owns app extraction and quality evidence. `SECUR4ALL-213` owns
the canonical feature schema, and the Lambda owner validates and forwards only
that allowlist. No application code belongs in this repository.

## Similarity and Promotion

- Candidate scoring weights are 45 percent semantic, 25 percent
  lexical/fingerprint, 20 percent tactics/taxonomy, and 10 percent bounded
  indicators.
- A score of at least 0.82 is a candidate match when there is no category
  conflict.
- Scores from 0.72 through 0.81 remain separate candidates for review.
- Scores below 0.72 have no association.
- Promotion requires at least 10 distinct contributors and measured precision of
  at least 95 percent.
- Recall must be at least 80 percent on approved English and Spanish fixtures.
- Merge, split, confirmation, and publication are never automatic.
- Threshold changes require versioned evidence.

## Privacy and Security

- Campaign participation requires explicit opt-in. Declining does not block normal
  analysis.
- Consent withdrawal immediately blocks future campaign processing and deletes
  active or unfinalized contributions within 24 hours.
- One contributor may influence one vector and at most three counted submissions
  per campaign and period.
- Campaigns and dimensions below 10 contributors are suppressed.
- V1 has exactly one named reviewer: the product owner. Shared credentials are
  prohibited.
- Every review transition requires a reason and a privacy-safe immutable audit
  item.
- IAM identity data and persistent campaign data remain separated.
- Development uses only synthetic or explicitly licensed data.
- Production requires manual privacy and security approval.

`SECUR4ALL-215` owns the privacy, security, and evidence review. Infrastructure
implements only the controls accepted through that review.

## Retention

- Active aggregation periods are 14 days, followed by a 7-day recovery window.
- Sanitized observations retain for no more than 72 hours.
- Features, contributor tokens, dedupe records, and candidates retain for no more
  than 21 days.
- Confirmed non-linkable aggregates and privacy-safe audit records retain for 400
  days.
- Transient data has no backup or PITR. Persistent aggregate-only data uses PITR.
- Period KMS HMAC keys are disabled after the recovery window and scheduled for
  deletion with the minimum permitted waiting period.

## Launch and Cost Gates

- No prohibited identity or content may appear in queues, tables, logs, metrics,
  traces, backups, or APIs.
- Consent-withdrawal and account-deletion tests must pass completely.
- Active-data deletion must complete within 24 hours.
- No campaign or dimension may publish below 10 contributors.
- English and Spanish evaluation must reach at least 95 percent precision and 80
  percent recall.
- p95 end-to-end campaign processing must complete within five minutes without
  delaying normal user analysis.
- The Dev campaign budget ceiling is $25 per month.
- The Production campaign budget ceiling is $50 per month.
- Budget alerts fire at 50, 80, and 100 percent.
- V1 provisions no OpenSearch, NAT gateway, paid VPC interface endpoints,
  provisioned concurrency, Step Functions, Global Tables, cross-Region replicas,
  or always-on compute.
- UAT and Production remain disabled until their promotion evidence is approved.

AWS Budgets is an alerting control, not a hard stop. Throughput and concurrency
caps plus the campaign kill switch are required to bound operational exposure.
