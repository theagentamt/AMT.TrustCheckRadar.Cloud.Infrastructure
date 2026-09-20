# Manual Dev URL consumer deployment — 2026-09-20

The owner requested manual execution instead of GitHub Actions. This deployment
provisioned the inactive candidate only in AWS account `107827791950`, region
`us-east-1`. It did not activate an Android external check or complete ATCR-124.

## Source and artifact evidence

Infrastructure preparation commit: `d05f110` on `codex/manual-dev-consumer-deployment`,
based on the reviewed PR10 head `974d51ca06bf6973edcbc7dade0259fd25f6b17f`.
Lambda packages were built from reviewed PR13 head
`44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d` (merged as
`12964d0e537d3ea6ac12bf4c76d1704837ff4e89`). The immutable S3 object versions and
base64 SHA-256 values are recorded in `environments/dev/url-consumer.tfvars`.
Only these three packages were uploaded; each object checksum was read back.

| Package | SHA-256 |
| --- | --- |
| `url_consumer.zip` | `6fc46821623483cb0dff7d3dcce016e049b66714fcd2309425513337167c79f3` |
| `url_lease_recovery.zip` | `5b59e146cead8dd544621ade4b4370492876670365033764c39daf18ecd6aed1` |
| `v1_entitlements.zip` | `6884458b157e1ffa6151359859642bb33eabbb331a364a6d4adb61b2f37953ff` |

## Deployment and validation

- Saved Terraform plan and apply: 19 added, zero changed, zero destroyed.
- Independent encrypted, locked remote state:
  `trustcheckradar/dev/url-consumer.tfstate`.
- Three function aliases point to version 1, Python 3.14 ARM64, 256 MiB.
  Consumer: 29 seconds/concurrency 2; access/trial: 10 seconds/concurrency 2;
  lease recovery: 15 seconds/concurrency 1. Code hashes match the artifacts.
- Four local mocked Terraform scenarios passed. Configuration validation and
  formatting passed. Fifteen read-only IAM simulations passed, including
  transaction-only writes, namespace restrictions, removed enumeration/deletion
  grants, and denied unrelated provider/secret access.
- Actual AWS disabled-handler invocations passed: consumer returned HTTP 503
  `SERVICE_UNAVAILABLE` with unknown accounting; access returned HTTP 503
  `ACCESS_SERVICE_UNAVAILABLE`; recovery returned disabled/recovered zero.
  This verifies real ARM64 package loading for the disabled paths. It does not
  qualify the enabled authority/provider transaction path or its timing.
- All activation/retention flags were verified false before invocations.
  There are no public routes, function URLs, invocation policies, event sources
  or recovery schedule added by this release. Async retries are zero.
- The separate HMAC secret container exists with no secret version/value. The
  existing Google Web Risk secret was not read or changed.
- A final plan using the committed Dev variable inputs reported no changes.
- Resolver remains version 2; private assessment remains version 1. Their code
  hashes are unchanged. The legacy Web Risk function's code hash, revision,
  last-modified timestamp and concurrency 5 match the pre-deployment baseline.

## Remaining activation work

Owner approval for receipt/result and trial-eligibility retention is pending.
The deletion bridge, cleanup schedule/monitoring, authenticated API routes,
explicit authority configuration, private assessment budget extension, real
paid-store/operator integration and enabled-path testing remain prerequisites.
HMAC material must be generated outside Terraform only for the reviewed next
phase. The Android adapter remains disabled and unbound; PR14 remains open.
No UAT/Production resources were modified, no grants or trial records were
created, and no provider calls were part of these disabled smoke checks.
