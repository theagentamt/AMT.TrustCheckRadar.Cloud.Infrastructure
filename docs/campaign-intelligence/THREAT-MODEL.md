# Campaign Intelligence Threat Model

Status: **Initial proposed review** for `SECUR4ALL-202`

## Protected Assets

- Source message and screenshot confidentiality.
- Account identity and participation privacy.
- Temporary contributor-token unlinkability after period close.
- Campaign aggregate integrity and publication correctness.
- Environment isolation and model artifact integrity.
- Consent withdrawal and account-deletion guarantees.

## Threats and Required Controls

| Threat | Required control | Verification evidence |
| --- | --- | --- |
| Direct identity enters campaign data | Publisher allowlist serialization; schema rejects unknown fields; IAM separation | Forbidden-field contract tests and sampled encrypted table inspection |
| Identity leaks through logs/traces | Structured allowlist logger; no payload capture; low-cardinality metrics | Log canary tests and CloudWatch query showing zero canary matches |
| Linkage through stable pseudonyms | Environment- and period-specific KMS HMAC keys; seven-day recovery then disable/delete | Rotation, disablement, cross-period, and cross-environment tests |
| Sparse cohort reveals a participant | Minimum cohort 10; small-cell suppression; public count bands | API negative tests for cohorts and dimensions below 10 |
| Model inversion recovers source text | No individual vectors in durable storage; clipped aggregate centroid only after threshold; re-identification review | Red-team reconstruction evaluation before UAT approval |
| Rare indicators enable linkage | Indicator allowlist, frequency threshold, truncation, and authorized review | Rare-indicator suppression fixtures |
| One account manufactures a trend | One contributor vector and three counted submissions per campaign/period | Repeated-account poisoning tests |
| Coordinated accounts poison clusters | Quality/confidence gate, authorized review, rate/abuse signals outside persistent campaign data | Synthetic coordinated-poisoning evaluation |
| Replay or duplicate delivery inflates counts | Transactional random event ID, conditional writes, dedupe retention, record versions | Stream/queue replay and concurrent-write tests |
| Deletion races with processing | Tombstone-before-delete, consumers re-read current state, finalization blocked during cleanup | Concurrent deletion/feature/cluster time-travel tests |
| Queue or backup resurrects deleted data | Opaque queue IDs; no transient backups; missing records are no-op | DLQ replay and restore tests |
| Reviewer publishes unsafe cluster | Separate reviewer role, state machine, reason codes, append-only safe audit | Authorization and invalid-transition tests |
| Runtime downloads altered model | Immutable digest, scanning/provenance, no runtime internet dependency | ECR policy and egress-negative tests |
| Cross-environment leakage | Separate resources/keys/roles/state and explicit source ARN conditions | IAM simulation and Dev/UAT/Production negative tests |
| Compromised function pivots | Minimal role per stage, reserved concurrency, no wildcard data/KMS permissions | Effective-policy assertions and failure injection |
| Cost exhaustion | Queue depth/concurrency bounds, DynamoDB on-demand alarms, budget alarms, bounded candidate retrieval | Burst/load test and alarm evidence |

## Residual Risks Requiring Handoff

- Product/privacy must decide whether cohort 10 and the proposed count bands are
  adequate for the intended claims and jurisdictions.
- ML/security must quantify inversion and membership-inference risk for the chosen
  encoder and centroid method.
- Backend/security must prove the completed-analysis event is committed once and
  that consent state cannot be forged or become stale during replay.
- Account-deletion owners must define completion semantics when lifecycle cleanup
  is delayed or an AWS dependency is unavailable.
- Operations must define authorized emergency suppression without exposing or
  exporting source records.

Production remains blocked until each residual risk has a named owner, evidence,
and an approved disposition in YouTrack.
