# ATCR-184: Dev/UAT alarms and environment handoff

Source base: `5c6281be23009d88c4b65df6788ae094528e097e`.
Release coordination: ATCR-180. Outstanding work remains with ATCR-184 or a
specific linked follow-up under ATCR-186; this document starts no new roadmap.

## Prepared change

All 40 CloudWatch alarm declarations in the 13 stacks listed in
[`nonproduction-alarm-resources.json`](../scripts/nonproduction-alarm-resources.json)
now select zero instances for Dev/UAT. Production evaluates the original
cardinality expressions and retains the original alarm fields and addresses.
No production tfvars, IAM policies, runtime admission, provider switches, logs,
metric filters, dashboards, SNS topics/subscriptions or cost budgets change.
The age-attestation output also returns an empty alarm list without indexing a
removed alarm.

Removing Dev/UAT alarms deliberately removes automatic failure/heartbeat/expiry
notifications there. It does not disable the maintenance worker or schedule,
prove recovery, or make a public release ready. The shared maintenance contract
is schema 2 with `alarm_policy = "dev-uat-disabled-v1"` and an honest
`heartbeat_enforced = false`. Worker/schedule, artifact, identity, authorization,
allowlist and provider boundaries still have to pass their existing checks.

The Message, trial, billing and preserved-deployment verifiers require an
alarm-free plan. They reject an alarm migration mixed into a runtime change.
The AI preservation guard retains runtime log groups and their observed
retention/encryption configuration; readback checks the logs and confirms the
six old Message alarm names are absent. Maintenance readback similarly requires
the old heartbeat/expiry alarms to be absent. Both alarm kinds and complete
pagination are required. Legacy alarm metadata unit regressions remain retained.

The new saved-plan verifier accepts only reviewed root alarm addresses, exact
Dev/UAT alarm names and account/Region ARNs, deletion actions, and identical
no-op unrelated resources. It rejects managed drift, unknown values, incomplete
inventories, replacements and post-plan alarms. It never calls AWS or applies.
For a future separately authorized plan review:

```sh
python3 scripts/verify_nonproduction_alarm_removal.py OWNER_PRIVATE_PLAN.json \
  --revision FULL_REVIEWED_SOURCE_SHA --environment dev --stack message-consumer
```

This command is an example consuming an already saved plan. No live plan, apply,
deletion, workflow dispatch, provider request or credential read was performed
for this change. An accepted digest is not deployment authorization.

## Integration and live-removal gates

Main currently triggers only `ci.yml` on push; the other infrastructure workflows
use `workflow_dispatch`. A merge does not automatically deploy. CI and deployment
workflows remain unchanged. Owner clarification permits mocks only for isolated
unit/functional regression; they cannot satisfy provider or end-to-end acceptance.

1. Parent/release-safety reviews this exact source and serializes main integration.
   A local commit is not an integrated or deployed story.
2. Completed: parent assigned heavy slot 2; all 13 stacks validated and all 551
   mocked Terraform checks passed with installed, locked providers. The full
   Python helper suite passed all 515 tests. Slot 2 is released. These checks
   provide no live acceptance; no tool installation occurred.
3. Before any live removal, an authorized operator captures exact account/Region
   identity, current alarm inventory and restoration definitions. Prepare one
   saved plan per owned state root using inputs that preserve actual live runtime
   versions/configuration. Committed Dev tfvars contain historical artifact pins;
   they must not silently overwrite the currently deployed versions.
4. Review every saved plan with the alarm-only verifier and bind the source SHA,
   state root and digest in the change record. Ordinary runtime workflows cannot
   substitute for this separate review. There is no dedicated alarm-removal
   workflow in this patch; parent/release-safety must select the approved execution
   path. Any IAM/access denial is a blocker, never a reason to broaden access.
5. A separate, specific approval is required to delete/apply. After an authorized
   action, capture complete `describe-alarms` results for both alarm types under
   the exact environment prefix, then verify logs, metric filters, budgets, SNS,
   runtime versions, worker/schedule and auth/provider gates remain unchanged.
   Reject partial pagination and compare the inventory against the owning states;
   40 source declarations do not imply exactly 40 live alarms.

The supplied inventory was **111 Dev alarms**, and zero UAT/prod-prefixed alarms,
functions or tables, in **account 107827791950, us-east-1 only**. This worker did
not refresh that inventory and makes no assertion about other accounts/Regions.
The supplied runtime baseline remains Message consumer 8/evaluator 7 rules-only,
AI off; URL consumer 9 disabled; assessment 3/resolver 2 present; History reader
3/GSI2 IAM fixed; maintenance worker 12 and schedule enabled. These resolved
changes are not recreated by this patch.

## Exact Dev to UAT deltas and blockers

| Boundary | Dev source / supplied runtime | UAT gap and required next evidence |
|---|---|---|
| Account, state and deployment identity | Reviewed Dev account/Region above; workflows refer to Dev deployment roles/state. | UAT tfvars name `us-east-1`, but no independently verified UAT account/state/role binding was supplied. Parent must name and verify them read-only before UAT provisioning. Repository variable names are `AWS_ROLE_ARN`, `AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_KEY_PREFIX`, `ARTIFACT_RELEASE`; values were not queried. |
| Cognito and authenticated routes | Dev issuer is pool `us-east-1_wzN0wUSdQ`, app client `5kvl9a8jo4fr1qqnci27tdabk4`; Message uses API `icuak34th9`, authorizer `itms4b`, JWT and `aws.cognito.signin.user.admin`. | Obtain UAT pool/client/API/authorizer outputs and the existing approved tester's scoped eligibility. Never copy Dev IDs or introduce a tester/account. Keep issuer/audience/scope checks and server authorization. |
| Public endpoint and identity workflows | API/edge state outputs supply the actual endpoint; identity-workflows links to its environment's foundation. | UAT source names `https://api-uat.andmorethings.net`, but DNS/TLS/API deployment and post-confirmation trigger binding are unverified. An intended hostname is not a working endpoint. |
| Provisioning/admission | Message and URL consumers, private URL assessment, governed History, Play handoff/lifecycle enforce Dev-only enablement in their variable validations. | Their UAT files are disabled placeholders. Governed History has null deployment/API inputs and `index_ready = false`; History data/processing are disabled. Supporting UAT requires a separately reviewed environment-bound contract change and real UAT dependency outputs, not just `enabled = true`. No restriction was relaxed here. |
| Google URL assessment | Dev private assessment references the existing Dev Web Risk secret **by ARN only**, a resolver `:live` alias and immutable artifact. The supplied URL consumer remains disabled. | UAT assessment/resolver lack artifact pins and provider/alias bindings. Provider credential presence, provider authorization/quota, resolver egress and real outcomes are unverified. Secret values and paid calls require separate scope. |
| Message AI | `environments/dev/message-ai.json` defaults AI off; supplied consumer/evaluator are rules-only. AI validation pins a Dev OpenAI secret ARN pattern, exact scope, qualified artifact and bounded cost policy. | No UAT AI config exists. A UAT provider reference, qualification, real endpoint response and exact shared-budget reservation are missing; Dev activation cannot be copied. AI/evidence worker owns the real provider failure and its attempt counter. |
| QR | No QR-specific provider/endpoint binding is defined in this infrastructure source. | Android/Lambda owners must supply the real QR contract and dependency evidence. An unavailable endpoint is a blocker; this worker added no stand-in. |
| Immutable artifacts | Dev tfvars include historical S3 key/version/hash pins; preservation workflows capture current runtime bindings. | UAT Message/URL/assessment/History/Play deployment artifacts are absent or disabled. Publish/promote only reviewed exact bytes into the approved environment bucket, with S3 object version and SHA256 readback. Publication is a separately approved action. |
| Maintenance and alarms | Worker/schedule remain enabled per supplied baseline; alarm removal is code only. | First complete the separately approved alarm-only migration and schema-2 readback in Dev. UAT needs its own same-table maintenance evidence; no Dev ARN or heartbeat-enforcement claim may be reused. |
| Play/billing | Existing Dev-only package/provider/authority constraints remain intact. | UAT Play verification is disabled; `environments/uat/play-lifecycle.tfvars` is absent. Billing worker owns the actual catalog/provider/approved tester proof. No purchase or provider call occurred here. |

These are concrete environment/dependency blockers to Dev then UAT acceptance,
not a finding that all environments are globally absent. Parent owns linking
the specific unresolved items to ATCR-186 without duplicating existing work.

## Scoped readiness record

Decision: **No-go for public deployment**. Accountable launch owner: **Daniel**;
coordination/escalation: **little b via ATCR-180**. Source integration can be
reviewed independently of that decision. There is no launch waiver in this record.

| Evidence category | Source or explicit gap |
|---|---|
| Ownership | Daniel; little b coordinates ATCR-184 and ATCR-186 follow-ups. |
| Outcome | Remove only Dev/UAT alarm instances while preserving runtime/auth/provider and production behavior. |
| Dependencies | Concrete UAT/auth/provider gaps above; no live qualification claimed. |
| SLOs | No user-boundary recovery/stability evidence collected. Parent retains the release gate until real Dev then UAT journeys pass. |
| Observability | Logs, metric filters and dashboards preserved; Dev/UAT automatic alarms intentionally removed. Future live batches need explicit operator observation and a stop condition. |
| Support | This handoff and existing `docs/authority-preserved-deployment.md`; escalate any missing live dependency to little b before activation. |
| Security | No IAM, JWT, allowlist, secret value or provider-access change. Private plans remain private. Static source review is not live authorization evidence. |
| Data | No data/state/resource mutation; existing deletion/History fixes preserved. |
| Rollback | Before deployment, revert the source commit. After separately approved removal, use retained exact alarm definitions and a separately reviewed restoration plan; a Git revert alone does not restore cloud resources. |
| Capacity | No load, emulator or live integration work; all 13 Terraform stacks validated offline; 551 mocked checks passed and heavy slot 2 is released. |
| Cost | Existing budgets/SNS retained. No paid batch or provider spend authorized/performed by this workstream; shared US$50 ceiling is unchanged. |

Validation details and historical failed-check dispositions are retained in
[`atcr184-source-checks-2026-10-25.json`](evidence/atcr184-source-checks-2026-10-25.json).
