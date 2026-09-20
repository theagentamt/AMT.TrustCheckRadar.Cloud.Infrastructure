# V1 URL consumer candidate

This independent, disabled-by-default Dev stack is the infrastructure candidate for the authenticated URL-check journey. It is not an active endpoint. Every environment file has `enabled = false`; no AWS deployment has been performed for this stack.

The three Python 3.14 ARM64 functions have separate roles:

| Function | Purpose | Allowed dependency writes/calls |
| --- | --- | --- |
| `url-consumer` | Prepare, admit, settle and reconcile one logical check | Transactional `V1#*` authority records; exact private assessment alias |
| `v1-entitlements` | Access snapshot and explicit trial activation | Transactional `V1#*` authority records; no provider invocation |
| `url-lease-recovery` | Release expired, unfinished reservations with zero deduction | Existing authority records and pending `GSI1`; no identity tables, secrets or provider invocation |

The consumer and entitlement functions can read authoritative account, deletion and active-device fences. They cannot mutate those identity tables. Only those two functions can read the separate HMAC key ring, with `AWSCURRENT` explicitly requested. No function receives the Google API key. The private assessment retains its separate storage-denied role.

## Release boundaries

- State: `trustcheckradar/dev/url-consumer.tfstate`. The API, foundation, resolver and assessment states remain separately owned.
- Candidate packages must identify a full source commit in the S3 path, exact object version and SHA-256. All tables, the private alias and artifact bucket must match the environment/account. The AWS provider is restricted to Dev's account `107827791950`.
- Consumer timeout is 29 seconds with concurrency two; recovery is 15 seconds with concurrency one; access/trial is ten seconds with concurrency two. Successful public activation will also require reviewed gateway and application deadlines.
- Runtime activation flags are hard-disabled. This revision creates no API route, public invocation policy, schedule, event source, secret version, authority grant or trial record. Setting `enabled` only provisions the inactive candidate after supplying reviewed artifacts.
- The HMAC secret container is separate from Web Risk credentials. Key material must be generated and stored outside Terraform; never put it in a tfvars file, output, command line or plan.
- Log groups retain fourteen days of operational diagnostics. Request/result retention is a different policy and is not selected by this stack.
- Automatic deployment excludes this root and its environment files. Use a reviewed manual Dev plan; broad infrastructure apply is not a substitute.

## Work required before activation

1. Pin the reviewed Lambda handlers, versioned mobile contract and private assessment deadline extension. The Android build must bind to that version and its explicit device-activation flow.
2. Record owner decisions for minimized result/receipt retention and one-time trial eligibility retention. Supply all authority horizons/rate configuration; do not infer consent from feature activation.
3. Wire account deletion to fence and erase every retained HMAC partition. Review key rotation without minting new allowance. No new raw URL or account reference is required for lease cleanup.
4. Add and validate the authenticated gateway routes and bounded pending-lease schedule. Expired results must become unreadable at the policy deadline; DynamoDB TTL is asynchronous and is not proof of physical deletion at that instant. Cleanup failures need monitoring and an operational repair path.
5. Add exact alarm permissions to the existing resolver SNS topic and verify delivery to the confirmed `support@andmorethings.com` subscription. No second email subscription is needed.
6. Establish real paid-period verification and purchase ownership before enabling paid access. A subscription's original `startTime` is not evidence of its current monthly period. Trial activation must be explicit; legacy free/pro/research allowances cannot grant V1 external access.
7. Review a saved Dev plan and IAM simulation, populate the HMAC key ring without exposing it, then test real account/device/allowance, ambiguous response, timeout, expiry and deletion races with synthetic data. Distinguish local mocked tests from deployed acceptance.

Until those gates are met, no public endpoint or Android external capability is advertised. The user-requested legacy Dev endpoint remains untouched.

## Local verification

`terraform init -backend=false`, `terraform validate` and `terraform test` validate this root with a mocked AWS provider. Mock test applies create no AWS resources. The helper's routing tests confirm independent state and no legacy artifact-release input. CI includes both checks.
