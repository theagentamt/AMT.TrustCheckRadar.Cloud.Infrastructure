# Focused main integration of shared maintenance controls

This source-only change starts from main
`f1c5d36d565d1f6eb937d957605dc235f7867780` and carries only the maintenance and
deployment-verifier delta reviewed in [PR183](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/pull/183).
It does not merge release-V01 wholesale, replace main's tree or close PR183.
The owner explicitly authorized this focused main integration on 2026-10-23.

The independent maintenance switch remains false by default. GET-only snapshot,
trial, operator, consumer and deletion selections remain distinct. Active Message
admission requires versioned same-table maintenance configuration; this object is
not live AWS readback. The existing plan verifiers now check no-op inventory,
runtime/alias pins, unexpected attachments and failed/unknown checks. Candidate.3
and History compatibility are preserved. No API, tfvars, IAM, secret, workflow or
activation default changes are included.

The complete Message/URL component source is byte-identical to the retained
reviewed component evidence from local commit
`2ff2140b021e096f1fcb35352368dbf075c3d8af`, published with tree
`91df880d24a75479664e1dfc78787f5245fe80c9` at
`56a1c6181dc41cae6919e20effe59f6f1ed73b32`. Prior offline tests remain source
evidence, not live connectivity acceptance or newly executed tests.

Current main-based checks passed: repository-wide Terraform formatting, static
Terraform validation for both complete components, Python syntax, whitespace,
and 30 focused verifier/release/History unit tests. The first unit-test command
used an incorrect module name; the corrected four-module command passed all 30.
No new Terraform mock suite or live service test was used for this integration.

Merging main triggers the unchanged Terraform CI validation workflow. All other
workflows are manual. CI has contents-read permission, no supplied AWS credentials
or OIDC permission, and no Terraform apply/deployment step. Feature-branch pushes
and PR creation do not trigger those checks; zero checks is not a passing result.
Post-merge CI must be observed and failures investigated before further rollout.

Source integration alone does not make the existing deployment workflow suitable
for current candidate.3/History or the bounded AI exception. Its manual Message
job is still main-only and its legacy transition mode preserves AI-off policy.
A separate exact saved-plan/overlay and deployment-path review is required; do
not use an older candidate.1 transition to erase current candidate.3 settings.

Shared recovery and expiry still run together. Activation can conditionally
settle abandoned pending checks and permanently delete expired minimized records
across retained account partitions. Fresh scope/inventory and separate
action-time approval are required. No activation, new provider permission,
credential handling, cloud mutation, provider call or mobile acceptance is
authorized by this source integration. Preserve the existing complimentary
grant and paid/trial state.
