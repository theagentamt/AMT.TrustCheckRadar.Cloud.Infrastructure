# Dev resolver readiness and deployment attempt — 2026-09-20

Historical predeployment record. AWS sign-in was subsequently restored and the resolver deployed and verified in Dev. Use the [completed deployment report](../../URL-RESOLVER-DEV-DEPLOYMENT-2026-09-20.md) for current status, artifact version, live evidence and remaining notification setup.

## Authorization and ownership

The user authorized closing gaps and attempting Dev deployment of both infrastructure and Lambda. Lambda source, tests, packaging, fixture server and live invocation harness were delegated to the Lambda agent. This task owns infrastructure, IAM, state, monitoring, deployment and verification coordination. Existing analyzer and mobile integration remain unchanged.

## Completed locally

- Lambda agent hardened empty-query preservation, relative redirect semantics, encoded sensitive-link/path patterns and parse failure handling. Full suite: **419 tests and 208 subtests passed**. Nine fixture routes were checked against a local HTTP server. Local Python was 3.14; the ZIP targets Python 3.13 ARM64 with pure-Python dnspython. Actual runtime qualification remains a Dev smoke check.
- Infrastructure now includes a dedicated SNS alert topic, a source-account/exact-alarm restricted CloudWatch publishing policy, recovery notifications, optional owner-selected email subscription, and a Dev-only test role trusted by one verified same-account IAM role. Its sole permission is InvokeFunction on the resolver live alias.
- Added a separate disposable HTTP fixture Terraform root: one t4g.nano and restricted security group, no IAM instance profile/key pair/SSH, resolver-EIP-only ingress, encrypted disposable disk, termination-on-shutdown and a one-hour shutdown backstop. IMDSv2 is available only for bootstrap, then disabled. Fixture code is supplied by the Lambda agent. No fixture was provisioned.
- Added fixture CI validation and an infrastructure startup template. Persistent and temporary roots both validate. **8 main Terraform tests + 3 fixture Terraform tests passed**, with mocked AWS. **28 infrastructure script tests passed**. Formatting, ShellCheck and tracked whitespace checks passed.

## Candidate artifact — not published

- Local ZIP: `/tmp/amt-url-resolver-artifacts/url_redirect_resolver.zip`.
- SHA256: `d107988b44125b485f439678b2d34ae7debc287a2f4f4d32a17ab532b0666e6c`.
- Base64 SHA256: `0QeYi0QSW0hfQ5Z4stNK5968KHovT00yoXq1MrBmbmw=`.
- Proposed immutable key: `releases/url-resolver-dev-20260920-d107988b4412/url_redirect_resolver.zip`.
- Expected Dev artifact bucket from prior verified deployment records: `trustcheckradar-dev-107827791950-artifacts`. Reverify account and bucket/versioning after sign-in. No S3 object version exists from this deployment attempt; none has been fabricated in tfvars.

## Deployment attempt and blockers

The configured `trustcheckradar` AWS profile failed STS/SNS/S3 reads because its SSO token expired. A standard device sign-in flow was started for the user. Attempted initialization of the isolated S3 backend also failed with `No valid credential sources found` / `InvalidGrantException` while refreshing SSO. No enabled Terraform plan, apply, S3 upload, resource creation, Lambda invocation, alert message or fixture deployment occurred.

State target after sign-in: bucket `amt-trustcheckradar-107827791950-tfstate`, key `trustcheckradar/dev/url-resolver.tfstate`, region `us-east-1`, expected account `107827791950`. This state is separate from the existing API and foundation stacks. All committed environment enable flags remain false. Do not apply broad bootstrap/access drift to solve this authentication issue.

The alert email was requested but not supplied at the time of this record. SNS topic wiring is implemented; actual subscription and confirmation remain pending. Consumer EN/ES inspection notice text was drafted by the Lambda agent for later integration; no customer UI or consent flow was changed.

## Resume sequence

1. Complete AWS SSO sign-in, verify the actual account, region, Dev artifact bucket/versioning and state bucket. Resolve the IAM role ARN behind the SSO session for `dev_test_principal_arn`.
2. Reactivate the Lambda agent to conditionally publish the verified ZIP under the immutable key, and obtain/check the S3 version and SHA256. Do not overwrite an existing release object.
3. Populate only Dev artifact/test-principal inputs and the owner-supplied alert email. Generate and inspect a saved resolver plan. Expected changes are new resolver resources, not changes to the analyzer or other stacks. Networking baseline is about $36.50/month plus traffic/service usage; fixture costs are temporary.
4. Apply the reviewed saved Dev plan. Confirm Active/Successful state, runtime, code hash, alias version, VPC/subnet/ACL/SG rules, execution policies, invocation grants and absence of public invocation configuration.
5. Provision the isolated fixture with the reviewed Lambda-agent script, await its console-ready marker, disable metadata, and invoke the smoke harness through the narrow test role. Use a down-scoped session for a real denied invocation; inspect runtime log samples without exposing raw URLs. Verify SNS confirmation and actual test alert delivery when the owner has supplied/confirmed the recipient.
6. Destroy and verify cleanup of the temporary fixture; confirm persistent resolver Terraform has no unexpected drift. Record evidence and remaining release limitations. Only then begin the separately scoped analyzer integration through the Lambda agent.

The Lambda agent's harness exercises blocked input without network access, controlled HTTP behavior and an explicitly selected example.com HTTPS request. A private-IP redirect can be enabled using the fixture's local private address. Configuration inspection or application-level blocking is not independent proof that every network-layer rule is enforced; label evidence precisely. Real DNS rebinding, IPv6-only handling, unsupported browser navigation and consumer privacy integration must not be overstated by these fixtures.
