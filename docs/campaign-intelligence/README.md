# Campaign Intelligence Architecture

This directory contains the proposed AWS architecture package for
`SECUR4ALL-202`. It defines the infrastructure boundary that must be approved
before `SECUR4ALL-203` provisions resources.

Status: **Proposed v1**

No document in this directory authorizes a Dev, UAT, or Production deployment.
The product/privacy, backend-contract, ML, and security handoffs listed below
must be returned before this package becomes accepted.

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

## Decision Summary

| Decision | Proposed v1 |
| --- | --- |
| Active aggregation period | 14 days, aligned to UTC period boundaries |
| Finalization recovery period | 7 days after period close |
| Promotion threshold | At least 10 distinct contributor tokens |
| Contributor influence | One vector and at most three counted submissions per campaign and period |
| Public small-cell rule | Suppress dimensions and campaigns below 10 contributors |
| Public counts | Count bands, not exact contributor counts |
| Sanitized observation retention | Delete after feature handoff plus 24 hours; hard TTL of 72 hours |
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

## Ownership

This repository owns AWS topology, Terraform stack contracts, encryption, IAM,
retention enforcement, operational controls, environment isolation, and cost
guardrails.

The following work is explicitly outside this repository:

- Product/privacy approval of consent language, retention, cohort size,
  small-cell policy, and claims.
- Canonical JSON Schema or OpenAPI definitions and service implementation.
- Taxonomy localization and application presentation.
- Encoder selection, similarity calibration, quality evaluation, and clustering
  implementation.
- Android and iOS implementation.

Those owners must return versioned artifacts to `SECUR4ALL-202`. This repository
will review them against the infrastructure contract before acceptance.

## Approval Gates

1. Product/privacy approves the numeric policy and collection/deletion language.
2. Backend owners publish canonical schemas and English/Spanish fixtures.
3. ML owners publish model provenance and calibrated quality targets.
4. Security approves the threat model and re-identification review.
5. Infrastructure records the accepted ADR and only then begins
   `SECUR4ALL-203`.
