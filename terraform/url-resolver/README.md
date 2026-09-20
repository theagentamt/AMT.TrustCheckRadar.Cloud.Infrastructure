# Standalone URL redirect resolver

Independent infrastructure for `url_redirect_resolver.zip` from the Lambda repository. It does not modify the API stack, URL analyzer, mobile routes, Google credentials or existing secrets. Dev was deployed and verified on 2026-09-20; its version-pinned configuration is enabled, with only a restricted Dev test caller. UAT and Prod remain disabled. See [initial deployment evidence](../../docs/URL-RESOLVER-DEV-DEPLOYMENT-2026-09-20.md) and [current Python 3.14 migration](../../docs/URL-RESOLVER-PYTHON314-MIGRATION.md).

## Resources and security boundary

- Dedicated IPv4 VPC, one private Lambda subnet and one public NAT subnet in one AZ. No application data stores, peering, public function URL or API Gateway route.
- Private subnet ACL denies 15 conservative non-public/special-use destination ranges before allowing TCP 80/443. Security group has no ingress and only those outbound ports. NAT provides internet access and a stable public IPv4 address. No IPv6 route or grant exists; the Lambda reports IPv6-only destinations as unsupported.
- AWS-managed VPC DNS is used by the bounded resolver. Security groups/ACLs do not filter AmazonProvidedDNS or all link-local service traffic; application validation remains mandatory. Do not present the ACL alone as complete SSRF protection. The execution role has no user data or provider secret access; explicit denies also protect those services from accidental later grants.
- Lambda ENI management permissions are required for VPC attachment. A `lambda:SourceFunctionArn` deny prevents function code from exercising those EC2 permissions while permitting Lambda service operations.
- Python 3.14 ARM64, 256 MiB, 12-second timeout; application deadline ten seconds, five redirects/six requests, 16 KiB bounded header reads. Reserved concurrency defaults to five and can be set to zero to pause invocation.
- Version-pinned S3 ZIP plus source SHA256; published Lambda version behind `live` alias. Selected same-account roles receive only `lambda:InvokeFunction` on that alias. Empty caller list creates no grants. This does not revoke existing administrator or wildcard IAM grants elsewhere in the account; audit caller access before release.
- Callers must invoke synchronously with SDK retries disabled. Async error retries on the alias are disabled as defense in depth, but Lambda can still deliver asynchronous events more than once. Do not use async invocation for URL inspection; caller idempotency remains required.
- Fourteen-day logs contain outcome codes and counts, not URLs. Runtime errors/throttles and partial-result metrics have alarms routed to a dedicated SNS topic. Its CloudWatch publishing policy accepts only this account's three resolver alarm ARNs. `alarm_action_arns` can add existing destinations; `notification_email` adds the owner's chosen email subscription, which requires SNS confirmation before delivery. No address is invented when it is unset. No raw event tracing, asynchronous payload destinations or request logging is provisioned.
- Optional `dev_test_principal_arn` creates a separate Dev acceptance role trusted by one exact same-account IAM role. It can invoke only the resolver's `live` alias. It is rejected in UAT/Prod and does not grant the analyzer access. Use a restrictive STS session policy for negative invocation tests; never output the assumed-role credentials.

Provisioning incurs NAT gateway, public IPv4, Lambda, logging and alarm charges. The single-AZ network keeps the initial topology small but is not multi-AZ resilient. No resources or charges are created by the disabled configuration. Review availability and estimated cost before applying an enabled plan.

For us-east-1, budget about $36.50 per 730-hour month for NAT ($0.045/hour) and one public IPv4 address ($0.005/hour), plus NAT processing, data transfer and other service usage. References: [AWS NAT pricing example for Northern Virginia](https://aws.amazon.com/network-firewall/pricing/), [AWS public IPv4 pricing](https://aws.amazon.com/vpc/pricing/). Disabling reserved concurrency pauses invocation but does not stop NAT or IPv4 charges.

## Deployment inputs

Build the artifact in the Lambda repository:

```sh
bash scripts/build_lambda_zip.sh --function url_redirect_resolver --python-version 3.14 --arch arm64
```

Publish it under an immutable `releases/<release>/url_redirect_resolver.zip` key in the existing versioned artifact bucket, using the repository's publishing process (or an explicitly reviewed single-artifact upload). Record the returned S3 version and base64 ZIP SHA256. Do not redeploy the analyzer merely to publish this separate artifact.

Populate the relevant environment's `url-resolver.tfvars`:

```hcl
enabled = true
artifact = {
  bucket         = "<existing-artifact-bucket>"
  key            = "releases/<release>/url_redirect_resolver.zip"
  object_version = "<actual-S3-object-version>"
  source_hash    = "<base64-SHA256-of-ZIP>"
}
caller_role_names = ["<existing-development-invocation-role>"]
```

For standalone acceptance, leave `caller_role_names=[]` and set `dev_test_principal_arn` to the verified deployment IAM role ARN (not its STS session ARN). Set `notification_email` only from the owner's supplied address. Both remain unset until those inputs are available.

No Google key or Secrets Manager value belongs in this stack. Production/UAT files remain disabled until their own reviewed promotion.

```sh
bash scripts/terraform.sh plan dev url-resolver
# Review the enabled plan before applying it.
bash scripts/terraform.sh apply dev url-resolver
bash scripts/terraform.sh output dev url-resolver
```

The helper requires TF_STATE_BUCKET and uses `<prefix>/<environment>/url-resolver.tfstate`; no analyzer artifact-release argument is required. Use the output `downstream_contract.invoke_arn` for IAM-authorized SDK/CLI tests. Example payload:

```json
{"schemaVersion":1,"checkId":"dev-fixture-001","url":"https://example.com/"}
```

The Lambda returns protocol traversal facts, never a safety verdict. `http_chain_complete` means a supported HTTP terminal response was observed; a 200 preview page may still require browser interaction. HTTP warnings remain separate from eventual scam risk. Sensitive-link pattern blocking is conservative and incomplete; consumer disclosure and approved path/query handling remain release requirements.

## Validation and release checks

```sh
terraform -chdir=terraform/url-resolver init -backend=false
terraform -chdir=terraform/url-resolver validate
terraform -chdir=terraform/url-resolver test
python3 -m unittest discover -s scripts/tests -p 'test_terraform_helper.py'
```

Terraform tests use a mocked AWS provider and never create cloud resources. Before enabling consumer traffic, run Dev tests with owned redirect fixtures: public redirects, private destinations, changing/mixed DNS, sensitive-link rejection, loops, TLS errors, time/size limits, unauthorized invocation, and no raw input in logs. Verify deployed routing/ACL/IAM enforcement and the actual packaged artifact. Do not use customer reset links or arbitrary live phishing URLs as fixtures.

The later analyzer integration owns account access, allowances, retries/idempotency, Google Lookup, per-chain threat evidence, and the final bilingual result. This stack exports only its private invocation contract.

The [disposable acceptance fixture](acceptance-fixture/README.md) is a separate local-state root. It can exercise owned HTTP redirects with ingress restricted to the resolver EIP. The Lambda agent owns the fixture script and live smoke harness in the Lambda repository. Remove the fixture immediately after testing and verify cleanup; it is not part of ongoing service infrastructure.

References: [AWS Lambda VPC and execution-role guidance](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html), [AWS network ACL limitations](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html), [OWASP SSRF guidance](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html).

## Reviewed Dev releases through GitHub

`.github/workflows/resolver-release.yml` supplies a manually dispatched **Dev code-release** path. It runs only on `main`, uses the existing `dev` GitHub environment and OIDC role, and shares `terraform-dev` concurrency with the environment deployment workflow. It operates only on the independent resolver state. The existing automatic environment workflow still does not deploy the resolver.

This path is deliberately limited to updates of the existing function's pinned artifact, its `live` version and reserved concurrency. It rejects initial creation, deletion/replacement, IAM, networking, runtime configuration and other resource changes. Those need a separately reviewed infrastructure plan; this workflow is not a general provisioning or UAT/Prod promotion tool.

Before first use:

1. Review/merge the implementation. `workflow_dispatch` must exist on the default branch, and existing OIDC trust requires `main`. Do not weaken branch/environment trust to execute a feature branch. Resolver-only paths are excluded from the broad main-push deployment trigger. Workflow-only changes require explicit dispatch. A merge containing other legacy stack changes can still trigger the broader deployment and must be reviewed for that scope.
2. The owner explicitly approved and applied the Dev-only `read-existing-url-resolver` policy supplement in `bootstrap/access/url-resolver.tf`. It grants bounded network, SNS and alarm inspection for refresh, with no new network writes. Existing deploy-role Lambda/IAM/S3/log permissions remain unchanged. Live readback matches the reviewed one-resource apply, the policy has no drift, and seven custom-policy simulations passed. Actual OIDC execution remains pending review/merge; simulations do not establish the entire role's effective privileges.
3. Confirm GitHub Dev variables: `AWS_ROLE_ARN`, `AWS_REGION=us-east-1`, `TF_STATE_BUCKET=amt-trustcheckradar-107827791950-tfstate`, and `TF_STATE_KEY_PREFIX=trustcheckradar` (or unset for that default).

For each release, commit the exact artifact bucket/key/S3 version/SHA256 to Dev tfvars. Dispatch **plan** with the full reviewed main SHA. The verifier checks the account, planned function's artifact mapping and actual downloaded versioned ZIP bytes; it reports `reviewedPlanDigest`. Review the Terraform plan, artifact provenance and digest. Dispatch **apply** at the same SHA with that digest. It re-plans, rejects changed state/intent, then applies that exact saved plan and checks drift. Plans/JSON are temporary runner files and are removed rather than uploaded as artifacts. The digest is a change-consistency check, not independent human approval or a replacement for GitHub access controls.

Rollback is the same process with a previously qualified resolver artifact tuple, committed to Dev tfvars. Never select an unqualified binary just because it exists in S3. This resolver returns traversal facts and has no entitlement authority. A future analyzer/entitlement rollback must separately validate authority, accounting, cache and schema compatibility; legacy FREE/research-bonus binaries are not approved V1 rollback targets. Use concurrency zero, not `enabled=false`, to pause invocation while preserving infrastructure. The dedicated workflow supports that bounded concurrency update after plan review.

Validation: 39 Python helper tests (including 11 release guardrail tests), Actionlint, a real read-only Dev no-change plan and exact-version artifact hash verification. The separately approved read-policy apply is recorded above. No GitHub release, production rollout or rollback execution is implied by these checks.

References: [GitHub manual workflow triggers](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow), [GitHub environment protections](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments), [EC2 authorization reference](https://docs.aws.amazon.com/service-authorization/latest/reference/list_ec2.html), [SNS authorization reference](https://docs.aws.amazon.com/service-authorization/latest/reference/list_sns.html).
