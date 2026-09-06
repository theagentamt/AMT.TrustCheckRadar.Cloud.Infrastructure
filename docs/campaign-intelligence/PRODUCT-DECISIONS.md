# Campaign Intelligence Product Decisions

- Story: `SECUR4ALL-202`
- Decision date: 2026-09-05
- Decision owner: Product owner

## Approved Decisions

### Taxonomy

Use one extensible canonical taxonomy with language-neutral stable identifiers,
English and Spanish display labels, and `other` and `unknown` values. Labels can
be expanded without breaking clients. Identifier removal or semantic reuse is not
allowed without a schema-major version.

### Consumers and Access

Authenticated app users receive only confirmed campaign summaries, coarse weekly
periods, stable taxonomy identifiers, localized labels, and count bands. A
separately authorized internal reviewer receives bounded aggregate details. There
is no anonymous campaign API.

Lambda implementation and AWS infrastructure access are split into separate
YouTrack stories beneath `SECUR4ALL-209` so application and Terraform ownership
remain explicit:

- `SECUR4ALL-211` owns the privacy-thresholded campaign trends Lambda.
- `SECUR4ALL-212` owns the least-privilege campaign trend API infrastructure.

### Privacy and Retention

- Campaign participation requires a separate explicit opt-in and does not block
  normal analysis when declined.
- Active aggregation periods are 14 days followed by a 7-day deletion/recovery
  window.
- Promotion requires at least 10 distinct contributors.
- One vector and at most three counted submissions per contributor, campaign, and
  period may influence statistics.
- Campaigns and dimensions below 10 contributors are suppressed.
- Public count bands are `10-24`, `25-49`, `50-99`, `100-249`, and `250+`.
- Sanitized observations retain for no more than 72 hours.
- Transient features, tokens, dedupe records, and candidates retain for no more
  than 21 days.
- Confirmed non-linkable aggregates retain for 400 days.
- Opt-out immediately blocks future processing and removes active/unfinalized
  contributions within 24 hours.
- Finalized aggregates may remain only when they contain no account-linking
  mechanism and still meet the approved threshold.
- Claims say `similar messages were submitted`; `participating accounts` is used
  only when privacy-preserving distinct counting passes the threshold.

### Model and Cost Constraints

Use a self-hosted open-source English/Spanish encoder. No third party processes
submissions, no model is downloaded at runtime, and campaign processing remains
asynchronous from user analysis. OpenSearch is excluded from V1. The Dev campaign
budget ceiling is $25 per month.

The exact model remains an ML-owner decision subject to license, provenance,
quality, memory, cold-start, and measured-cost evidence.

### Similarity and Publication

Prioritize precision because a false campaign merge is more harmful than a missed
match. Initial quality targets are at least 95 percent precision and 80 percent
recall on approved English and Spanish fixtures. No campaign is automatically
published; threshold checks and the authorized reviewer are required.

### Reviewer and Operations

V1 has exactly one named reviewer, initially the product owner. The reviewer can
review, confirm, suppress, merge, split, and perform emergency suppression. Every
transition requires a reason and a privacy-safe immutable audit item. Shared
credentials are prohibited.

V1 uses the low-fixed-cost serverless network posture: no NAT gateway and no paid
VPC interface endpoints. Dev uses synthetic or explicitly licensed data. Private
egress controls must be reassessed before Production if required by the security
review.

### Launch Gates

- No prohibited identity or content appears in campaign tables, queues, logs,
  metrics, traces, backups, or APIs.
- Consent-withdrawal and account-deletion scenarios pass completely.
- Active-data deletion completes within 24 hours.
- No campaign or dimension is published below 10 contributors.
- English and Spanish evaluation reaches at least 95 percent precision and 80
  percent recall.
- p95 campaign processing completes within five minutes without delaying user
  analysis.
- Dev campaign spend remains below $25 per month.
- Production remains disabled until UAT privacy, security, quality, abuse,
  rollback, and cost evidence is approved.

## Open Decision

The product owner must set the initial Production monthly campaign budget ceiling
before Production resources can be enabled. This does not block architecture,
contract, Dev infrastructure, or Dev implementation work.
