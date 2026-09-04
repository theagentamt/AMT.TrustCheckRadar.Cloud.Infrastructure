# Access and Setup Runbook

This deployment keeps the existing AWS account. Transferring its ownership, billing details, or business contact information does not change the infrastructure account ID and is outside this repository's deployment workflow.

Codex must not open, control, or sign in to the AWS or GitHub websites. The account owner completes every browser login, MFA challenge, device authorization, billing action, and account-management confirmation.

## Responsibility Boundary

| Activity | Owner |
| --- | --- |
| Open AWS or GitHub and sign in | Account owner |
| Complete MFA, device authorization, billing, and account changes | Account owner |
| Install and run approved CLI tools | Codex |
| Display a CLI device URL and one-time code | Codex |
| Open the device URL and enter its code | Account owner |
| Verify the authenticated account through CLI | Codex |
| Bootstrap and plan Terraform | Codex |
| Configure GitHub settings that require the website | Account owner |

Never provide passwords, MFA codes, access keys, secret values, or recovery codes in this repository or conversation.

## 1. Finish the Account Transfer

The account owner completes the business transfer directly in AWS. Before deployment, confirm that the existing account has:

- A durable business-controlled root email address and phone number.
- Root-user MFA and securely stored recovery information.
- Current business contact, tax, and payment details.
- A non-root administrative identity for routine work.
- The Route 53 hosted zone for `andmorethings.net`, or a documented DNS delegation plan.

Then provide only these nonsecret values:

```text
AWS account ID:
Primary deployment Region: us-east-1
CLI access method: IAM Identity Center or existing profile
```

## 2. Establish CLI Access

AWS CLI is installed locally. Prefer short-lived IAM Identity Center credentials over long-lived access keys.

For IAM Identity Center, provide these nonsecret values:

```text
SSO start URL:
SSO Region:
AWS account ID:
Permission set or role name:
CLI profile name: trustcheckradar
```

Codex configures the CLI profile and starts authentication with browser launch disabled:

```bash
aws sso login --profile trustcheckradar --use-device-code --no-browser
```

Codex displays the device URL and one-time code. The account owner opens the URL, signs in, enters the code, and reports completion. Codex verifies that the profile resolves to the expected account before any Terraform command:

```bash
aws --profile trustcheckradar sts get-caller-identity
```

Reference: [Configure IAM Identity Center authentication with the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html).

## 3. Bootstrap the Existing Account

After CLI identity verification, Codex:

1. Checks for conflicting state buckets, GitHub OIDC providers, IAM roles, and TrustCheckRadar resources.
2. Installs the pinned Terraform version.
3. Plans and applies `bootstrap/state-bucket` in the existing account.
4. Plans and applies `bootstrap/access` to create the `dev`, `uat`, and `prod` GitHub deployment roles.
5. Reports the state bucket name and role ARN for each environment.

All three environments use the same AWS account. Their Terraform state keys, resource names, IAM roles, and artifact buckets remain environment-specific.

## 4. Configure GitHub Environments

The account owner signs in to GitHub and performs these website steps:

1. Open `theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure`.
2. Open **Settings**, then **Environments**.
3. Create `dev`, `uat`, and `prod`.
4. Add the environment variables documented in [SETUP.md](SETUP.md).
5. Restrict deployments to `main`.
6. Add the protection rules and reviewers supported by the repository's GitHub plan.

No AWS access key is stored in GitHub. GitHub Actions exchanges its identity for short-lived AWS credentials through OIDC.

When GitHub CLI verification is needed, Codex starts the device flow and displays the URL and code without opening a browser. The account owner completes authorization and reports when it is finished.

Reference: [Managing environments for deployment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

## 5. Deploy in Order

The first deployment remains intentionally staged:

1. Deploy the `dev` foundation.
2. Build and upload immutable Lambda packages when application code is available.
3. Deploy the `dev` API and identity workflows.
4. Promote the same package set to UAT and production after plan review and approval.

See [RELEASES.md](RELEASES.md) and [OPERATIONS.md](OPERATIONS.md) for release and promotion procedures.
