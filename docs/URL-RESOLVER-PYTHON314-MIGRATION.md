# Resolver Python 3.14 migration

The owner requested the latest AWS-supported Python baseline. AWS documentation checked on 2026-09-20 lists Python 3.14 as the latest generally available Python Lambda runtime; Python 3.15 is public preview and excluded from this baseline. [AWS runtime support](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html).

The initial resolver deployment used Python 3.13. Dev now runs **Python 3.14 ARM64, published version 2**, with the `live` alias verified Active and LastUpdateStatus Successful. Local validation uses Python 3.14.7. AWS manages its runtime patch versions; the Terraform selector pins the supported minor runtime rather than claiming AWS runs that exact local patch.

## Scope and artifact

The reviewed local Terraform migration applied **zero additions, two in-place updates, zero deletions**: resolver function runtime/artifact and its live alias. Networking, IAM, alerting, existing analyzer and UAT/Prod were unchanged. This was a local CLI deployment, not a GitHub Actions run. The separate Dev GitHub read-permission policy remains unapplied pending explicit approval.

- Bucket: `trustcheckradar-dev-107827791950-artifacts`.
- Key: `releases/url-resolver-py314-dev-20260920-d107988b4412/url_redirect_resolver.zip`.
- Version: `zKohCq1dfkcQb5f2IPscPfiYv9RoIFYB`.
- Base64 SHA256: `0QeYi0QSW0hfQ5Z4stNK5968KHovT00yoXq1MrBmbmw=`; 336116 bytes.
- The pure-Python package bytes match the original package, but the separate immutable release records the 3.14 build/test target.
- Lambda build/CI alignment commit: `e768955cc3f069448df207027fb65db5904de5aa`.

Only the isolated resolver root upgraded its AWS provider from 5.100.0 (which rejects `python3.14`) to locked 6.65.0. The lock file includes Mac ARM64 and GitHub Linux AMD64 checksums. Other Terraform stacks keep their providers. Infrastructure CI/release helper Python is now explicitly 3.14; the Lambda agent owns resolver build/CI changes.

## Verification

- Lambda full suite: 419 tests plus 208 subtests on Python 3.14.7; resolver subset 77. Packaged handler and vendored DNS import passed.
- Infrastructure: all eight mocked resolver security tests, 39 Python helper tests, Actionlint, Terraform validate/fmt and whitespace checks passed.
- Live AWS alias runtime, version, status, architecture and code hash verified.
- Post-migration Terraform plan: no changes. The code-release verifier also revalidated the new exact-version artifact bytes against this plan.
- All nine bounded live Python 3.14/version 2 smoke cases passed through the narrow Dev role: eight blocked/no-network cases and benign public HTTPS. No EC2 fixture was recreated. Evidence is recorded separately in the Lambda repository.
- Historical 22-case owned-fixture verification remains Python 3.13 evidence; it is not relabeled as a 3.14 run. The full owned redirect/TLS/rebinding matrix was not repeated for this runtime-only migration.

Other existing stacks still reference Python 3.12/3.13 and need separate tested migrations. Runtime upgrades are not part of the deliberately code-only GitHub resolver workflow; they require their own reviewed infrastructure plan, as used here. Latest generally available AWS support is the default for future work, with preview exclusion and explicit build/test/runtime alignment.
