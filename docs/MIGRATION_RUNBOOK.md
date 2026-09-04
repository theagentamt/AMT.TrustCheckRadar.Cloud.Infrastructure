# Account Migration Runbook

This runbook separates browser work performed by the account owner from CLI work performed locally. Codex must not open, control, or sign in to the AWS or GitHub websites. The account owner completes every browser login, MFA challenge, billing action, and account-closure confirmation.

No destruction is authorized by this document. Inventory, backup, deletion, and account closure are separate checkpoints.

## Responsibility Boundary

| Activity | Owner |
| --- | --- |
| Open AWS or GitHub and sign in | Account owner |
| Complete MFA, device authorization, billing, and legal confirmations | Account owner |
| Install and run approved CLI tools | Codex |
| Display a CLI device URL and one-time code | Codex |
| Open the device URL and enter its code | Account owner |
| Run read-only inventory and verification commands | Codex |
| Run Terraform plans | Codex |
| Approve any resource deletion or account closure | Account owner, immediately before the action |

## Phase 1: Identify the Old Account

The account owner signs in to the old AWS account and records:

- Twelve-digit account ID and account name.
- Root email address and whether its domain is registered in this account.
- Whether the account is standalone, an Organizations member, or the Organizations management account.
- Organization ID and management account ID, when applicable.
- Business owner, billing owner, and technical owner.
- Whether the intended end state is workload deletion, account closure, or both.

Do not close an account whose root email depends on a Route 53 domain registered in that same account. Transfer the domain or change the root email first. AWS also recommends backing up required data and notes that outstanding commitments and charges can continue after closure. See [Close an AWS account](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-closing.html).

## Phase 2: Establish CLI Access

AWS CLI is installed locally. Prefer short-lived IAM Identity Center credentials rather than access keys.

The account owner first creates or confirms an IAM Identity Center user and grants the required read-only permission set in the AWS console. Then provide these nonsecret values:

```text
SSO start URL:
SSO Region:
AWS account ID:
Permission set or role name:
CLI profile name: trustcheckradar-old
```

Codex configures the profile and starts login without opening a browser:

```bash
aws configure sso --profile trustcheckradar-old --use-device-code
aws sso login --profile trustcheckradar-old --use-device-code --no-browser
```

Codex displays the device URL and code. The account owner opens that URL, signs in, enters the code, and reports completion. Codex then verifies only the expected account:

```bash
aws --profile trustcheckradar-old sts get-caller-identity
```

Reference: [Configure IAM Identity Center authentication with the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html).

## Phase 3: Inventory and Back Up

After CLI verification, Codex runs the repository's read-only inventory:

```bash
./scripts/aws-inventory.sh trustcheckradar-old
```

The ignored `.local/aws-inventory/` directory contains account identity, organization, global-service, and enabled-Region exports. Permission failures are retained as `.err` files and must be resolved rather than treated as empty results.

The inventory must be reconciled with these console-only checks by the account owner:

- Billing: current and prior-month charges, unpaid invoices, budgets, and tax settings.
- Commitments: Savings Plans and EC2, RDS, Redshift, or ElastiCache reservations.
- AWS Marketplace subscriptions.
- Route 53 registered domains, hosted zones, DNS records, and domain contacts.
- AWS Backup vaults, snapshots, exports, and retention requirements.
- CloudTrail, AWS Config, GuardDuty, Security Hub, and audit-log retention.
- Support plan and open support cases.
- IAM Identity Center, Organizations delegated administrators, and cross-account dependencies.

AWS Resource Explorer can help discover resources, but missing search results are not proof that the account is empty. Cross-Region results require appropriate permissions and an aggregator index. See [Using AWS Resource Explorer](https://docs.aws.amazon.com/resource-explorer/latest/userguide/using-search.html).

For every retained item, record its owner, export or transfer method, destination, verification evidence, and retention period. Secrets must be rotated after migration rather than copied into the repository.

## Checkpoint A: Approve Workload Deletion

Before any deletion, Codex presents:

- Verified AWS account ID and profile.
- Final inventory and unresolved `.err` files.
- Backup and transfer evidence.
- Terraform state locations and any resources that are not Terraform-managed.
- A deletion plan showing the exact resources and expected effect.

The account owner must explicitly approve that deletion plan. Approval to delete workloads does not authorize AWS account closure.

## Phase 4: Create the Business AWS Structure

Use a business-controlled AWS Organizations management account for organization and billing administration, and a separate member account for TrustCheckRadar workloads. AWS recommends keeping workloads out of the management account because service control policies do not restrict it. See [Best practices for the management account](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices_mgmt-acct.html).

The account owner performs these browser steps:

1. Sign in to the business management account.
2. Enable AWS Organizations with all features if it is not already enabled.
3. Confirm the management account uses a durable business email, phone number, payment method, and hardware or passkey MFA.
4. Enable IAM Identity Center and create the administrative user or group used for daily access.
5. In AWS Organizations, choose **AWS accounts**, **Add an AWS account**, then **Create an AWS account**.
6. Name the workload account `AMT TrustCheckRadar` and use a unique business-controlled email address.
7. Keep the default `OrganizationAccountAccessRole` unless the business has an established naming standard.
8. Assign IAM Identity Center access to the new member account.
9. Record the management account ID, workload account ID, organization ID, Identity Center start URL and Region, and permission-set name.

AWS documents the member-account procedure in [Creating a member account](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_create.html). The current architecture keeps `dev`, `staging`, and `prod` in this single workload member account, as previously selected.

Codex then configures a separate `trustcheckradar-new` CLI profile, starts a no-browser device login, and verifies the new workload account ID before applying Terraform.

## Phase 5: Bootstrap Deployment Access

After the new account is verified through CLI:

1. Codex creates the Terraform state bucket and GitHub OIDC roles from `bootstrap/`.
2. Codex reports the state bucket name and the `dev`, `staging`, and `prod` role ARNs.
3. The account owner signs in to GitHub and opens the repository.
4. Under **Settings**, **Environments**, create `dev`, `staging`, and `prod`.
5. Add the environment variables documented in [SETUP.md](SETUP.md).
6. Configure deployment-branch restrictions and reviewers supported by the repository's GitHub plan.
7. The account owner completes GitHub CLI device authorization only when Codex needs API verification.
8. Codex verifies the environment configuration through `gh` and runs the first foundation-only plan.

GitHub documents the console flow and plan limitations in [Managing environments for deployment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

## Checkpoint B: Approve Account Closure

Account closure is considered only after the new account and required data are independently verified. Codex presents a final closure checklist, but the account owner performs the closure in the AWS console.

The final checklist must confirm:

- The old account is the intended account ID and is not the business management account.
- Required data, domains, logs, and backups are accessible outside the old account.
- Marketplace subscriptions and avoidable paid resources are canceled.
- Outstanding invoices, reservations, Savings Plans, and support obligations are understood.
- Root email and MFA remain available throughout AWS's post-closure recovery period.
- Cross-account principals, DNS, CI/CD, and external integrations no longer depend on the account.

AWS currently provides a 90-day post-closure period during which an account can be reopened. Closure is asynchronous for an Organizations member account, and retained commitments can still generate charges. The account owner must review AWS's current closure page immediately before confirming the action.
