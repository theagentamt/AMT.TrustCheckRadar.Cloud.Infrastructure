# Initial Setup

This deployment uses one existing AWS account for `dev`, `staging`, and `prod`. Environment-specific state keys, names, roles, and artifact buckets keep the deployments independent within that account.

## Prerequisites

- Terraform `1.12.1`
- AWS CLI authenticated as an administrator for the bootstrap only
- Permission to configure GitHub repository environments
- A Route 53 hosted zone for the production custom domain

Complete the account-owner actions in [ACCESS_RUNBOOK.md](ACCESS_RUNBOOK.md) before bootstrap. The production Route 53 hosted zone must be available in this account, or DNS delegation must be arranged before enabling the custom domain.

## 1. Create Remote State

Choose a globally unique bucket name. Create this shared state bucket once in the existing account; each environment uses a separate object key.

```bash
terraform -chdir=bootstrap/state-bucket init -backend=false
terraform -chdir=bootstrap/state-bucket apply \
  -var="state_bucket_name=amt-trustcheckradar-ACCOUNT_ID-tfstate" \
  -var="aws_region=us-east-1"

terraform -chdir=bootstrap/state-bucket init -migrate-state -force-copy \
  -backend-config="bucket=amt-trustcheckradar-ACCOUNT_ID-tfstate" \
  -backend-config="key=trustcheckradar/bootstrap/state-bucket.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
```

The bucket has versioning, server-side encryption, blocked public access, bucket-owner-enforced ownership, TLS-only access, and deletion protection. Initial creation uses temporary local state because the backend does not exist yet; the second initialization migrates that state into the protected bucket.

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

If the AWS account already has the GitHub OIDC provider, pass its ARN through `existing_github_oidc_provider_arn` instead of creating another provider.

The role trust policy matches the repository's immutable owner and repository IDs plus the exact GitHub environment subject. If the repository is transferred or recreated, update those IDs before applying. Do not replace the subject condition with a wildcard.

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
