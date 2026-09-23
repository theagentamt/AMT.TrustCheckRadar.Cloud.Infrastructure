# V1 URL consumer candidate

This document preserves the initial provisioning procedure. Authenticated
routes, a fourth deletion worker, maintenance schedules and alarms have since
been provisioned and qualified with bounded synthetic fixtures. Execution gates
remain closed. See the [engineering evidence](../../docs/URL-CONSUMER-ENGINEERING-INTEGRATION.md)
and [current access integration](../../docs/V1-ACCESS-INTEGRATION.md) before using
the historical resource counts or activation checklist below.

This independent stack provisions the inactive Dev candidate for the authenticated URL-check journey. Dev was manually provisioned on 2026-09-20 with all runtime gates false; UAT and Production remain unprovisioned. It is not an active endpoint. See [manual deployment evidence](../../docs/URL-CONSUMER-MANUAL-DEV-2026-09-20.md).

The three Python 3.14 ARM64 functions have separate roles:

| Function | Purpose | Allowed dependency writes/calls |
| --- | --- | --- |
| `url-consumer` | Prepare, admit, settle and reconcile one logical check | Transactional `V1#*#*` authority records; exact private assessment alias |
| `v1-entitlements` | Access snapshot and explicit trial activation | Transactional `V1#*#*` authority records; no provider invocation |
| `url-lease-recovery` | Release expired, unfinished reservations with zero deduction | Existing authority records and pending `GSI1`; no identity tables, secrets or provider invocation |

The consumer and entitlement functions can read authoritative account, deletion and active-device fences. They cannot mutate those identity tables. Only those two functions can read the separate HMAC key ring, with `AWSCURRENT` explicitly requested. No function receives the Google API key. The private assessment retains its separate storage-denied role.

## Release boundaries

- State: `trustcheckradar/dev/url-consumer.tfstate`. The API, foundation, resolver and assessment states remain separately owned.
- Candidate packages must identify a full source commit in the S3 path, exact object version and SHA-256. All tables, the private alias and artifact bucket must match the environment/account. The AWS provider is restricted to Dev's account `107827791950`.
- Consumer timeout is 29 seconds with concurrency two; recovery is 15 seconds with concurrency one; access/trial is ten seconds with concurrency two. Successful public activation will also require reviewed gateway and application deadlines.
- Runtime defaults are disabled; the separately reviewed engineering mode requires exact synthetic subjects, policy configuration, routing, monitoring and deletion infrastructure. General customer activation is unavailable. This revision creates no API route, public invocation policy, schedule, event source, secret version, authority grant or trial record. Setting `enabled` only provisions the inactive candidate after supplying reviewed artifacts.
- The HMAC secret container is separate from Web Risk credentials. Key material must be generated and stored outside Terraform; never put it in a tfvars file, output, command line or plan.
- Log groups retain fourteen days of operational diagnostics. Request/result retention is a different policy and is not selected by this stack.
- Automatic deployment excludes this root and its environment files. Use a reviewed manual Dev plan; broad infrastructure apply is not a substitute.

## Work required before activation

1. Pin the reviewed Lambda handlers, versioned mobile contract and private assessment deadline extension. The Android build must bind to that version and its explicit device-activation flow.
2. The owner approved seven-day minimized receipt retention and trial eligibility until account deletion on 2026-09-20. Supply and enforce the explicit horizons, physical expiry cleanup and account-deletion controls; see [engineering integration](../../docs/URL-CONSUMER-ENGINEERING-INTEGRATION.md).
3. Wire account deletion to fence and erase every retained HMAC partition. Review key rotation without minting new allowance. No new raw URL or account reference is required for lease cleanup.
4. Add and validate the authenticated gateway routes and bounded pending-lease schedule. Expired results must become unreadable at the policy deadline; DynamoDB TTL is asynchronous and is not proof of physical deletion at that instant. Cleanup failures need monitoring and an operational repair path.
5. Add exact alarm permissions to the existing resolver SNS topic and verify delivery to the confirmed `support@andmorethings.com` subscription. No second email subscription is needed.
6. Establish real paid-period verification and purchase ownership before enabling paid access. A subscription's original `startTime` is not evidence of its current monthly period. Trial activation must be explicit; legacy free/pro/research allowances cannot grant V1 external access.
7. Review a saved Dev plan and IAM simulation, populate the HMAC key ring without exposing it, then test real account/device/allowance, ambiguous response, timeout, expiry and deletion races with synthetic data. Distinguish local mocked tests from deployed acceptance.

Until those gates are met, no public endpoint or Android external capability is advertised. The user-requested legacy Dev endpoint remains untouched.

## Local verification

`terraform init -backend=false`, `terraform validate` and `terraform test` validate this root with a mocked AWS provider. Mock test applies create no AWS resources. The helper's routing tests confirm independent state and no legacy artifact-release input. CI includes both checks.

## Manual Dev release procedure

GitHub Actions is not required for a reviewed Dev candidate deployment. Use the
same immutable source and local validation; a manual deployment does not merge a
pending Android pull request or satisfy its missing acceptance evidence.

1. Confirm the AWS profile resolves to account `107827791950` in `us-east-1`.
   Renew SSO interactively if expired. Read dependency metadata only; never read
   the Web Risk secret value. Capture the current resolver, assessment and legacy
   Web Risk versions/configuration so their unchanged state can be verified.
2. Build the three packages from one full reviewed Lambda commit. Verify ZIP
   structure, Python 3.14 ARM64 dependencies and SHA-256 locally. Upload only those
   exact files to the versioned Dev artifact bucket, using full commit release
   paths. Record the returned object versions and verify object checksums.
3. Supply the exact live dependency ARNs/Cognito identifiers and immutable artifact
   references in a reviewed Dev variable file. `enabled = true` provisions the
   candidate only: all five runtime approval/activation flags remain false.
4. Initialize only `terraform/url-consumer` with the independent encrypted remote
   state and locking. Save and inspect the plan. Expect only this root's three
   functions, separate roles/policies/log groups, aliases/invocation settings and
   the empty HMAC secret container. Reject unrelated updates or deletions.
5. Apply that exact saved plan. Verify published versions, code hashes, ARM64,
   Python runtime, timeouts/concurrency and false flags. Invoke each disabled
   handler with an empty synthetic event: consumer/access must return unavailable,
   recovery must report disabled, and no provider call or authority write is
   expected. This checks actual Lambda package loading, not enabled integration.
6. Verify the legacy endpoint, private assessment and resolver are unchanged; run
   a final no-drift plan using the same reviewed inputs. Record hashes, versions,
   local test evidence and the remaining activation gates in the relevant stories.

Do not generate HMAC key material, add public routes/schedules, or grant real trial
or paid access as part of this inactive provisioning procedure. Complete the
activation prerequisites above in a separately reviewed change.
