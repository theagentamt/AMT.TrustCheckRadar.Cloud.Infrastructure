# Operations

## Deployment Order

Always deploy in this order:

1. Foundation
2. Artifact verification
3. API
4. Identity workflows

The GitHub deployment workflow enforces this sequence. Direct local changes should use `scripts/terraform.sh` and follow the same order.

## Promotion

Deploy a release to development, run API smoke tests, promote the identical package set to staging, then promote it to production after approval. Do not rebuild packages between environments.

For staging and production, run the workflow in `plan` mode first. Review replacements and deletions, then rerun the identical environment, scope, commit, and release in `apply` mode.

## Rollback

Choose the last known-good immutable release identifier and rerun `Deploy infrastructure` for the affected environment. Terraform updates each Lambda back to that release path while leaving stateful services unchanged.

Infrastructure rollbacks should use a Git revert followed by the normal pipeline. Avoid manually editing Terraform state.

## Secrets

Rotate runtime values with `aws secretsmanager put-secret-value` or an approved secret-management system. Terraform ignores secret contents and therefore does not overwrite rotations.

## Drift

Run a manual deployment for the environment and inspect the generated plans. Any unexpected replacement of Cognito, DynamoDB, or S3 resources must be investigated before approval.

## Destruction

Production artifact buckets do not allow force deletion, and the state bucket has Terraform deletion protection. Environment destruction must be an explicit, separately reviewed operation; it is not part of the deployment workflow.
