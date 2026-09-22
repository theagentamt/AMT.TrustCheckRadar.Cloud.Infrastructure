# Authorized Dev runtime migration

On 2026-09-21 the owner clarified that Dev has no ongoing testing and that this
is the right time to perform the migration. This authorizes the temporary
unavailability of legacy analysis, access and purchase paths while deploying
the reviewed independent-consent candidates. Replacement paid service readiness
is a later acceptance task, not a reason to defer this Dev runtime deployment.
Infrastructure and Lambda Actions are authorized; Android Actions, main
promotion, UAT and Production remain outside scope.

## Selection and ordering

The immutable package release is d98ffd65b42d54953ad83e980e58846b6fc02c5d,
from the [successful publication](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/actions/runs/35675976296).
The committed publication manifest supplies nine exact S3 versions and SHA-256
values. Normal Dev tfvars now select those packages so later normal planning
does not silently restore the old behavior. The temporary plan-only overlay is
removed. New consent joins remain false; ownership and cleanup inventory gates
are not approved by this deployment.

1. Drain exactly the nine migration functions: record their pre-state, stop new
   invocations, disable the three campaign mappings and lifecycle schedules,
   verify the pause and wait at least the maximum old invocation timeout.
   Preserve queued work and customer records. This bounded bootstrap operation
   is performed by the Lambda agent through the authenticated AWS operator.
2. Run the campaign-processing migration plan from the exact release commit.
   Review its minimized changes/digest and immutable-package verification.
   Dispatch apply with the same revision and digest; apply only the saved,
   verified plan. Check the post-apply plan for drift. Worker concurrency stays zero throughout installation, and event
   mappings/schedules stay disabled.
3. The API plan must read the actual same-release paused campaign state.
   Apply its reviewed saved plan with the same safeguards. It keeps all five API concurrency limits at zero while installing the
   new code and enforced IAM boundaries.
4. Verify actual runtime, architecture, hash, successful update status, flags,
   consumer state and IAM while every function is still paused. Then commit
   the normal API 5/campaign 2 limits and apply separately reviewed concurrency-only
   restore plans. A positive concurrency plan cannot also switch old code to the
   new packages. Finally check non-mutating handler responses. Record what was and was
   not exercised. Never label a package upload or plan as a runtime deployment.

The existing registered workflow supports research-migrate-campaign-processing
and research-migrate-api only for Dev on release-V01. Apply requires the exact
reviewed digest and commit. The verifier limits managed resource addresses and
operations, checks the closed activation flags and all immutable package bytes,
and rejects destructive or unrelated changes. Raw plans remain runner-local.
The old research-plan paths remain plan-only. Automatic CI remains main-only.

## Remaining acceptance after deployment

Migration deployment does not rewrite or approve existing entitlement, receipt,
consent or research records. Inventory/classification, uncertain accounting
reconciliation, paid/trial/complimentary restoration, historical withdrawal and
backup cleanup, real-client compatibility and device qualification remain
tracked in SECUR4ALL-217/218/241. Paused cleanup cannot be described as completed
erasure. Keep those acceptance requirements open and qualify the new cleanup
path before enabling research contributions or user testing that depends on it.
Do not resume legacy publication to clear queues or restore research bonuses.

## Drain evidence

The [verified drain](evidence/dev-research-runtime-drain.json) records nine
functions at concurrency zero, all three campaign mappings disabled and all
three lifecycle schedules disabled with their other configuration preserved.
The final check occurred 80.733 seconds after all gates first settled, exceeding
the longest old invocation timeout of 60 seconds. This bounds completion of old
executions; it does not establish that stored records or queued work are empty.

## Install validation

Local validation passed: 14 campaign privacy Terraform cases (including the
Dev-only zero-concurrency install exception), 11 release-verifier cases,
Actionlint, formatting and diff checks. The refreshed private campaign plan
passed scope/closed-gate validation and exact S3 version/hash verification for
all four packages. Its digest is a local preflight only; Actions must generate
its own reviewed digest at the committed dispatch revision. Independent review
covered the verifier, workflow gates, pin mapping and normal environment inputs.

## Campaign installation

[Plan 35677812219](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35677812219)
and matching [apply 35677898642](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35677898642)
succeeded at 245d67a0226cf19de5dd793daa4fa30c63fa5498. The saved plan applied
nine updates (four packages/configurations and five inline policies); the
post-apply plan reported no drift. Four exact deployed package hashes and
Python 3.14/arm64 runtime identities were independently verified while concurrency
remained zero. Campaign mappings and schedules remain disabled.

The dependent private API plan contains seven updates and six creates (five
named IAM boundaries and one Terraform coordination record), with no deletes.
All five exact package bytes verified. The release checker now accepts the
provider's unused computed name_prefix only on creation with an exact fixed
policy name and role; twelve focused checker tests pass, including rejection
of a supplied prefix or missing/changed identity. This is a checker correction,
not a broader permission grant.
