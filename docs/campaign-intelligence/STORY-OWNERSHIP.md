# Campaign Intelligence Story Ownership

This matrix keeps AWS infrastructure work in this repository and prevents the
same resources from being independently designed in downstream Lambda or client
stories.

## Classification

| Story | Infrastructure classification | Work owned by this repository | Required handoff |
| --- | --- | --- | --- |
| `SECUR4ALL-202` | Shared architecture; no deployment | AWS data flow, trust boundaries, retention enforcement, KMS lifecycle, DynamoDB access patterns, stack contract, threat model, and cost guardrails | Product decisions are approved; `SECUR4ALL-213` through `SECUR4ALL-215` own the remaining technical handoffs |
| `SECUR4ALL-203` | Primary infrastructure implementation | All V1 tables, indexes, KMS keys and policies, clustering queue/DLQ, Lambda resource shells, event-source mappings, schedules, IAM, logs, metrics, alarms, budgets, state outputs, environment flags, and Terraform tests | Immutable Lambda artifacts and accepted contracts |
| `SECUR4ALL-204` | Infrastructure consumer | No independent resource design after `SECUR4ALL-203`; only contract-driven adjustments to publisher wiring, permissions, configuration, alarms, and immutable release references | Lambda team owns observation-publisher code, sanitization, consent evaluation, idempotency behavior, and tests |
| `SECUR4ALL-205` | App implementation handoff; no AWS runtime | Remove and prohibit server feature infrastructure; validate only the returned feature contract against storage, privacy, and transport bounds | Android/app team owns multilingual feature extraction, versioning, platform tests, provenance, and quality evidence; Lambda team owns strict validation and forwarding |
| `SECUR4ALL-206` | Infrastructure consumer | No independent resource design after `SECUR4ALL-203`; only contract-driven table/index, queue mapping, IAM, throughput-cap, concurrency, and alarm adjustments | Lambda/ML team owns clustering, scoring, concurrency/idempotency logic, centroid handling, and quality tests |
| `SECUR4ALL-207` | Shared integration, primarily application logic | Lifecycle schedule, KMS lifecycle permissions, deletion invocation boundary, TTL configuration, reconciliation alarms, and runbook wiring are provisioned by `SECUR4ALL-203` | Lambda/account-deletion teams own purge, recomputation, consent withdrawal, key-retirement orchestration, repair logic, and tests |
| `SECUR4ALL-208` | Shared implementation | Internal review route/integration, separate authorization role/scope, aggregate/audit access policies, throttling, structured log groups, and transition alarms | Backend/product teams own review workflow, state-transition logic, localized descriptions, reason codes, and reviewer experience |
| `SECUR4ALL-209` | Shared integration parent | Coordinates the accepted API contract, Lambda artifact, infrastructure deployment, client handoff, dashboards, and end-to-end acceptance | Implementation is split between `SECUR4ALL-211` and `SECUR4ALL-212`; product/client teams own localized presentation and consumption |
| `SECUR4ALL-210` | Shared validation gate; normally no permanent runtime resources | Terraform/security assertions, effective IAM review, environment-isolation tests, alarm and dashboard evidence, load/cost measurements, rollback proof, and removal of temporary test resources | ML, privacy, security, backend, and QA owners provide quality, re-identification, abuse, deletion, and go/no-go evidence |
| `SECUR4ALL-211` | Lambda implementation handoff | No application code in this repository; infrastructure validates the returned immutable artifact and contract | Lambda team owns the privacy-thresholded trends handler, schemas, filters, localization, pagination, suppression, and tests |
| `SECUR4ALL-212` | Primary API infrastructure implementation | Environment trend route, JWT authorizer, Lambda deployment/integration, aggregate-only IAM, throttling, concurrency, logs, alarms, outputs, smoke tests, and environment flags | Consumes the immutable artifact and canonical contract from `SECUR4ALL-211` |
| `SECUR4ALL-213` | Backend/API architecture handoff | Review returned contracts for transport, storage, IAM, encryption, lifecycle, and environment compatibility | Backend/API team owns canonical JSON Schema or OpenAPI artifacts, bilingual taxonomy fixtures, examples, and compatibility tests |
| `SECUR4ALL-214` | App/ML quality handoff | Validate returned feature bounds and quality evidence against the infrastructure contract; no image or runtime resources | App/ML team owns extraction versioning, calibration, quality fixtures, platform benchmarks, and similarity evidence |
| `SECUR4ALL-215` | Security/privacy/QA handoff | Supply infrastructure controls and evidence for review; no separate runtime resources | Security, privacy, product, and QA own threat-model approval, re-identification review, test evidence plan, and signoff |

## Infrastructure Execution Set

The stories requiring planned work in this repository are:

1. `SECUR4ALL-202` for infrastructure architecture and constraints.
2. `SECUR4ALL-203` for the complete V1 pipeline resource foundation.
3. `SECUR4ALL-208` for internal review and publication-control infrastructure.
4. `SECUR4ALL-209` for end-to-end trend API integration and acceptance.
5. `SECUR4ALL-210` for infrastructure validation and promotion evidence.
6. `SECUR4ALL-212` for trend API infrastructure implementation.

`SECUR4ALL-204` through `SECUR4ALL-207` consume the resources created by
`SECUR4ALL-203`. They do not get separate Terraform implementations unless an
accepted contract change requires one. This keeps resource ownership centralized
and prevents IAM, queues, tables, schedules, and alarms from being split across
application stories.

## Delivery Order

```text
SECUR4ALL-202 architecture approval
  -> SECUR4ALL-213 contracts and taxonomy handoff
  -> SECUR4ALL-205/214 app feature and calibration handoff
  -> SECUR4ALL-215 privacy, security, and evidence approval
  -> SECUR4ALL-203 Dev infrastructure
  -> SECUR4ALL-204 through SECUR4ALL-207 application artifacts and integration
  -> SECUR4ALL-208 review controls
  -> SECUR4ALL-211 Lambda artifact
  -> SECUR4ALL-212 trend API infrastructure
  -> SECUR4ALL-209 end-to-end acceptance and dashboards
  -> SECUR4ALL-210 UAT validation and go/no-go evidence
```

OpenSearch is not part of any V1 story. It may be proposed only as a separately
approved V2-or-later story after the thresholds in the architecture ADR are met.
