# Isolated recovery clarification candidate

This root prepares the infrastructure boundary for SECUR4ALL-235 / ATCR-121.
Every checked-in environment is disabled. It creates no endpoint or provider
activation, and this source change performs no AWS deployment.

## Provisioning boundary

Only a version-pinned Dev candidate in `us-east-1`, account `107827791950`, may be
provisioned. UAT/production provisioning is rejected. Independent backend key:
`trustcheckradar/dev/recovery-consumer.tfstate`. Main-only CI validates this root;
the automatic broad deployment workflow explicitly excludes it. Manual helper
support does not imply approval of an apply or state change.

Two immutable packages from the same release are required: `recovery_consumer.zip`
and `recovery_evaluator.zip`, each with an exact S3 object version and SHA256.
Terraform handlers are `recovery_consumer.app.lambda_handler` and
`recovery_evaluator.app.lambda_handler`; package verification must import and invoke
these exact paths, not just the compatibility `app.py` shim.

Both use Python 3.14 ARM64, 256 MiB and reserved concurrency two. Consumer/evaluator
timeouts are 29/23 seconds; the internal evaluator deadline is at most 18 seconds.
Asynchronous retries are disabled. A synchronous timeout does not prove that
downstream work stopped; reconcile the original logical check.

Runtime selection was checked against the [AWS supported-runtime documentation](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)
on 2026-09-21: Python 3.14 is the latest generally available Python runtime;
Python 3.15 is listed as a public preview outside Lambda SLA/technical support.
This follows the owner's latest-supported-runtime preference using the GA release.

## Permissions and storage

The consumer reuses the existing account/device/deletion fences, V1 authority
table and exact current HMAC secret. Authority reads are fenced to `V1#*` keys;
mutations require transactions. It invokes only its private recovery evaluator's
`live` alias. It cannot enumerate/delete ledger records; existing lifecycle workers
own expiry/deletion. No new ledger, incident table, secret value or content bucket
is provisioned.

The evaluator can write its own logs only. It explicitly denies DynamoDB, Secrets
Manager, S3, SSM, downstream Lambda invocation and role chaining. No message or URL
assessment invocation is needed. Future qualified-provider activation must review
the exact existing provider secret permission and remove the conflicting blanket
deny only as narrowly required. An added Allow cannot override an explicit Deny.
The evaluator must never receive the authority key or table permissions.

The runtime must enforce the approved usage-only receipt policy: seven-day existing
retention, no descriptions or exposure/action IDs. Terraform cannot prove payload
minimization; runtime tests and live qualification must verify it. Fourteen-day
operational log retention follows the existing baseline, with approved metadata
only—no request/model content, identifiers, secrets or exception payloads.

## Exact disabled configuration

Both runtimes receive:

| Variable | Value |
| --- | --- |
| `RECOVERY_POLICY_VERSION` | `recovery-clarification-2026-09-21-v1` |
| `RECOVERY_POLICY_APPROVAL_SHA256` | `173132b8d5a16d3d5a8ccdbc7355a631f8384634945772993200a3559c89da72` |
| `RECOVERY_PLAYBOOK_VERSION` | `recovery-playbook-1.0` |

The consumer has `RECOVERY_CONSUMER_ENABLED=false`, `AUTHORITY_ENABLED=false`,
`RECOVERY_PROVIDER_CIRCUIT_OPEN=true`, existing identity/Cognito/authority settings
and only its private evaluator alias. The evaluator has
`RECOVERY_EVALUATOR_ENABLED=false`, `RECOVERY_AI_ENABLED=false` and
`RECOVERY_AI_QUALIFIED=false`. Disabled bootstrap must return before requiring
provider settings or doing network/ledger work.

No model, provider credential, qualification ID, output-token/time budget or
provider-attempt window is supplied. Before activation, validate the exact
`RECOVERY_PROVIDER_WINDOW_SECONDS`, `RECOVERY_PROVIDER_ATTEMPTS_PER_WINDOW`,
`RECOVERY_PROVIDER_FAILURES_PER_WINDOW`, model/qualification, maximum output tokens
(at most 512) and AI timeout (at most 10,000 ms) against the qualified adapter and
overall deadline. These attempt/cost controls differ from the user's completed-check
allowance. Do not invent a production budget in an infrastructure default.

Shared-authority activation also requires the validated timing/rate configuration:
`OPERATION_VALIDITY_SECONDS`, `WORKER_SETTLEMENT_SECONDS`,
`RECONCILIATION_SECONDS`, `RECEIPT_RETENTION_SECONDS`, `COUNTER_RETENTION_SECONDS`,
`ATTEMPT_WINDOW_SECONDS`, `ATTEMPTS_PER_WINDOW` and `MAX_INFLIGHT`. This inactive
root deliberately supplies none of these. The future values must satisfy the
authority's cross-field invariants and approved seven-day receipt policy; a ready
deployment must not rely on implicit defaults or treat missing configuration as
unlimited access.

## Operations and activation evidence

Six native Lambda alarms cover errors, throttles and duration via the existing
confirmed `support@andmorethings.com` SNS path. Alarm dimensions contain only the
function name. Dev warning settings are one error/throttle in five minutes and
duration within three seconds of the hard timeout. They are engineering settings,
not measured production SLOs. Missing metrics do not establish service health.
No new alert subscription or confirmation is created.

These alarms do not count successful logical checks, discover provider failures
returned in HTTP200, calculate cost, deduplicate attempts or supply the daily
report. `daily_reporting_ready=false` remains explicit.

The future authenticated routes are prepare, submit and reconcile under
`/v1/recovery-clarifications`. This candidate provisions no API Gateway integration,
Lambda URL, public invocation grant, schedule or event source. Before adding them,
qualify real JWT/device/account fences, the recovery-specific authority scope,
usage-only reconciliation, completed-only settlement, cancellation/lost responses,
provider projection and bilingual adversarial model behavior. User approval of
the policy is not model qualification or provider activation.

Prepare a concrete version-pinned manual Dev plan and rollback after package and
Android contract qualification. A mocked Terraform apply is never evidence that
resources were deployed. No existing message/URL routes or IAM roles are modified.

## Local validation

Run `terraform init -backend=false`, `terraform validate` and `terraform test` in
this root, plus the shell-helper tests. Tests mock AWS, exercising no-op defaults,
inactive private functions, IAM separation, exact policy pins, existing support
alarms, wrong environment/account, mutable/mixed/unrelated artifacts and secret
scope rejection. Keep main-only CI triggers unchanged; run local checks before
publishing `release-V01` work.
