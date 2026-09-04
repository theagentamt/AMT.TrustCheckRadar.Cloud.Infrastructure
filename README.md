# AMT TrustCheckRadar Cloud Infrastructure

Terraform infrastructure for TrustCheckRadar, organized for isolated `dev`, `staging`, and `prod` deployments through GitHub Actions.

## Architecture

Each environment has three independently locked remote states:

1. `foundation` creates Cognito, DynamoDB, the versioned Lambda artifact bucket, and shared IAM roles.
2. `api` reads the foundation contract and creates Secrets Manager containers, Lambda functions, API Gateway, logs, and optional DNS/ACM resources.
3. `identity-workflows` reads the same contract and creates the Cognito PostConfirmation Lambda and trigger binding.

State object keys follow this convention:

```text
trustcheckradar/<environment>/foundation.tfstate
trustcheckradar/<environment>/api.tfstate
trustcheckradar/<environment>/identity-workflows.tfstate
```

Foundation outputs are passed to downstream stacks through a versioned remote-state contract. Resource IDs are not duplicated in environment variable files.

## Repository Layout

```text
bootstrap/
  state-bucket/          # One-time S3 remote-state bootstrap
  access/                # GitHub OIDC provider and environment deployment roles
environments/
  dev/                   # Nonsecret development values
  staging/               # Nonsecret staging values
  prod/                  # Nonsecret production values
terraform/
  foundation/
  api/
  identity-workflows/
scripts/
  terraform.sh           # Consistent local Terraform entry point
.github/workflows/
  ci.yml                 # Format and validate every change
  deploy.yml             # Ordered, environment-gated deployments
```

## Delivery Model

- Pull requests and pushes run recursive formatting and validation.
- A push to `main` deploys `dev` using the release configured in the GitHub `dev` environment.
- Staging and production are promoted with the `Deploy infrastructure` workflow.
- Manual deployments default to plan-only mode; rerun with `execution_mode=apply` after reviewing the plan.
- GitHub obtains short-lived AWS credentials through OIDC. No AWS access keys are stored in GitHub.
- One deployment can run per environment at a time.
- Foundation is applied before dependent stacks.
- The pipeline verifies every required Lambda zip before changing API or identity resources.
- Lambda objects live under `releases/<release-id>/` and are never overwritten.
- Production applies should be protected by required reviewers in the GitHub `prod` environment.

## First Deployment

The initial deployment is intentionally two-stage because the artifact bucket must exist before application packages can be uploaded:

1. Bootstrap remote state and GitHub OIDC by following [docs/SETUP.md](docs/SETUP.md).
2. Run `Deploy infrastructure` with `deployment_scope=foundation`.
3. Upload the release artifacts listed in [docs/RELEASES.md](docs/RELEASES.md).
4. Run the workflow again with `deployment_scope=all` and the same release identifier.
5. Populate the created Secrets Manager containers before sending traffic.

## Local Commands

Terraform `1.12.1`, AWS credentials, and the AWS CLI are required.

```bash
export TF_STATE_BUCKET="your-terraform-state-bucket"
export AWS_REGION="us-east-1"
export ARTIFACT_RELEASE="2026.09.03-1"

./scripts/terraform.sh plan dev foundation
./scripts/terraform.sh plan dev api "$ARTIFACT_RELEASE"
./scripts/terraform.sh plan dev identity-workflows "$ARTIFACT_RELEASE"
```

Do not run raw Terraform commands against a stack already initialized for another environment. The helper always reconfigures the backend to the selected environment.

## Configuration Rules

- Commit only nonsecret values in `environments/`.
- Store deployment settings such as role ARN and state bucket in GitHub environment variables.
- Store runtime credentials only in AWS Secrets Manager.
- Never commit state, plans, `.auto.tfvars`, backend files, or zip artifacts.
- Promote the same immutable application release through environments.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for design decisions, [docs/OPERATIONS.md](docs/OPERATIONS.md) for deployment and recovery procedures, and [docs/MIGRATION_RUNBOOK.md](docs/MIGRATION_RUNBOOK.md) for the old-account migration and console/CLI responsibility boundary.
