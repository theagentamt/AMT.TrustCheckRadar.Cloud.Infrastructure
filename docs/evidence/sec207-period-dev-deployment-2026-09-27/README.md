# SECUR4ALL-207 Dev deployment evidence

This directory records the reviewed September 27, 2026 Dev rollout. JSON files
contain configuration metadata, hashes, fixed reason/count diagnostics and
synthetic fixture references. Raw application rows, credentials and HTTP account
content were not retained. Evidence labels describe the performed scope.

| Stage | Evidence | Meaning |
| --- | --- | --- |
| Build/publication | private-artifact-publication.json, lambda-final-local-audit.json | Immutable private S3 packages, production9147 and separate fixture/documentation head8d4; not public Git integration |
| Paused boundary | eight-writers-paused.json, pre-apply-policy-readback.json | Exact installed writers/roles and reviewed drain interval before bootstrap |
| Candidate review | bootstrap-manifest-candidate.json, review-inventory-candidate.json, assessment.json, independent-candidate-review.json | Bounded full strong snapshot plus external source/resource/policy review; candidates are not self-approval |
| External approval | bootstrap-plan.json, external-approval.json, external-operator-review.json | Exact reviewed 16-action conditional plan, serialized privileged-writer boundary and source-bound inventory |
| Apply/readback | apply-intent.json, apply-result.json, expected-readback.json, independent-bootstrap-readback.json, independent-operator-readback.json | Durable intent, acknowledgment and independent exact bounded post-snapshot match |
| Terraform phases | staged-plans.json | Reviewed plan hashes for pause, closed install, scope restoration and guarded retirement activation; no resource replacement |
| Installed runtime | restored-runtime-smoke.json, final-runtime-config.json | Eight source/configuration matches and two identity-free handler checks; export stays disabled, scoped deletion stays unchanged |
| Scheduled startup | scheduled-first-observation.json, independent-scheduled-runtime.json | Actual scheduled heartbeats/progress and initial full-pass alert; no claim of completed aggregate sweep at that time |
| Validation | local-validation.json, final-no-drift.json | Local test outcomes and final persisted configuration matching actual deployed state |
| Retained copies | retention-control-plane-before.json, retention-operations.json | Current bounded metadata observations; no proof of historical or external-copy absence |

The raw Terraform plans/state and credentials remain private. Saved-plan hashes
allow correspondence without publishing state. Do not replay a bootstrap plan or
copy Dev inventory to another environment. Current record deadlines were never
reset and application keys were not retired early. The original retired1478 row
is preserved as historical metadata, not a newly proved erasure.

Follow docs/CAMPAIGN-PERIOD-OPERATIONS.md and the final acceptance page. Any later
full-pass continuation evidence must identify explicit operator invocations
separately from genuine scheduled ticks and natural alarm transitions. Topic-level
SNS delivery is not verified individual inbox receipt.

General research ingestion, account export, UAT/Production and physical testing
remain outside this activation. Later release execution belongs to SECUR4ALL-330,
native restoration/reopening to SECUR4ALL-245 and Android physical cases to ATCR-148.
