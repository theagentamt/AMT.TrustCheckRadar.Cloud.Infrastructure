# Campaign Intelligence Architecture

This directory contains the proposed AWS architecture package for
`SECUR4ALL-202`. It defines the infrastructure boundary that must be approved
before `SECUR4ALL-203` provisions resources.

Status: **Dev campaign pipeline active; authenticated app validation pending**

The approved Dev deployment is limited to the resources recorded below. This
document does not authorize worker activation or promotion to UAT or Production;
those actions remain subject to the deployment gates.

## Documents

- [ADR-001: Privacy Boundary and Lifecycle](ADR-001-privacy-boundary-and-lifecycle.md)
  records the proposed privacy, retention, pseudonym, environment, and
  publication decisions.
- [Infrastructure Contract](INFRASTRUCTURE-CONTRACT.md) defines stack ownership,
  resource capabilities, access patterns, message envelopes, IAM boundaries,
  and deployment gates.
- [Data Flow](DATA-FLOW.md) identifies every allowed transient and durable copy.
- [Threat Model](THREAT-MODEL.md) records the initial abuse and privacy analysis
  and required controls.
- [Cost Model](COST-MODEL.md) estimates fixed and usage-based spend and defines
  the V1 budget guardrails.
- [Story Ownership](STORY-OWNERSHIP.md) identifies which campaign stories own
  infrastructure changes and which require application-team handoff.
- [Product Decisions](PRODUCT-DECISIONS.md) records the product-owner approvals
  for the V1 baseline.
- [Implementation Rules](IMPLEMENTATION-RULES.md) is the normative rule set for
  contracts, taxonomy, app feature input, similarity, privacy, retention, launch, and
  cost validation.
- [Deployment Gates](DEPLOYMENT-GATES.md) records the exact inputs, flag changes,
  ordering, tests, and promotion approvals required to activate an environment.

## Infrastructure Status

The `campaign-data`, `campaign-processing`, and `campaign-api` Terraform stacks
are implemented with environment gates and native contract tests. Dev data
resources, source publishing, background workers, lifecycle schedules, and the
authenticated review/trend APIs are active. The processing kill switch is off in
Dev; UAT and Production remain disabled.

The server-side feature-extractor image is retired by product decision. Campaign
processing now requires app-produced, versioned features to pass through the
sanitized analysis/outbox contract before the publisher and clustering workers
are enabled. See [Deployment Gates](DEPLOYMENT-GATES.md) for the current handoff
state.

## Decision Summary

| Decision | Proposed v1 |
| --- | --- |
| Active aggregation period | 14 days, aligned to UTC period boundaries |
| Finalization recovery period | 7 days after period close |
| Promotion threshold | At least 10 distinct contributor tokens |
| Contributor influence | One vector and at most three counted submissions per campaign and period |
| Public small-cell rule | Suppress dimensions and campaigns below 10 contributors |
| Public counts | Count bands, not exact contributor counts |
| Sanitized observation retention | Delete after clustering handoff plus 24 hours; hard TTL of 72 hours |
| Features, tokens, dedupe, and candidates | Period end plus 7 days; maximum 21 days |
| Confirmed aggregates | 400 days, then delete unless a reviewed exception exists |
| Queue payloads | Opaque event identifiers and control metadata only |
| Contributor pseudonym | Environment- and period-specific AWS KMS HMAC token |
| Transient backups | Disabled; restore must never resurrect transient personal data |
| Persistent backups | DynamoDB PITR for aggregate-only data |
| Environments | Separate tables, queues, keys, roles, logs, state, and artifact deployment |
| Vector search | Explicitly excluded from V1; reconsider only in V2 or later |
| Initial environments | Dev only; UAT and Production disabled until promotion |
| Target Dev pilot cost | $5-$8/month at up to 10,000 eligible scans/month |
| Monthly budget ceilings | Dev $25; Production $50; alerts at 50, 80, and 100 percent |

## Ownership

This repository owns AWS topology, Terraform stack contracts, encryption, IAM,
retention enforcement, operational controls, environment isolation, and cost
guardrails.

The following work is explicitly outside this repository:

- Product/privacy approval of consent language, retention, cohort size,
  small-cell policy, and claims.
- Canonical JSON Schema or OpenAPI definitions and service implementation.
- Taxonomy localization and application presentation.
- App feature extraction, similarity calibration, quality evaluation, and
  clustering implementation.
- Android and iOS implementation.

Those owners must return versioned artifacts through `SECUR4ALL-213`,
`SECUR4ALL-214`, and `SECUR4ALL-215`. This repository will review them against the
infrastructure contract before acceptance.

## Approval Gates

1. Product/privacy approves the numeric policy and collection/deletion language.
2. `SECUR4ALL-213` publishes canonical schemas and English/Spanish fixtures.
3. `SECUR4ALL-205` and `SECUR4ALL-214` publish the app feature contract and
   calibrated quality evidence.
4. `SECUR4ALL-215` approves the threat model, re-identification review, and
   evidence plan.
5. Infrastructure records the accepted ADR and only then begins
   `SECUR4ALL-203`.
