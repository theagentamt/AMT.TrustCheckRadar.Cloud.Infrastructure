# Operations

## Deployment Order

Always deploy in this order:

1. Foundation
2. Campaign data
3. Artifact verification
4. API
5. Campaign processing
6. Campaign API
7. Edge
8. Identity workflows

The GitHub deployment workflow enforces this sequence. Direct local changes should use `scripts/terraform.sh` and follow the same order.

## Promotion

Deploy a release to development, run API smoke tests, promote the identical package set to UAT, then promote it to production after approval. Do not rebuild packages between environments.

For UAT and production, run the workflow in `plan` mode first. Review replacements and deletions, then rerun the identical environment, scope, commit, and release in `apply` mode.

## Rollback

Choose the last known-good immutable release identifier and rerun `Deploy infrastructure` for the affected environment. Terraform updates each Lambda back to that release path while leaving stateful services unchanged.

Infrastructure rollbacks should use a Git revert followed by the normal pipeline. Avoid manually editing Terraform state.

For an immediate campaign processing stop, set `kill_switch_enabled=true` in the
environment's `campaign-processing.tfvars` and deploy that stack. This disables
all campaign event-source mappings and lifecycle schedules without deleting data.
Emergency suppression of an already published campaign remains an audited review
operation, not a Terraform state edit.

## Secrets

Rotate runtime values with `aws secretsmanager put-secret-value` or an approved secret-management system. Terraform ignores secret contents and therefore does not overwrite rotations.

## Drift

Run a manual deployment for the environment and inspect the generated plans. Any unexpected replacement of Cognito, DynamoDB, or S3 resources must be investigated before approval.

## Destruction

Production artifact buckets do not allow force deletion, and the state bucket has Terraform deletion protection. Environment destruction must be an explicit, separately reviewed operation; it is not part of the deployment workflow.

Campaign data must be destroyed in reverse dependency order: `campaign-api`,
`campaign-processing`, then `campaign-data`. Production table deletion protection
must never be disabled without an approved retention/deletion record.
