# Message AI evaluation: offline operations and cloud handoff

Tracks SECUR4ALL-240/229; operational dependencies SECUR4ALL-237/243; Android ATCR-120.
This increment implements evaluation tooling, not a qualified model or enabled service.
The [research proposal](MESSAGE-AI-QUALIFICATION-RESEARCH.md) remains the source for
candidate selection and proposed paid-experiment limits.

The next source increment is tracked in SECUR4ALL-321/322; see the
[controlled evaluation handoff](MESSAGE-AI-CONTROLLED-EVALUATION.md) for access,
durable experiment authority, auxiliary request accounting and remaining run gates.

## Execution boundary

The runner belongs to the Lambda repository and runs locally with Python 3.14.
Offline simulation requires no new AWS function, IAM role, DynamoDB table, schedule,
provider secret, API endpoint, or network egress. Do not provision infrastructure
merely to run synthetic tests. The runner must not be included in deployed Lambda
archives or invoked by mobile endpoints.

Simulation responses exercise the existing request builder, output parser and
candidate.2 policy using invented engineering examples. Simulated outcomes, token
usage, latency and monetary reservations must be labeled as such. They cannot
populate the production qualification registry, establish model accuracy, or prove
that the provider accepts the schema. A sample corpus is not an independently
reviewed holdout. Labeling metadata is an assertion to verify, not evidence that
human review happened.

Keep the production AI flags false, provider circuit open and qualification registry
empty. Existing candidate.1/candidate.2 contracts, seven-day receipts, account access,
allowances and the mobile feature flags retain their current semantics.

## Local artifact handling

Use a dedicated private directory outside the source checkout for the run journal
and generated reports. It must not be synchronized into customer analytics or
uploaded to cloud logs. Keep raw corpus fixtures limited to permitted synthetic or
licensed evaluation material; do not export customer submissions, research records,
credentials or account/device/check identifiers into a corpus.

The durable journal coordinates simulated attempt/cost reservations. Treat it as
sensitive operational metadata; use restrictive file/directory permissions and
preserve it when resuming a run. Never remove, edit or replace a journal to claim
that a paid budget has reset. Offline tooling alone cannot prevent an operator from
creating another local file; any future live runner must bind its authorization to
a durable, auditable experiment identity and enforce limits across restarts and
processes. Loss or corruption of that ledger must block further live work.

Export only bounded aggregate dimensions, fixed outcome/reason codes and hashes
needed to identify the reviewed profile/corpus. Do not export raw messages, evidence
spans, exception strings, credential values, arbitrary case names or filesystem
paths. A cryptographic hash identifies an artifact; it does not prove label quality,
independence or privacy. Keep failure/unknown-cost coverage explicit.

Refusal, truncation, malformed schema, wrong model metadata and timeout must be
forced through offline fixtures. A small live smoke run cannot guarantee those
outcomes occur naturally. Separate actual provider dispatch counts from deterministic
policy skips; local rule passes cannot inflate AI quality or provider latency samples.

Keep model assessment distinct from final mobile verdict, processing and coverage.
For example, AI no-warning with a withheld link remains inconclusive; a warning
with that link remains partial. Neither result clears the link. Report simulated
dispatches separately with zero live dispatches, and do not interpret a predicted
chargeable outcome as an actual settled receipt. Account settlement, retry/recovery
and immutable candidate.1 receipts retain their separate backend/mobile tests.

## Review checklist for a later paid experiment

Before a separately reviewed live implementation/run:

- Pin the exact code, corpus split/provenance and independently reviewed labels,
  dated model, prompt/schema/contract and the full effective request profile,
  including reasoning, output limit, deadline and endpoint. Reject changed profiles
  on resume. Do not use a forged production qualification entry for experiments.
- Validate an upper bound for all input tokens, including instructions/schema and
  model framing. An unverified estimate or 8,000-character limit is not a token cap.
  Record any token-count API traffic separately. Over-budget supported cases remain
  visible coverage gaps; never silently omit them from quality results.
- Reserve an attempt and maximum cost before dispatch, atomically and durably;
  reconcile only authoritative usage. A timeout may still cost money. Retain the
  reservation when usage is unknown, reject duplicates/conflicts, and prohibit
  automatic retry/reset paths that evade the cap.
- Recheck current pricing and the actual provider project's availability, data
  controls, training-sharing settings and retention. Use a separate test project/key
  with only the required access and permitted evaluation content. Do not send keys
  through messages, source files, CLI arguments, reports or Terraform state.
- Present concrete generation and auxiliary request limits plus a monetary budget.
  The proposed $5/660 and later $30/2,800 stages are not measured costs or blanket
  authority for provider/AWS calls. The offline runner must have no enabled live
  transport until that boundary is implemented and reviewed.
- Establish per-language metrics for warning/no-warning/abstention, semantic evidence
  support and processing failures. Record code-point offset cases separately from
  UTF-16/grapheme assumptions. Freeze quality thresholds before the holdout.

## Eventual infrastructure activation

Once the separate experiment and its evidence qualify a model, inspect the actual
Dev artifact/configuration/IAM diff. Bind runtime validation to the same evaluated
request profile. Grant provider-secret read only to the private evaluator and only
the reviewed secret/version stage. Keep the consumer unable to read provider keys
or bypass accounting. Existing source defaults do not grant that access today.

SECUR4ALL-237 supplies authoritative lifecycle, deduction and provider-cost facts;
SECUR4ALL-243 supplies scheduled reports, restricted delivery, meaningful alerts and
runbooks. Recipient remains support@andmorethings.com. Neither synthetic reports nor
native Lambda alarms satisfy application reporting/delivery acceptance.

Resolve the draft reporting schedule, alert thresholds and operational retention
before provisioning new stores. A proposed 30-day linkable reconciliation record is
not covered by approved seven-day result/usage retention. Preserve the distinction
between processing completion and chargeable completion; inconclusive/partial/failed
outcomes do not deduct. Keep unknown accounting unknown until reconciled.

No new cloud resources or Terraform behavior are required for this offline increment.
Future Dev runtime, provider-data controls, real outcome reporting and physical-device
acceptance under ATCR-148 remain separately evidenced gates.
