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
