# Architecture Decisions

## Environment Isolation

Every resource name and tag contains the environment. Every environment and stack uses a distinct state object and lock file. GitHub deployment concurrency prevents two applies from racing against the same environment.

Using separate AWS accounts is recommended for production. The same code also supports a single account because resource names, artifact buckets, IAM roles, and state keys remain environment-specific.

## Stack Boundaries

`foundation` owns long-lived stateful services. `api` owns independently deployable request-processing infrastructure. `identity-workflows` owns the Cognito trigger integration that must run after the user pool and artifact bucket exist.

Keeping these states separate limits routine API deployments from locking or rewriting the stateful foundation. Downstream stacks read only the `downstream_contract` foundation output, whose `schema_version` is checked before planning.

## State

The S3 backend uses native lock files with `use_lockfile=true`; no DynamoDB lock table is required. Bucket versioning provides state recovery. The CI role can update only its environment state prefix.

State remains sensitive even when outputs are marked nonsensitive. Access to the state bucket should be restricted to administrators and the environment deployment role.

## AWS Authentication

GitHub Actions uses an AWS IAM OIDC provider. Each deploy role accepts tokens only when the `aud` claim is `sts.amazonaws.com`, the `sub` claim exactly matches this repository and one GitHub environment, and the workflow is running from `main`.

The bootstrap policy is a service-limited deployment baseline for the resources in this repository. Review CloudTrail after initial deployments and narrow actions further as the resource model stabilizes.

## Artifacts and Secrets

Terraform references immutable release paths instead of mutable object names. Application packaging is expected to happen in the application repository; this repository verifies and deploys those packages.

Terraform creates Secrets Manager containers and IAM access, but it does not create secret values. This keeps credentials out of Terraform configuration, plans, and state.

## Cognito Trigger

The AWS provider manages Lambda configuration as part of the full Cognito user-pool resource, but does not provide an independent trigger-binding resource. Because the user pool and workflow have separate states, the identity stack uses a guarded Python helper that reads the current pool configuration, merges `PostConfirmation`, and writes the complete mutable configuration back. The step runs through `terraform_data` and is repeatable in GitHub-hosted runners.
