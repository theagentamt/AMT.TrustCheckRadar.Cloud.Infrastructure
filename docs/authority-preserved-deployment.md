# Preserved Dev deployment modes

This focused main-based source change adds two choices to the existing manual
Deploy infrastructure workflow. Both require an exact main revision, Dev account
107827791950, the existing protected Dev environment/role and Terraform 1.12.1.
The broad and legacy jobs exclude these choices. No automatic trigger, IAM/trust,
secret, API, admission default or provider setting is changed.

`authority-maintenance` can update only the existing recovery function's
LEASE_SWEEP_ENABLED environment flag, its unweighted live alias, existing
one-minute rule, heartbeat alarm controls and overdue-alarm actions. Worker code
is pinned to the retained v11 hash; all artifacts and unrelated resources remain
unchanged. Shared recovery and expiry are inseparable: enabling this mode can
permanently delete eligible expired records across Dev accounts. The owner must
approve this scope separately before an apply. No apply is authorized by source
publication or by a successful plan.

`message-consumer-preserve-history` preserves candidate.3/schema3, History, AI-off
and the provider-open circuit. It permits coordinated Message package/alias
updates only; IAM and all runtime environments remain exact. The existing
two-subject Message/History cohort is pinned by its sorted JSON SHA-256. The old
one-subject qualification remains supported separately; no arbitrary second
subject is admitted. A future AI exception remains a different, one-tester gate.

The workflow first makes a private, non-applicable baseline plan using existing
source inputs. A read-only helper binds every selected existing function/alias to
its current version, package hash, full environment, limits and successful update
state, then prepares a private overlay. Maintenance preparation preserves existing
governed trial, separate GET-only access and deletion selections. It does not read
user items, derive keys, fetch secret values, register devices or grant access.
An optional full artifact_release SHA selects the two already-published versioned
Message objects; their hashes are checked before plan review. Artifact coordinates
that cannot be joined to current state/live code fail closed rather than being
guessed or replaced with stale defaults.

Message planning requires actual enabled same-table maintenance first. Readback
checks the exact worker hash/runtime/role/table, rule and target, input, retries,
invocation resource policy, existing role/trust/inline-policy baseline, and both
alarm identities/destinations. Missing read permissions stop the workflow; no
permission expansion or skipped check is allowed.

The final saved-plan verifier rejects failed/unknown checks, managed drift,
missing or inconsistent inventory, replacements, unrelated changes, private scope
changes, networking/limit changes, IAM updates and alias replay. It requires the
same refreshed baseline and captured live data. Apply needs the exact reviewed
digest at the same source revision and fresh identical live capture. Existing
caller-session normalization is reused for digest stability; no plan timestamps
or session suffixes serve as identity. Actual post-apply function/alias/control
readback and a zero-drift plan are required. Every shell creating private files
uses umask 077; exclusive private JSON writers use 0600; temporary files are removed
on success or failure. Only minimized fixed results/digests enter job summaries.

This is source completion, not deployment or live connectivity acceptance. The
two modes cannot enable AI, read a provider key or consume the one-generation
allowance. The exact retained worker 11 ZIP imports successfully in the cached
official Python 3.14 ARM64 Lambda image with networking disabled and no credentials;
its handler was not invoked. Full non-secret inventory shape, behavioral cleanup
qualification, fresh due-index inventory and irreversible-expiry approval remain
pre-activation gates. The earlier due-index observation was zero pending/zero
expiring at 15:17 UTC on 2026-10-23; it is eventual, dated and not future permission.
Keep complimentary access through 2026-10-27T22:09:34Z and active paid/trial state
unchanged. Expired period deletion is an explicit separate destructive scope.

Validation includes 42 passing focused Python cases, actionlint, Terraform
format/Message configuration validation, and whitespace checks. These are pure
saved-plan/compiler and workflow/static checks, not live connectivity evidence.
The read-only current maintenance metadata check passed with all controls disabled;
there was no mock-provider connectivity demonstration or live business submission.
Independent review found and corrected incomplete maintenance binding and missing
private umasks before publication. Main-push CI remains unchanged and must be
observed after integration; absent PR checks are not passing checks.

## Optional alarm metadata correction

The first [plan-only run](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/39993883611)
stopped during private preparation; its precise rejection predicate was not retained.
An independent actual read-only execution of the same checker reproduced a
`DatapointsToAlarm` KeyError: the existing overdue alarm omits that optional field.
[AWS documents](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-cloudwatch-alarm.html#cfn-cloudwatch-alarm-datapointstoalarm)
that omission uses `EvaluationPeriods`. Only absence now inherits that value;
explicit null, malformed, or incompatible datapoints remain rejected. All alarm
timing, comparison, destinations and disabled/enabled controls remain exact.
The pure alarm predicate has direct metadata regression coverage, without a mock
AWS client or connectivity claim. No workflow, IAM, defaults or activation scope
changes are included. A retry must use the reconciled new main revision, plan-only
inputs, and the existing role; it does not authorize an apply.

## Entitlements v18 preservation correction

Read-only reconciliation on 2026-10-23 identified the owning URL root state at
serial 33 with entitlements function/alias v15, while the actual unweighted live
alias and latest successful code are v18. The exact live ZIP was downloaded from
Lambda and hashed independently; its two admission-diagnostics modules match the
reviewed [PR126/127 source and deployment evidence](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/127).
No v18 S3 publication coordinates were established or invented.

The pinned AWS provider refreshes computed `code_sha256` from Lambda's
`CodeSha256`, but retains `source_code_hash` and S3 coordinates as historical
configuration inputs. These fields have different meanings. Capture now checks
actual runtime identity with mandatory `code_sha256`, and independently binds
all historical artifact inputs. The exact v18 bytes, version, code size/date,
full environment, base trial selection and independent GET-only selection are
pinned in `docs/evidence/entitlements18-preservation.json`. Private subjects are
represented only by canonical selection digests. The old GET-only selection must
never be restored; no trial or consumer scope is expanded.

Only the complete known v15-to-v18 function-and-alias refresh may appear as
read-only `resource_drift`. Its old/new runtime and environment pins, unchanged
historical artifact inputs and every other field must match. Partial pairs,
weighted aliases, different code, configuration changes, or other managed drift
are rejected. Both final entitlements resources must independently be complete
no-ops at v18 with no unknown values. Keeping the old deployment arguments inert
is permitted only with that full no-op proof; any proposed reapplication or
rollback is rejected. This does not import, rewrite or push Terraform state,
ignore configuration changes, or establish reusable v18 S3 provenance.

The final maintenance plan still permits only the existing five recovery
resource updates, or an exact no-op when already active. All IAM, routes,
admission and other runtimes remain unchanged. A minimized accepted result names
only those permitted addresses and the reviewed plan digest. Source tests exercise
saved-plan/compiler predicates with synthetic private selections; they are not
live connectivity acceptance. The earlier plan rejection's exact predicate was
not retained, so this correction does not claim to prove its unique cause.

Workflow inputs, side effects, role permissions and Terraform configuration are
unchanged. A new exact main revision and one separately authorized plan-only run
are required. No apply or shared recovery/irreversible expiry activation is
included. Main CI and the actual new plan outcome are recorded separately after
source integration; local test success alone does not qualify a live plan.

Local correction validation passed 479 Python cases, including 23 preservation
predicate cases, with the existing dependency-equipped interpreter. Terraform
formatting, actionlint, campaign guardrails, Python compilation and whitespace
checks passed. An initial host-interpreter run lacked boto3/botocore; that
incomplete run is not counted as a pass and no dependencies were downloaded.

## Finite verifier rejection diagnostics

The verifier now emits a fixed JSON rejection record: phase, predicate code,
resource category and allowlisted field categories. Every original safety
condition is unchanged and evaluated once. A source-AST regression pins all
43 conditions from main `f4ea3ada`; prior preservation tests remain applicable.
Resource addresses, private selections, environment values, plan/state content,
AWS command arguments/stderr and arbitrary exception text are never rendered.
Unrecognized resource/field labels become fixed `OTHER` categories. Unexpected
structure errors remain rejected and expose only a known schema-field label.

Artifact account/read/version/hash failures have separate finite codes after the
plan-review phase. Therefore a failed required S3 read cannot be mislabeled as an
accepted five-resource plan or silently skipped. Public results contain no
private plan, raw error or request payload. Adversarial rejection tests cover
injected addresses, field names, exception text, command arguments and stderr.

The exact rejection in run `40000744126` cannot be reconstructed from its generic
message; its private files were correctly removed and no artifact remains. A new
reviewed source revision and separately authorized plan-only diagnostic attempt
are necessary to identify the boundary. This change does not retry a workflow,
weaken a guard, authorize apply/expiry, or change IAM, runtime flags or contracts.

Diagnostic source validation passed 490 Python tests, including eleven dedicated
rejection/privacy cases and the unchanged 23 preservation cases. The prior PR187
main CI passed all 33 steps before this change. These are source-validation
results, not a successful live plan or connectivity claim.

Argument-parser failures also use the finite rejection path; invalid options and
choices cannot echo raw supplied arguments. Normal help remains available.


## Deletion handler pin correction

The real diagnostic plan `40003812497` rejected `RUNTIME_IDENTITY` for
`DELETION_FUNCTION`. A bounded read-only check at 2026-10-23T18:33:11Z confirmed
that active unweighted live v24 uses
`v1_authority_deletion.app.lambda_handler`, exactly as declared by
`terraform/url-consumer/main.tf`. The verifier incorrectly assigned the generic
`app.lambda_handler` entry point. All other comparable runtime/role/limit fields
matched. The preservation fixture overwrote the correct existing deletion
handler with that same wrong generic value, hiding the defect.

The verifier now pins the exact packaged deletion handler; the fixture override
is removed. The regression joins the actual sanitized metadata in
`docs/evidence/deletion-handler-preservation.json`, the real IaC handler and the
unmodified base fixture, accepts preservation as a no-op, and rejects wrong
handlers for all four protected runtimes. Synthetic scope data in these source
tests is not a live-plan acceptance claim. All other runtime identity, artifact,
no-op, drift, IAM and activation predicates remain intact. No deployed Lambda
handler or Terraform configuration is changed.

The earlier generic run did not retain its exact rejection; this diagnostic
establishes the current failed guard directly. It does not prove that later
checks or the required artifact read will pass. A separately authorized corrected
plan must use the new reviewed main revision. No apply or recovery/expiry
activation is included in this correction.

Local correction validation passed 492 Python cases, including the two new
IaC/live-handler provenance and wrong-handler regressions. The fixed finite
rejection/privacy tests and all other preservation checks also pass. Formatting,
actionlint, campaign guardrails, compilation and whitespace checks passed.
