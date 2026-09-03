# Initial Setup

This guide supports either one AWS account containing all environments or a separate AWS account for each environment. Separate accounts provide the strongest production boundary.

## Prerequisites

- Terraform `1.12.1`
- AWS CLI authenticated as an administrator for the bootstrap only
- Permission to configure GitHub repository environments
- A Route 53 hosted zone for the production custom domain

When production uses a separate AWS account, the configured Route 53 zone must be in that account. Otherwise delegate the API subdomain to the production account or disable the custom domain until DNS ownership is arranged.

## 1. Create Remote State

Choose a globally unique bucket name. For separate AWS accounts, perform this step once in each account and use a different bucket name for each environment.

```bash
terraform -chdir=bootstrap/state-bucket init
terraform -chdir=bootstrap/state-bucket apply \
  -var="state_bucket_name=amt-trustcheckradar-ACCOUNT_ID-tfstate" \
  -var="aws_region=us-east-1"
```

The bucket has versioning, server-side encryption, blocked public access, bucket-owner-enforced ownership, TLS-only access, and deletion protection. Its small bootstrap state remains local and is ignored by Git; retain an encrypted administrative backup.

## 2. Create GitHub OIDC Access

Initialize the access stack against the bucket created above:

```bash
terraform -chdir=bootstrap/access init \
  -backend-config="bucket=amt-trustcheckradar-ACCOUNT_ID-tfstate" \
  -backend-config="key=trustcheckradar/bootstrap/access.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"

terraform -chdir=bootstrap/access apply \
  -var="state_bucket_name=amt-trustcheckradar-ACCOUNT_ID-tfstate"
```

For a separate environment account, limit the roles created in that account:

```bash
terraform -chdir=bootstrap/access apply \
  -var="state_bucket_name=amt-trustcheckradar-DEV_ACCOUNT_ID-tfstate" \
  -var='environments=["dev"]'
```

If the AWS account already has the GitHub OIDC provider, pass its ARN through `existing_github_oidc_provider_arn` instead of creating another provider.

The role trust policy matches the exact repository and GitHub environment subject. Do not replace that condition with a wildcard.

## 3. Configure GitHub Environments

Create `dev`, `staging`, and `prod` under repository settings. Define these environment variables in each one:

| Variable | Value |
| --- | --- |
| `AWS_REGION` | Target AWS region, currently `us-east-1` |
| `AWS_ROLE_ARN` | Matching `github_deploy_role_arns` bootstrap output |
| `TF_STATE_BUCKET` | State bucket for that environment/account |
| `TF_STATE_KEY_PREFIX` | `trustcheckradar` |
| `ARTIFACT_RELEASE` | Release deployed automatically to `dev` |

Environment variables are configuration, not credentials. AWS authorization is exchanged through GitHub OIDC.

Recommended protection:

- `dev`: deployments only from `main`; no manual reviewer.
- `staging`: deployments only from `main`; one reviewer.
- `prod`: deployments only from `main` or release tags; required reviewer; prevent self-approval and administrator bypass where the GitHub plan supports it.

Protect `main` with pull requests, required CI, and no direct pushes.

## 4. Create the Foundation

Run `Deploy infrastructure` manually with:

```text
environment: dev
deployment_scope: foundation
execution_mode: apply
artifact_release: leave empty
```

Repeat for staging and production when each environment is ready.

## 5. Publish and Deploy a Release

Upload immutable Lambda packages using [RELEASES.md](RELEASES.md), then run the deployment workflow with `deployment_scope=all`.

For staging and production, first run with `execution_mode=plan`, review all Terraform plan logs, and then rerun the same release with `execution_mode=apply`.

After API creation, populate these Secrets Manager containers using a restricted secret-management process:

```text
trustcheckradar/<environment>/openai
trustcheckradar/<environment>/google-play-service-account
```

The optional Web Risk secret is created only when its feature is enabled. Secret values are intentionally not managed by Terraform.
