# Governed V1 message candidate

SECUR4ALL-242 supplies the isolated infrastructure dependency for ATCR-120 and
SECUR4ALL-190/228/229/230. This root can provision the inactive Dev runtimes and
the three authenticated message routes without activating message processing.
Provisioning, rules-only engineering qualification and later qualified AI are
separate gates. The checked-in Dev configuration installs the candidate while
all execution gates remain disabled; UAT and production remain disabled.

## Runtime and trust boundaries

- Python 3.14 ARM64 `message-consumer` invokes only `message-evaluator:live`.
  It reuses the existing V1 HMAC key ring, authority ledger, account/device/deletion
  fences and transactional `V1#*#*` mutations. There is no second allowance ledger,
  duplicate recovery worker, new secret container or Terraform-managed key value.
- Python 3.14 ARM64 `message-evaluator` can invoke only the existing private
  `url-assessment:live` for explicitly reviewed targets. Its role denies DynamoDB,
  Secrets Manager, S3, SSM and role chaining. Initial Android submission withholds
  links and declares that limitation; sanitized origins never authorize full URL
  disclosure. No model credential or model-provider permission is provisioned.
- Runtime entry points are `message_consumer.app.lambda_handler` and
  `message_evaluator.app.lambda_handler`. Both artifacts must come from one exact
  source commit, with an S3 object version and SHA-256; handlers must be included
  with their package paths and shared dependencies.
- Consumer/evaluator timeouts are 29/23 seconds, with reserved concurrency two
  each and asynchronous retries disabled. Internal call deadlines must fit those
  envelopes. A synchronous timeout may leave downstream work running; the ledger
  must reconcile the original identity rather than invoke again automatically.
- Consumer, evaluator and authority flags remain false unless the rules-only
  engineering gate is deliberately enabled for exact synthetic Dev subjects. The
  provider circuit remains open while inactive. Policy/version and approval SHA
  are pinned to the owner-approved 2026-09-20 message rubric. Explicit aggregate
  attempt/failure/window limits are mandatory for engineering activation and stay
  separate from the 200-completed-check customer allowance.
- The aggregate provider circuit uses only the shared authority row
  `PK=V1#CONTROL, SK=MESSAGE_PROVIDER_BUDGET`. Consumer IAM can transactionally
  update only its record type, revision, window, attempt and failure fields; the
  permission cannot write another control row or perform a non-transactional
  update.
- Fourteen-day operational log retention follows the existing runtime baseline.
  The Lambda code must emit only approved metadata; no request/response payloads,
  replaced values, URLs, proof, credentials or exception payloads. Seven-day
  minimized receipts use the shared authority lifecycle, not this log policy.

## Integration and activation gates

State is isolated at `trustcheckradar/dev/message-consumer.tfstate`. The provider
is restricted to Dev account 107827791950. Inputs are exact environment-scoped
same-account dependencies. UAT/production provisioning is rejected. CI validates
this root, and the automatic environment deployment excludes it. Installation is
available only through the manually dispatched, main-only **Deploy infrastructure**
workflow with `deployment_scope=message-consumer`.

Before provisioning, pin the reviewed Lambda artifact pair, validate the actual
Android contract against handler responses, supply the exact existing Dev API and
shared JWT authorizer, and review the workflow's saved Dev plan. Applying requires
the exact plan digest emitted for the same full `main` revision. The verifier
downloads both exact S3 object versions and checks their SHA-256 values before it
permits an apply. Provisioning creates
only `POST /v1/message-checks/prepare`, `POST /v1/message-checks`, and
`POST /v1/message-checks/reconcile`; every route requires the existing Cognito JWT
scope and invokes the pinned `message-consumer:live` alias. Disabled handlers
return a fixed 503 response and cannot reach authority or providers.

Rules-only engineering activation additionally requires one to three exact
synthetic Cognito subjects, explicit seven-day-bounded authority horizons and an
aggregate provider budget. It closes the circuit only for candidate.1. Candidate.2
and candidate.3 remain unavailable because AI flags stay false and evaluator IAM
continues to deny every Secrets Manager action.

The first connected SECUR4ALL-230 qualification narrows this further to exactly
one synthetic subject. Dispatch the registered workflow with
`deployment_scope=message-consumer-engineering`. The subject comes from the
protected Dev environment secret `MESSAGE_ENGINEERING_SUBJECTS_JSON`; it is not
committed or printed. The transition verifier permits only coordinated updates to
the two immutable runtimes and their `live` aliases, requires the exact reviewed
plan digest before apply, and suppresses Terraform plan/apply output that could
contain the subject. Use `deployment_scope=message-consumer` to return to the
checked-in inactive configuration.

The route resources do not replace `/analysis`, add a Lambda URL, schedule work,
or change URL-consumer IAM. The legacy endpoint remains retired. Authority and
provider activation, operational outcome reporting, qualified AI, Android gating
and controlled rollback remain separate acceptance steps. No new commercial,
research, retention or eligibility policy is introduced.

The first evaluator increment applies a deliberately bounded, qualified rule set;
unknown/out-of-coverage content remains inconclusive. Approved fixed EN/ES copy is
not evidence of production accuracy or broader AI coverage. Complete, partial and
inconclusive states must retain authoritative accounting and evidence limitations.

## Disabled proposer integration

The next Lambda increment may include an OpenAI Responses proposer. This root
explicitly sets `MESSAGE_PROPOSER_ENABLED=false`, supplies no provider credential,
and preserves the evaluator's blanket Secrets Manager deny. Installing its code
does not activate model processing. The approved rule policy remains pinned;
general AI conclusions require the approved separate policy to be implemented and
qualified through a new contract version. See the exact source and owner approval
in the [approval record](../../docs/MESSAGE-AI-ASSESSMENT-POLICY-APPROVAL.md).

A future reviewed activation change must supply all of these together:

| Setting | Required constraint |
| --- | --- |
| `MESSAGE_PROPOSER_ENABLED` | Explicit activation, separate from evaluator/consumer gates |
| `MESSAGE_PROPOSER_MODEL` | Explicit qualified model version; no inferred default |
| `MESSAGE_PROPOSER_SECRET_ARN` | Existing exact same-account Dev `trustcheckradar/dev/openai` secret ARN; never its value |
| `MESSAGE_PROPOSER_TIMEOUT_MS` | Integer 250–8000, within the remaining overall request deadline |
| `MESSAGE_PROPOSER_MAX_OUTPUT_TOKENS` | Integer 128–512, validated with the selected model |

Only then may evaluator IAM replace its blanket secret deny with an exact
`GetSecretValue`/`AWSCURRENT` allow and explicit denial outside that secret and
operation. Adding an allow underneath the existing blanket deny does not work.
The consumer must never receive provider-secret permission, and the evaluator
must never receive the authority HMAC or ledger permission. No secret value is
read by Terraform or stored in state. If the existing secret uses a customer KMS
key, qualify the narrow decrypt dependency separately; do not add wildcard KMS.

The adapter uses fixed HTTPS `api.openai.com:443/v1/responses`, one attempt,
no redirects/tools/background mode and `store:false`. Its only content projection
is validated sanitized text, language and speaker role; account/device/check IDs,
original entities and reviewed URLs are excluded. Model proposals remain subject
to the independently qualified verifier. The fixed endpoint is an application
control, not a claim of network-level egress enforcement. Provider data controls,
selected model compatibility, total attempt budgets, operational alarms and
rollback remain activation prerequisites. `store:false` does not establish zero
provider retention; see the linked proposal's source notes.

## Approved AI policy and candidate.2 gates

The 2026-09-21 owner approval authorizes broader AI implementation under
`message-ai-2026-09-21-v1`; it is not provider qualification or activation. Both
runtimes receive that separate version and the immutable approval SHA, while the
existing `MESSAGE_POLICY_*` settings retain candidate.1 semantics. The new
`MESSAGE_AI_ENABLED` flag is explicitly false on both, and evaluator
`MESSAGE_AI_QUALIFIED` is false. No qualification ID, model, credential or budget is
silently supplied. The approved policy document remains byte-for-byte historical;
its old draft heading is superseded by the linked approval record.

Candidate.2 uses a distinct version-bound intent/receipt path. A model call or JSON
schema pass does not establish qualification. Future activation must bind the
qualified model, prompt, schema and policy digests, require the exact existing Dev
credential permissions, and retain candidate.1 reconciliation. The AI path and
legacy proposer are separately gated; enabling either requires deliberate provider
access review. No permission is granted to either in this configuration.

When the candidate is provisioned, six native Lambda alarms cover errors,
throttles and duration for consumer/evaluator. They use only function-name metric
dimensions and the existing confirmed Dev SNS path for
`support@andmorethings.com`. Errors/throttles trigger at one event in five minutes;
duration warns three seconds below each hard function timeout. These are scoped
Dev engineering settings, not measured production SLOs. Missing metrics do not
constitute a service health check, and an OK notification is only this metric's
state transition.

Native alarms do not detect a fixed failure returned in a successful invocation,
count completed checks, deduplicate retries, calculate model costs or produce the
daily outcome report. Those SECUR4ALL-237/243 requirements, live alarm delivery
qualification, provider quality/data-control/cost gates and a rollback exercise
remain prerequisites for user traffic. `daily_reporting_ready=false` is explicit
in the candidate output. No alarm or resource is created when `enabled=false`.

## Verification

Use `terraform init -backend=false`, `terraform validate`, and `terraform test`
for local validation with the mocked AWS provider. Tests cover no-op defaults,
inactive runtimes, authority/evaluator isolation, immutable coordinated packages,
wrong environment/account rejection and absent public endpoint output. These
mocked applies create no AWS resources and are not a deployment report.

For the Dev installation, dispatch **Deploy infrastructure** from the exact
reviewed `main` revision with `environment=dev`,
`deployment_scope=message-consumer`, and `execution_mode=plan`. Confirm the summary
contains the bounded transition scope and the expected immutable Lambda release.
The initial installation produced 25 creates; later inactive plans are no-op or
coordinated runtime/alias updates. Then dispatch the same revision with
`execution_mode=apply` and its exact `reviewedPlanDigest`. The workflow applies
only that saved plan, verifies the selected inactive or one-subject engineering
contract, and requires a zero-drift follow-up plan. A changed revision or state
requires a new plan review.

The 2026-09-21 proposer handoff passed `terraform fmt -check`, `terraform validate`
and all 10 mocked runs, including the explicit disabled-provider/no-config
assertion. Changed-file Gitleaks found no leaks; the whole-tree scan reported two
pre-existing documentation matches containing commit IDs. The historical broader policy
draft is retained; its later approval is recorded separately and does not activate runtime behavior.
