# Campaign Intelligence Story Ownership

This matrix keeps AWS infrastructure work in this repository and prevents the
same resources from being independently designed in downstream Lambda or client
stories.

## Classification

| Story | Infrastructure classification | Work owned by this repository | Required handoff |
| --- | --- | --- | --- |
| `SECUR4ALL-202` | Shared architecture; no deployment | AWS data flow, trust boundaries, retention enforcement, KMS lifecycle, DynamoDB access patterns, stack contract, threat model, and cost guardrails | Product/privacy decisions, canonical schemas, ML design, and security approval |
| `SECUR4ALL-203` | Primary infrastructure implementation | All V1 tables, indexes, KMS keys and policies, queues/DLQs, ECR, Lambda resource shells, event-source mappings, schedules, IAM, logs, metrics, alarms, budgets, state outputs, environment flags, and Terraform tests | Immutable Lambda/container artifacts and accepted contracts |
| `SECUR4ALL-204` | Infrastructure consumer | No independent resource design after `SECUR4ALL-203`; only contract-driven adjustments to publisher wiring, permissions, configuration, alarms, and immutable release references | Lambda team owns observation-publisher code, sanitization, consent evaluation, idempotency behavior, and tests |
| `SECUR4ALL-205` | Infrastructure consumer | No independent resource design after `SECUR4ALL-203`; only contract-driven ECR, Lambda sizing, queue mapping, IAM, timeout, concurrency, and alarm adjustments | ML/Lambda team owns model selection, image contents, redaction, feature extraction, provenance evidence, and quality tests |
| `SECUR4ALL-206` | Infrastructure consumer | No independent resource design after `SECUR4ALL-203`; only contract-driven table/index, queue mapping, IAM, throughput-cap, concurrency, and alarm adjustments | Lambda/ML team owns clustering, scoring, concurrency/idempotency logic, centroid handling, and quality tests |
| `SECUR4ALL-207` | Shared integration, primarily application logic | Lifecycle schedule, KMS lifecycle permissions, deletion invocation boundary, TTL configuration, reconciliation alarms, and runbook wiring are provisioned by `SECUR4ALL-203` | Lambda/account-deletion teams own purge, recomputation, consent withdrawal, key-retirement orchestration, repair logic, and tests |
| `SECUR4ALL-208` | Shared implementation | Internal review route/integration, separate authorization role/scope, aggregate/audit access policies, throttling, structured log groups, and transition alarms | Backend/product teams own review workflow, state-transition logic, localized descriptions, reason codes, and reviewer experience |
| `SECUR4ALL-209` | Major infrastructure integration | Environment-specific trend routes on the existing custom domains, JWT authorization, Lambda integration, least-privilege reads, throttling, cache controls where justified, dashboards, alarms, outputs, and Terraform tests | Backend team owns API handlers/OpenAPI; product/client teams own localized presentation and consumption |
| `SECUR4ALL-210` | Shared validation gate; normally no permanent runtime resources | Terraform/security assertions, effective IAM review, environment-isolation tests, alarm and dashboard evidence, load/cost measurements, rollback proof, and removal of temporary test resources | ML, privacy, security, backend, and QA owners provide quality, re-identification, abuse, deletion, and go/no-go evidence |

## Infrastructure Execution Set

The stories requiring planned work in this repository are:

1. `SECUR4ALL-202` for infrastructure architecture and constraints.
2. `SECUR4ALL-203` for the complete V1 pipeline resource foundation.
3. `SECUR4ALL-208` for internal review and publication-control infrastructure.
4. `SECUR4ALL-209` for trend API and dashboard infrastructure.
5. `SECUR4ALL-210` for infrastructure validation and promotion evidence.

`SECUR4ALL-204` through `SECUR4ALL-207` consume the resources created by
`SECUR4ALL-203`. They do not get separate Terraform implementations unless an
accepted contract change requires one. This keeps resource ownership centralized
and prevents IAM, queues, tables, schedules, and alarms from being split across
application stories.

## Delivery Order

```text
SECUR4ALL-202 architecture approval
  -> SECUR4ALL-203 Dev infrastructure
  -> SECUR4ALL-204 through SECUR4ALL-207 application artifacts and integration
  -> SECUR4ALL-208 review controls
  -> SECUR4ALL-209 trend API and dashboards
  -> SECUR4ALL-210 UAT validation and go/no-go evidence
```

OpenSearch is not part of any V1 story. It may be proposed only as a separately
approved V2-or-later story after the thresholds in the architecture ADR are met.
