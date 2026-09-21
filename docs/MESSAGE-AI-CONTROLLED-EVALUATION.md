# Controlled message AI evaluation: access and operations

SECUR4ALL-322 coordinates the Lambda tooling in SECUR4ALL-321 under the open
quality story SECUR4ALL-240. This handoff covers local evaluation source and
operations. It does not qualify a model, authorize an experiment, or activate AI
for mobile traffic. The [offline runbook](MESSAGE-AI-EVALUATION-RUNBOOK.md) and
[research proposal](MESSAGE-AI-QUALIFICATION-RESEARCH.md) retain their boundaries.

## Infrastructure findings

Source inspected at infrastructure release commit
`4d88b8ccf8a59c5a37b6a4ccd9d52dbcbe8c6c29`:

| Source | Observed behavior | Implication for evaluation |
| --- | --- | --- |
| `terraform/api/main.tf`, `aws_secretsmanager_secret.openai` | Creates a secret container when an existing ARN is not supplied; default name is `trustcheckradar/<environment>/openai`. Terraform does not populate its value. | A source declaration does not prove a usable secret or provider project exists. |
| `terraform/api/main.tf`, `analysis_runtime` | The legacy analysis role can read the configured OpenAI secret. | This is a different runtime; do not borrow its credentials or treat that access as authority for an experiment. |
| `terraform/message-consumer/main.tf`, evaluator policy | Explicitly denies all Secrets Manager access, along with consumer storage and role chaining. | Current candidate cannot read provider credentials. A future runtime activation requires a separate reviewed IAM change; adding an allow beneath the deny is insufficient. |
| `terraform/message-consumer/main.tf` and `outputs.tf` | AI/proposer gates remain false; no model qualification or provider credential is supplied. | Evaluation tooling must not change deployment flags or grant runtime access. |

This source inspection did not query deployed AWS state, read a secret value, or
inspect the provider account. No current deployment or account-access claim follows
from it. A local runner needs no new Lambda, public endpoint, DynamoDB table,
scheduled job or AWS role. No Terraform behavior changes are required here.

## Experiment identity and spending boundary

One experiment has one reviewed authorization and durable authority ledger. Export
directories are disposable views, not independent budgets. The authorization must
pin code, corpus/catalog split hashes, dated models, full effective request profiles,
pricing evidence and the allowed execution host/authority location. Execution must
reject a missing, corrupt or conflicting authority rather than initialize a fresh
budget. Creation of the authority is a separate deliberate step after approval.

The proposed comparison remains at most 660 generation attempts: 20 smoke and 200
development attempts per model across three candidates. The proposed auxiliary
ceiling is separately 660 input-count requests. Failed or timed-out requests count
toward their respective limits. These are maxima, not promised sample sizes:
ineligible speakers, failed counting, over-limit inputs and budget exhaustion reduce generation
coverage. Preserve those gaps in reports. Neither limit permits automatic retries.

The proposed USD 5 ceiling must cover the conservative price of both request types.
Generation reservations use uncached input and capped output rates; input-count
reservations need a separately evidenced worst-case charge, including evidence if
that charge is zero. Current public documentation establishes a counting endpoint,
but this handoff has not established its billing terms for the intended project.
Missing price evidence blocks approval; it is not silently treated as free.
AWS, Google, VirusTotal, taxes and human review are outside these model-service
estimates and must not be described as covered by that ceiling.

Reserve the maximum liability durably before each dispatch, using atomic admission
across concurrent processes. Preserve uncertain reservations after timeouts, crashes,
malformed usage or lost responses. Reconciliation may add validated usage evidence;
it must not erase an attempted request or manufacture a refund. A token-based cost
calculation is an estimate, not a provider invoice. Cost reporting and chargeable
customer checks remain separate: no customer allowance is touched by this runner.

Recheck revocation, expiry and the persisted experiment halt before dispatch. A
stop prevents subsequent admission; it cannot recall a request already admitted
or in flight. Those reservations still count against the budget. Count/usage or
effective pricing-tier drift halts the experiment for review.

Local permissions and transactions protect against accidents and concurrent runs.
They do not stop a privileged operator from modifying code, credentials or database
files. Use one controlled host and a dedicated provider project/key; do not copy a
live authority to other hosts. Distributed execution would require a separately
designed shared authority. Do not claim a local ledger enforces an account-wide
provider spending limit.

## Request counting and provider data

The official [input-token reference](https://developers.openai.com/api/reference/python/resources/responses/subresources/input_tokens/methods/count)
documents `POST /v1/responses/input_tokens`; the [counting guide](https://developers.openai.com/api/docs/guides/token-counting)
explains pre-generation counting. Bind counting to the same model, messages,
instructions, structured-output schema and effective token-bearing options used by
generation. Unsupported projection or a changed request invalidates admission.
The proposed 8,192-token cap is a tool limit; source tests do not prove actual
provider compatibility or that every supported 8,000-character message fits it.
An input above the cap is a visible coverage failure, not a silently dropped case.

Counting is itself external processing of the input. Provider access and data review
must cover both count and generation endpoints. The generation request uses fixed
official HTTPS routing, no tools/redirects/background mode, and `store:false`.
Keep these separate from networking guarantees: an application allowlist is not a
firewall, and source deadline tests do not establish measured provider latency.

The official [data-controls documentation](https://developers.openai.com/api/docs/guides/your-data)
distinguishes response storage from abuse-monitoring retention. `store:false` does
not establish zero retention. Inspect the actual evaluation project's data-sharing,
retention and endpoint eligibility before approving content transmission. The
customer application's seven-day receipt policy and US market restriction do not
establish provider retention or data residency.

Use a dedicated evaluation project and restricted credential. Deliver the key only
through the reviewed runner's protected credential input after admission succeeds;
never put it in source, a manifest, shell arguments, reports, Terraform variables or
state. Do not silently fall back to application runtime credentials. Exact credential
input and authority commands are specified by the Lambda tool's final operator
documentation; do not substitute an ad hoc HTTP call that bypasses its ledger.

The Lambda entry point is `scripts/message_ai_controlled.py`, with explicit `init`,
`preflight`, `run` and `report` actions. It ships with an empty evaluation-approval
registry, distinct from the unchanged production qualification registry. A manifest
file or command-line request alone grants no execution. The reviewed manifest also
has an expiry and pins a credential fingerprint; the fingerprint does not prove the
key's project or permissions, which must be established in the access evidence.

Keep the authority directory owner-only (`0700`) and its files owner-read/write
(`0600`). The operator supplies `provider-key.txt` there, containing only the exact
key bytes, through a restricted local secret-management process. The runner reads
it after dispatch admission and verifies its fingerprint. `preflight`, `init` and
`report` do not need to read key bytes. Protect this local credential as a secret;
never add the authority directory to the repository or a synced report folder.

Execution does not initialize the ledger. The explicit initialization action must
refuse repeat initialization, including after loss of the database. Reports go into
a separate private directory and cannot overlap the authority. Re-exporting a report
or choosing a new report directory must not create another spending allowance.
Use the same authority for restarts and preserve the full outstanding reservations.
Read-only reporting remains available after approval expiry or revocation and
labels that status. Preserve the pinned source checkout, matching corpus/authorization
and evidence files at the original host/location for this audit; a newer source
profile must not reinterpret an older experiment's identity or prices.

## Concrete run readiness record

Prepare this record once the tool and corpus are frozen. Unresolved entries remain
unresolved; this document supplies no approval signature or artificial evidence.

| Required evidence | Current status |
| --- | --- |
| Source commit and full profile/corpus digests | Record from the integrated adapter and reviewed input artifacts. |
| Scope: smoke/development only, permitted synthetic/licensed content | Draft bilingual development examples prepared separately; no customer submissions. |
| Actual label review and adjudication | Pending; proposed labels are not independent human review. |
| Provider project, dated-model access and compatible request schema | Unverified; source/fixture validation is not a successful provider call. |
| Sharing, retention, count-endpoint data treatment and any residency constraint | Actual project review pending. |
| Current generation rates and evidenced auxiliary maximum charge | Generation proposal exists; count pricing unresolved. |
| Exact generation, auxiliary and USD limits; authority location/owner | Proposed 660 / 660 / USD 5; concrete authorization still required. |
| Credential delivery, ability to stop further calls, and error recovery | Match final adapter documentation and verify with offline fault tests. |
| Evaluation artifact access, retention and end-of-run reconciliation | Select in the concrete run record; no new retention period approved here. |

For the first smoke run, compatibility evidence can be the reviewed official API
contract and matching request projection, with the authorized purpose explicitly
limited to validating actual compatibility. Do not require an earlier successful
live call to authorize the first one, or describe that documentary review as a
measured pass. A rejected count/schema request consumes its attempt and retains
any uncertain cost under the same limits.

Do not delete an unresolved ledger as a retention cleanup and then reuse its
authorization. Stop dispatch, retain the necessary reconciliation evidence under
the agreed policy, and resolve unknown usage before retiring the experiment.
If the authority is lost, stop. A stale backup must not be used to restore an older
spending balance. Any recovery must reconcile every potentially dispatched request
and receive a new reviewed authorization when that cannot be established.

## Test data and release evidence

The small English/Spanish development package belongs with Lambda evaluation
tooling. It should identify cohorts, paired-language cases, proposed reason sets,
code-point spans and reviewer worksheets. Blank reviewer fields must stay blank
until actual review. Draft material must fail the reviewed-corpus admission path.

Do not transform synthetic fixtures or translated development examples into a
claimed independent holdout. Split at family/source/template level, then check
cross-split duplicates and semantic near-duplicates. Independently review label
meaning, evidence spans and bilingual equivalence before freezing the holdout.
The parent quality story retains the larger corpus, cohort metrics, comprehension,
adversarial, real latency and release acceptance requirements.

Local adapter tests validate transport/accounting failure handling. They do not
prove model quality, schema acceptance by a live provider, settled provider charges,
customer deduction behavior or physical-device acceptance. ATCR-148 retains device
testing. SECUR4ALL-237/243 retain application reporting and alert delivery, with
`support@andmorethings.com` as the approved recipient. No daily report or new alert
schedule is provisioned by this evaluation handoff.

The controlled adapter calls the text-model boundary directly for eligible incoming
messages. It does not execute the production guard, Google lookup or final verdict
pipeline. Production guard skips remain covered by the offline pipeline harness;
neither tool may credit those rule results as measured model quality. Reports must
separate planned, eligible, unattempted and reserved cases by model/language, and
label token totals as the known-usage subset when any generation usage is unknown.
