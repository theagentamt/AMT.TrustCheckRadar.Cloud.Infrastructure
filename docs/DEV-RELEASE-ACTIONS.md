# Dev release branch Actions

The owner authorized GitHub Actions for infrastructure and Lambda deployment on
2026-09-21 after resolving GitHub billing. Android Actions remain excluded.
Automatic CI still runs only on main; this permission does not promote a release
or authorize UAT/Production.

The two Dev OIDC roles accept exactly main and release-V01. Immutable repository
IDs, organization ID, audience, environment subjects and role permission policies
are preserved. UAT/Production remain main-only. Because the old roles could not
assume credentials from the release branch, this bootstrap trust adjustment was
made through the authenticated operator and verified by readback, not through
Actions. Terraform bootstrap source records the same policy. The infrastructure
Dev environment permits main and release-V01; no protection rules were removed.
See [trust evidence](evidence/dev-release-actions-trust.json).

## Ready operations

Lambda's existing Publish Lambda release workflow accepts an explicit
research_candidate / Dev / exact source SHA dispatch from release-V01. It
validates and publishes nine immutable packages to the Dev artifacts bucket.
It does not update Lambda code or aliases. Publication evidence supplies object
versions and checksums for the later reviewed infrastructure selection.

Infrastructure's existing Deploy infrastructure workflow accepts
research-plan-campaign-processing or research-plan-api from release-V01,
environment dev, execution_mode plan, and expected_revision equal to the dispatch
commit. No other stack runs. These paths cannot apply. The existing broad
workflow job now explicitly requires main, preventing release dispatch from
entering the all-stack apply path. Automatic main behavior is unchanged.

A selected stack uses its normal Dev tfvars. A committed optional
`environments/dev/research-migration-<stack>.tfvars.json` overlays an immutable
candidate for review without replacing normal environment configuration.
The report explicitly distinguishes a baseline from a selected candidate.
Raw plans, logs and state-derived values remain on the runner and are removed;
the seven-day Actions artifact contains only resource addresses/actions, a plan
fingerprint, source revision and selection status. The fingerprint is observation
evidence, not permission to apply a future plan. Failed plans produce no success
report and require bounded diagnosis before another dispatch.

## Runtime cutover remains separate

The current Dev V1 authority live alias is disabled. Replacing legacy analysis,
snapshot, Web Risk and purchase handlers would interrupt their old behavior.
The migration also pauses campaign cleanup workers. Do not leave them paused
indefinitely or describe queued cleanup as complete. Follow
[the migration runbook](RESEARCH-CONSENT-MIGRATION.md), qualify inventory and
replacement access, review actual planned changes and maintenance impacts, and
verify the old-invocation drain before runtime cutover. Artifact publication,
workflow success and source integration are not live migration acceptance.

## Local validation

Actionlint passed for deploy.yml. Four summarizer tests cover environment/scope
rejection, private-value omission, baseline identification and drift fingerprints.
The mocked Terraform trust test verifies exact Dev release refs, audience and
repository/environment subjects, with main-only UAT/Prod trust.

## Plan-only candidate selection

[Lambda run 35675976296](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/actions/runs/35675976296)
succeeded at source d98ffd65b42d54953ad83e980e58846b6fc02c5d. The
[publication manifest](evidence/dev-research-actions-publication.json) contains all
nine S3 object versions and hashes. This is artifact publication, not runtime
replacement. Use this manifest exclusively; the packaged purchase dependency
bytes differ from the earlier local build.

[Campaign baseline run 35676187963](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35676187963)
succeeded with zero changes and candidateSelected=false. Its minimized report is
[retained here](evidence/dev-research-campaign-baseline-plan.json).

The campaign-processing overlay selects the four published workers and pauses
all consumers only in a plan. Its approval_reference points here to describe
plan review; it is not a maintenance-window or runtime-activation approval.
Normal campaign-processing.tfvars remains unchanged. The API candidate must wait
for an actual same-release paused campaign contract before a valid cutover plan;
we will not forge remote-state evidence to bypass that requirement.

[API baseline run 35676311698](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35676311698)
also succeeded with zero changes and candidateSelected=false; its
[minimized report](evidence/dev-research-api-baseline-plan.json) confirms no
baseline API drift at the observed revision.

## Candidate plan result

[Candidate run 35676587703](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/actions/runs/35676587703)
succeeded at infrastructure revision325b0ed01493dfb754614b7506d59f3886afa8c7.
The [minimized report](evidence/dev-research-campaign-candidate-plan.json) records
candidateSelected=true and15 in-place updates: four worker functions, five
runtime/scheduler inline policies, three event mappings and three schedules.
There are no planned creates or deletes. This verifies plan execution through
Dev OIDC; it is not an IAM behavior review, invocation drain or apply evidence.

No campaign worker, API handler, alias, customer item, entitlement or activation
flag was changed by these runs. Infrastructure bootstrap trust and the Dev
GitHub environment branch allowlist are the only applied access configuration
changes. Lambda publication uploaded immutable S3 packages. Android Actions
were not dispatched and main was not changed.

Next migration acceptance remains SECUR4ALL-217/218/241: protected inventory and
classification, qualified paid/trial/complimentary access and purchase restore,
retention-aware cleanup continuity, reviewed maintenance/drain, then an exact
saved-plan apply with runtime/IAM verification. Do not apply the campaign pause
and leave cleanup disabled while those dependencies remain unresolved. New
consent joins and the Android adapter stay closed until their own acceptance.
