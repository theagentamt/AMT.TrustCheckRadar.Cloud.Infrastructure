# URL resolver Dev deployment — 2026-09-20

Status: deployed and verified in Dev. The resolver is independently callable through its restricted test role; it is not connected to the consumer URL analyzer. Email alert delivery is pending an owner-selected, confirmed recipient.

## Ownership and scope

The user authorized addressing gaps and deploying infrastructure and Lambda. The Lambda agent owned source hardening, testing, packaging, immutable publication, the fixture server, live smoke and log-privacy checks. This task owned Terraform, AWS deployment, IAM/network verification, monitoring and fixture cleanup.

Verified account `107827791950`, region `us-east-1`, using the existing `trustcheckradar` SSO administrator session. No broad bootstrap apply, existing analyzer modification, mobile integration, Google API call, UAT/Prod change or Git push occurred. YouTrack was updated afterward at the user's request; see the tracking record below.

## Deployed service

- Function: `trustcheckradar-dev-url-resolver`; Python 3.13 ARM64, 256 MiB, 12-second timeout, reserved concurrency 5.
- Live alias: `arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-resolver:live`, version **1**, State **Active**, LastUpdateStatus **Successful**.
- Artifact: `s3://trustcheckradar-dev-107827791950-artifacts/releases/url-resolver-dev-20260920-d107988b4412/url_redirect_resolver.zip`.
- S3 version: `WEvxJt8eMNpmlnqfliCyw_SSncSAKaOT`; 336116 bytes.
- Base64 SHA256: `0QeYi0QSW0hfQ5Z4stNK5968KHovT00yoXq1MrBmbmw=`. Independently checked against the versioned S3 object and deployed function.
- Dev test role: `arn:aws:iam::107827791950:role/trustcheckradar-dev-url-resolver-dev-test`; trusts only the verified same-account SSO role and grants InvokeFunction only on the live alias. No analyzer invocation grant was added.
- Log group: `/aws/lambda/trustcheckradar-dev-url-resolver`, 14-day retention.
- Alert topic: `arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts`; errors, throttles and partial-result alarms publish to it, with recovery actions. CloudWatch publishing is constrained to this account and those three exact alarm ARNs.
- Network: dedicated VPC `vpc-0606b53b0577c1464`, private subnet `subnet-0c1244a1a20c08cf8`, security group `sg-013657f703672940f`, NAT `nat-0481a24acf6658cb1`, egress IPv4 `98.82.242.45`. This egress address belongs to the resolver, which does not call Google; it is not the unchanged analyzer's outbound address.
- State: `amt-trustcheckradar-107827791950-tfstate`, key `trustcheckradar/dev/url-resolver.tfstate`.

## Apply and verification evidence

The reviewed saved plan added **44 resources**, with no updates or deletions to existing resources. AWS rejected the initial SNS policy's `sns:*` administration action with `Policy statement action out of service scope`. Terraform finished creating the remaining service resources. The policy was corrected to the eight supported topic actions; a second reviewed plan applied only that policy. Its restricted CloudWatch statement was then read back and verified. The final full resolver plan reported **no changes**.

- Lambda agent's local suite: **419 tests and 208 subtests passed**; resolver subset **77 passed**. Local Python was 3.14, followed by actual deployed Python 3.13 verification.
- Infrastructure: **8 resolver + 3 fixture mocked Terraform tests passed**, both roots validated, **28 script tests passed**, formatting/ShellCheck/whitespace checks passed.
- **22 live smoke cases passed** using assumed-role credentials from the narrow Dev test role, not administrator invocation. Cases covered metadata/private/loopback blocking, injected controls, userinfo, sensitive encodings, unsupported schemes, public HTTPS, owned HTTP terminal/relative/nested redirects, loops, private-IP/metadata redirects, sensitive redirects, request limits, timeouts, oversized headers, duplicate Location, Refresh and explicit empty-query semantics.
- A real unqualified-function invocation from that role was denied with `AccessDeniedException`.
- **22 CloudWatch application events** had only the approved telemetry fields, with zero raw input/check-ID markers or unexpected schemas in the audit. No raw log content was persisted in evidence.
- Live subnet ACL inspection verified all **15 non-public/special-use CIDR denies** before the only allowed outbound ports, **80 and 443**. The function has no public Function URL or event-source mapping.
- IAM simulation returned explicit denies for Secrets Manager, DynamoDB, S3 and STS role assumption, and for EC2 interface management when the function-code source-ARN context is present. Simulation is distinguished from the actual denied invocation above.

Sanitized results are in [deployment evidence](planning/amt-digital-safety-v1-proposal/url-resolver-dev-evidence/infrastructure-verification.json), [smoke cases](planning/amt-digital-safety-v1-proposal/url-resolver-dev-evidence/lambda-smoke.jsonl), [denied invocation](planning/amt-digital-safety-v1-proposal/url-resolver-dev-evidence/lambda-denied-invoke.json), and [log audit](planning/amt-digital-safety-v1-proposal/url-resolver-dev-evidence/lambda-log-privacy.json). The Lambda repository also contains `docs/url-resolver-dev-deployment-handoff.md` and its sanitized evidence.

## Temporary fixture cleanup

A separate two-resource local-state plan created an owned HTTP fixture on `i-02c7db66fbe2e2a29` with security group `sg-0b69d25642411c001`. HTTP ingress was restricted to the resolver's NAT IPv4. It had no IAM profile/key pair/SSH; IMDSv2 was available only for cloud-init bootstrap and then disabled before testing. Fixture script SHA256: `2a57951efa0ffc0e39ccc3e612eef5105a405b5b6b80f9e4851353ecb2d0a051`.

After testing, a reviewed cleanup plan destroyed only that instance and its security group. AWS independently confirmed the instance terminated, its root volume was deleted and the security group no longer existed. [Cleanup evidence](planning/amt-digital-safety-v1-proposal/url-resolver-dev-evidence/fixture-cleanup-verification.json). No temporary fixture remains billing.

## Remaining work and limits

1. Supply `notification_email`, apply that isolated subscription change and complete AWS SNS confirmation. At verification there were **zero confirmed and zero pending subscriptions**; no email delivery is claimed. Topic/alarms are deployed, but operational notification delivery is not complete.
2. The Lambda agent's next separate work is analyzer integration: Google Lookup, authenticated access/allowance/idempotency, response interpretation, preserved threat evidence and English/Spanish consumer messaging. Infrastructure supplies only the required invocation/monitoring changes. No Google key is required by the resolver.
3. HTTP-chain completion is not a safety verdict or a browser-final-destination guarantee. IPv6-only links, nonstandard ports, JavaScript/interactive navigation and some sensitive links remain unsupported. The EN/ES inspection notice is drafted; consumer privacy integration is not deployed.
4. Owned live TLS-failure and DNS-rebinding fixtures were not run; those paths have local tests. Application-level blocking and configuration inspection are not blanket proof of every independent network-layer attack path. This is Dev qualification, not a production launch sign-off.
5. The persistent single-AZ NAT/public IPv4 baseline is about **$36.50/month**, plus traffic and service usage. Setting Lambda concurrency to zero does not stop network charges. See [deployment/security contract](../terraform/url-resolver/README.md) for cost sources and operation details.

Source, Dev tfvars and sanitized evidence are included in infrastructure implementation commit `3e8370d8faf3db2bff7c4e45e1108c970030d0e0` on `codex/url-resolver-dev`. The corresponding Lambda commit is `c6507610639f233aee1b0287f4e03c769da2d783` on the same branch name in its repository. These are local commits; no push is included.

After the user requested committing and tracker synchronization, [SECUR4ALL-112](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-112) and [SECUR4ALL-242](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-242) were updated with those commits, artifact identity, local/live verification, cleanup and remaining work. Both states were set to **In Progress**, and saved comments `7-1101` and `7-1102` were read back and verified. The resolver still needs consumer integration, and the broader infrastructure story includes undelivered entitlement work. Neither is claimed Done; notification recipient setup remains pending.

Do not reset `enabled=false` merely to pause traffic: that would request resource destruction. UAT and Prod remain disabled.
