# Isolated Dev acceptance proposal

Planning only, September 16, 2026. No provisioning, accounts, activation or paid
calls are authorized by this document. Shared Dev remains unchanged.

## Bounded Footprint

One run in account 107827791950/us-east-1, uniquely prefixed and tagged with
RunId, Owner, Purpose and ExpiresAt, in its own Terraform state:

| Resource | Proposed maximum |
| --- | --- |
| Cognito | One dedicated pool, one public client, exactly two admin-created users |
| HTTP API | One API/stage, ten routes, native JWT authorizer; no custom domain |
| Lambda | Seven: analysis, read, mutation, lifecycle, bridge, registration, candidate access gate |
| DynamoDB | Seven on-demand tables: users, deletion ledger, bindings, entitlements, analysis abuse, History content/control; required indexes only |
| Secrets | Two: cursor signing and encrypted candidate access configuration |
| Background work | Two five-minute rules, one candidate-only stream mapping |
| Failure delivery | Up to two candidate-only SQS queues if reviewed async failure tests require them; bounded retries/retention |
| Monitoring | Up to 16 standard alarms/32 evaluated metric series, 40 custom metric series, eight log groups; no dashboard |
| Notification | One candidate SNS topic, one support email subscription, at most eight test notifications |
| IAM/artifacts | Candidate-only roles/policies; read existing immutable artifacts; separate small state prefix |

Candidate History tables retain the approved seven-day PITR configuration. No
shared data tables, user pool, routes, checkpoints or signing secret are reused.
No OpenSearch, RDS, EC2, NAT, paid model keys, provisioned concurrency, SMS, WAF,
new VPN, customer-managed KMS key, campaign pipeline or full-account finalizer.
No existing DLQ is assumed. The ceiling allows up to two queues for reviewed
EventBridge/stream failure tests; synchronous API calls do not need a DLQ.

Resource count is a proposed ceiling, not a generated/approved Terraform plan.
Any extra dependency requires a revised footprint before provisioning. Candidate
registration and profile fixture prerequisites must be confirmed by Lambda owner.
The Lambda owner recommends a bounded candidate-only transaction to establish
the two ACTIVE/ageVerified profile fixtures, then real device registration via
the candidate API. Label this synthetic setup, not signup/age-verification
acceptance. Adding real post-confirmation/age-attestation coverage would require
two more functions and a separately reviewed scope.

## Authentication Boundary

Use a separate Cognito pool with public self-signup disabled, no messaging or
post-confirmation hooks, and only two synthetic identities. Keep credentials in
Keychain and tokens in memory. This avoids shared Cognito triggers and identities.

Preserve the native HTTP API JWT authorizer: exact candidate issuer/client,
expiry and access scope. Current handlers require `authorizer.jwt.claims`; a
Lambda authorizer is not a drop-in replacement and authorizers cannot simply be
stacked. Proposed integration gate checks the already-verified subject against
exactly two configured values, the trusted gateway source IP against the test
operator's approved egress, and the run expiry. It then invokes only the approved
candidate backend for the matched route, preserving verified gateway context.

No token/body/header-selected user, caller-supplied claims, public Function URL,
arbitrary target invocation or shared-table IAM is permitted. Missing/invalid
configuration denies access. Gate caching must not outlive the run. Review and
test this adapter before deployment; it is not existing infrastructure. A fixed
egress address is needed; do not create a VPN to obtain one without approval.

Dedicated-pool authentication and the extra gate differ from shared Dev. A pass
therefore proves candidate behavior, not shared-Dev activation or signup parity.

## Incremental Cost

Budget proposal: USD 1-3 for one run of at most 24 hours; request a USD 5
planning allowance. This is an estimate, not an AWS-enforced spending cap.
No free tier/credits assumed; taxes, existing infrastructure, engineering time,
GitHub runner charges, paid models and restore/export exercises are excluded.

Assume at most 5,000 HTTP requests and 10,000 total Lambda invocations,
10,000 GB-seconds compute, 200,000 DynamoDB read units and 20,000 write units
including transactional/index amplification, 100 MB table/index data, 100 MB logs,
and 100 MB outbound responses. At most ten no-model completions per subject;
this initial scope does not test the checks_20 threshold live.

| Component | Approximate upper allowance under these assumptions |
| --- | --- |
| Lambda compute/requests + HTTP API | $0.18 |
| DynamoDB requests/storage/PITR | $0.05 |
| CloudWatch metric series, alarm metrics, logs | $0.70 |
| Two Cognito MAUs + two secrets/API calls | $0.12 |
| SNS/SQS, schedules, artifact/state access, transfer contingency | $0.25 |

The subtotal is about $1.30; the $3 planning range leaves room for bounded reruns.
Observed request/compute/log counts must be checked during the run; billing
reports arrive later. Stop new fixtures if usage exceeds the approved bounds.
Concurrency one per worker, low API throttles, bounded loops and limited DynamoDB
on-demand throughput reduce exposure but do not guarantee a dollar ceiling.

Rate basis checked on AWS public pricing pages: conservative x86 Lambda duration
$0.0000166667/GB-second plus $0.20/million invocations; HTTP API $1/million calls.
[Lambda](https://aws.amazon.com/lambda/pricing/), [API Gateway](https://aws.amazon.com/api-gateway/pricing/).
DynamoDB Standard $0.625/million write units, $0.125/million read units,
$0.25/GB-month storage and $0.20/GB-month PITR.
[DynamoDB](https://aws.amazon.com/dynamodb/pricing/).
CloudWatch uses $0.30/custom metric-month, $0.10/standard alarm metric-month,
and $0.50/GB standard log ingestion; use billable metric series, not alarm count.
[CloudWatch](https://aws.amazon.com/cloudwatch/pricing/).
Two Essentials MAUs at $0.015 each are charged monthly, not prorated to one day.
Secrets use $0.40/secret-month prorated plus $0.05/10,000 calls.
[Cognito](https://aws.amazon.com/cognito/pricing/), [Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/).

## Teardown Deadline

Infrastructure owns shutdown immediately after testing, no later than T0+24h
from the first resource creation. Set an exact UTC deadline before deployment;
do not launch unattended or unless an operator can verify cleanup. ExpiresAt tags
are inventory metadata, not automatic deletion. The proposed gate denies expired
runs; background shutdown/destroy needs a reviewed, executable runbook/workflow.

1. Stop new submissions. Clear the two synthetic subjects and verify physical
   content purge, replay redaction and terminal erasure jobs; preserve only
   content-free evidence. Do not confuse logical clear with physical completion.
2. Disable candidate routes, rules and stream mapping; revoke test sessions.
3. Apply a reviewed candidate-only destroy plan, including the two users/pool,
   tables, functions, logs, alarms, topic/subscription, roles and signing secret.
   Record any cleanup failure without claiming acceptance or successful teardown.
4. Compare service inventories with Terraform state and the recorded resource
   manifest; verify no active candidate endpoints/workers/billable infrastructure.
   Check scheduled-deletion secrets and backup inventory separately. Remove only
   the candidate Keychain entries after the credential-dependent tests finish.

AWS can retain a SYSTEM backup for 35 days when a PITR table is deleted, at no
additional cost. Record its disposition/expiry rather than claiming all copies
vanish in 24 hours. Secrets scheduled for deletion are inaccessible and unbilled
during their recovery window. Residual synthetic backups, secret recovery state
and redacted Terraform state must be explicitly accounted for in the teardown.
[DynamoDB backup behavior](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery_Howitworks.html),
[Secrets deletion](https://docs.aws.amazon.com/secretsmanager/latest/userguide/manage_delete-secret.html).

## Local Work Without AWS

Lambda owner can implement and run offline tests for manifest/hash validation,
mock Keychain reads and failure redaction, candidate-only resource guards,
paging/cursor tamper and tenant isolation, binding/bootstrap, deterministic
RESULT_READY-clear-recovery, quota/consumption uniqueness and reset-generation
semantics. Fake AWS/HTTP clients must prove plan mode and failures make zero
network calls and never print secrets. No live credentials are needed.
Add a rollback-aware transaction fake; recorded transaction arrays alone do not
prove atomicity. Verify every candidate create target has a teardown target,
reject shared-resource names, and scan evidence values as well as field names
for secret/subject leakage. Keychain tests use an in-memory provider, never real
credentials. The no-model fixture must be locally proven and no usable model
credentials may be supplied to the candidate; IAM alone does not prevent a call
to a third-party model API. Keep AWS model-invoke permissions absent too.

Infrastructure can add mocked Terraform tests for separate state/resources,
exact candidate IAM, issuer/client/subject/egress/expiry gates, quotas, disabled
initial schedules and candidate-only destroy inventory. Contract fixtures should
remain byte-identical to the pinned V1 contract. These tests improve readiness
but cannot establish actual JWT enforcement, IAM, scheduled cleanup, physical
purge or email delivery. This request prepares the plan; source changes remain
coordinated with their respective repository owners.
