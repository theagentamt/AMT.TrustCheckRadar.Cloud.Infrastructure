# Governed V1 message candidate

SECUR4ALL-242 supplies the isolated infrastructure dependency for ATCR-120 and
SECUR4ALL-190/228/229/230. This root provisions only an inactive Dev candidate.
It does not replace the existing URL stack, publish an endpoint or activate
message processing. All checked-in environment files remain disabled.

## Runtime and trust boundaries

- Python 3.14 ARM64 `message-consumer` invokes only `message-evaluator:live`.
  It reuses the existing V1 HMAC key ring, authority ledger, account/device/deletion
  fences and transactional `V1#*` mutations. There is no second allowance ledger,
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
- Consumer, evaluator and authority flags remain false; the provider circuit is
  explicitly open. Policy/version and approval SHA are pinned to the owner-approved
  2026-09-20 message rubric. Budget configuration is not invented here: validated
  account/service attempts, failures, window and deadline limits are activation
  prerequisites, separate from the 200-completed-check allowance.
- Fourteen-day operational log retention follows the existing runtime baseline.
  The Lambda code must emit only approved metadata; no request/response payloads,
  replaced values, URLs, proof, credentials or exception payloads. Seven-day
  minimized receipts use the shared authority lifecycle, not this log policy.

## Integration and activation gates

State is isolated at `trustcheckradar/dev/message-consumer.tfstate`. The provider
is restricted to Dev account 107827791950. Inputs are exact environment-scoped
same-account dependencies. UAT/production provisioning is rejected. CI validates
this root, and the automatic deployment workflow explicitly excludes it.

Before deployment/activation, pin the reviewed Lambda artifact pair, validate the
actual Android contract against handler responses, and review a saved manual Dev
plan. Existing account inventory, retained-key deletion, ACCESS-last fencing,
explicit expiry and lease recovery must be integrated coherently; a passing mock
must not stand in for live lifecycle qualification.

Authenticated gateway routes, authority/retention horizons, allowlisted synthetic
Dev qualification, provider budgets, operational alarms using the existing
confirmed support@andmorethings.com alert path, and controlled rollback are
separate activation gates. This candidate creates no API Gateway integration,
Lambda URL, public invocation grant, schedule or event source. It changes neither
the legacy endpoint nor the URL consumer's IAM permissions. No new commercial,
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
general AI conclusions require the separate [policy proposal](../../docs/MESSAGE-AI-ASSESSMENT-POLICY-PROPOSAL.md)
to be reviewed and implemented through a new contract version.

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

## Verification

Use `terraform init -backend=false`, `terraform validate`, and `terraform test`
for local validation with the mocked AWS provider. Tests cover no-op defaults,
inactive runtimes, authority/evaluator isolation, immutable coordinated packages,
wrong environment/account rejection and absent public endpoint output. These
mocked applies create no AWS resources and are not a deployment report.

The 2026-09-21 proposer handoff passed `terraform fmt -check`, `terraform validate`
and all 10 mocked runs, including the explicit disabled-provider/no-config
assertion. Changed-file Gitleaks found no leaks; the whole-tree scan reported two
pre-existing documentation matches containing commit IDs. The broader policy
document is a review draft, not a runtime configuration or approval record.
