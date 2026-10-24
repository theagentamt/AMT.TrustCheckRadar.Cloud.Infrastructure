# Permanent Message AI configuration and deployment boundary

This source adds a normal default-off application configuration and a bounded
`message-consumer-ai` deployment mode. There is no fixed synthetic message,
one-use runtime reservation, temporary operator compiler or tester-specific
runtime exception. The existing two-subject Dev admission is preserved; it is
not broadened into general customer admission.

`environments/dev/message-ai.json` currently disables AI, selects no model,
qualification, secret or currency budget, and retains the existing deterministic
profile. AI=false never implies enabling a deterministic fallback. History may
remain configured while execution is paused so reconciliation can preserve
original receipt/accounting semantics. The runtime gates still determine whether
new checks can execute.

## Exact source/deployment checks

The existing manual workflow is extended, not replaced. Its legacy Message job
and preserved jobs use disjoint exact scope lists, with main/Dev/manual/revision
guards retained. Main publication runs source CI only. It cannot authenticate to
AWS, apply Terraform or open a feature gate. No workflow was dispatched here.

The normal mode captures real active unweighted aliases, current function code,
configuration and limits, same-table active maintenance, existing History and the
exact two-subject scope. For this mode it also checks both owned IAM policy sets,
role trust and absence of attached policies. Full saved-plan inventory is required;
only the two Message functions/aliases and their two owned policies may update.
All routes, identity/admission, runtime limits and unrelated resources stay exact.
Existing maintenance-only and Message/History-only modes retain their own guards.

AI activation may add only the three monetary reservation attributes to the
existing transactional `V1#CONTROL` UpdateItem boundary. The private evaluator
can read only the exact normal OpenAI secret at AWSCURRENT; other secrets,
secret mutations, other stages, storage and role chaining remain denied. URL
invocation has a separate default-deny control and is never opened by Message AI.
These are reviewed source permissions, not applied permissions.

Artifact selection uses one immutable release, exact S3 versions and hashes.
The normal publisher records SHA256 as object metadata; a server SHA256 header
is optional and must agree when present. In all cases the exact version is GET
and fully hashed before acceptance. Enabling AI additionally requires packaged
approved qualification metadata, matching evidence/cost/prompt/schema and every
contract manifest member. ZIP code is not executed by the inspector. Hashes bind
identity, not the truth of quality evidence; review remains necessary.

Apply requires the fresh complete plan to match the reviewed digest and captured
live baseline. Readback verifies actual functions, unweighted aliases, exact
configuration/limits/policies, preserved maintenance/History, then zero managed
drift. Private plans/configuration are cleaned even on failure. A green CI or
plan does not establish real model connectivity or application acceptance.

## Explicit activation holds and rollback

The current model batch is not accepted qualification and no registry entry is
created. Daily reporting readiness remains false, so the normal verifier rejects
AI-enabling plans with `AI_OPERATIONAL_REPORTING_NOT_READY`. No ongoing provider
budget is selected: the earlier ten-request/US$5 batch and one secret read are
consumed bounded authority, not standing application spending or secret access.

Future rollout needs accepted model/privacy/operational evidence, explicit model
and aggregate currency/attempt/failure/period limits, exact ongoing secret-read
and IAM approval, and a reviewed fresh Dev plan/apply. The prior one-hour e2e
permission approval cannot be revived. No secret upload or new credential is
implied by this source. No production activation is included.

A disable plan must explicitly preserve or choose the deterministic profile;
there is no automatic fallback. It disables AI access and removes the narrowly
added reader permission while preserving original receipts, provider reservations,
History, paid/trial state and complimentary access. Reconciliation never repeats
an external model call. Budget reservations are not refunded/reset by rollback.
Maintenance remains unchanged and independently continues its existing approved
retention behavior; stopping Message AI cannot restore already expired records.
Partial/uncertain applies require readback before any further action.

## Existing URL and QR path retained

Read-only metadata at 2026-10-24 05:25:24Z confirms three existing JWT routes:

- `POST /v1/url-checks/prepare`
- `POST /v1/url-checks`
- `POST /v1/url-checks/reconcile`

They target URL consumer live v9, then the existing private assessment v3 and
resolver v2. JWT scope is `aws.cognito.signin.user.admin`. URL consumer execution
and its authority gate are currently false; presence of a Web Risk secret
reference is metadata only and does not prove usable credentials/connectivity.

The retained Android contract/source routes URL-bearing QR through explicit local
Review link -> URL disclosure/review -> this same URL flow with `qr_url`
provenance. Non-URL QR stays inert/local; no separate generic QR-analysis endpoint
is introduced. No business endpoint, resolver/provider or secret-value call was
made during this readback. URL gate/IAM/provider/runtime qualification remains a
separate rollout; Message source changes do not authorize it.

## Validation state

All Python helpers pass 501 tests and 846 subtests; the CI unittest command passes
501 methods with external networking blocked. Installed boto3 matches the repository CI pin 1.43.107; Moto matches 5.2.3.
The existing compatible botocore 1.43.118 satisfies the package dependency range.
These are source checks, not live service results.

All 21 CI Terraform roots validate and all 601 cases pass with Terraform 1.12.1
and the exact locked providers. The owner-approved AWS 6.66.0, Random 3.9.1 and
boto3 1.43.107 downloads were installed only into isolated task caches/targets
from the official Registry/PyPI. Provider installation verified lock checksums;
the boto3 wheel matches its official PyPI digest. No repository lock changed,
other package was upgraded, or existing qualification environment was modified.
Backend initialization was disabled; tests use mock providers and synthetic
credentials. Exact new main CI remains required after source integration.

Formatting, helper shell syntax, campaign guardrails, Python compilation and YAML
parse pass. The focused Message 28 and preserved URL/maintenance 87 cases pass.
The independent 12-file review passed; final evidence/format review and source
publication are recorded separately. No Terraform apply, IAM/secret mutation, activation,
provider call, mobile test or qualification retry occurred.
