# Private Dev URL assessment deployment — 2026-09-20

Tracks SECUR4ALL-233 and the delivered subset of SECUR4ALL-242. This is an operator-only integration, not Android activation or accepted billing/accounting authority.

## Deployed scope

The user populated the existing `trustcheckradar/dev/web-risk-api-key` secret. Metadata confirmed an `AWSCURRENT` version; deployment tooling never retrieved the value. The Lambda reads it only during an eligible provider check.

A new independent state, `trustcheckradar/dev/url-assessment.tfstate`, created 12 resources in account 107827791950 / us-east-1: private function/alias/asynchronous retry configuration, execution and restricted test roles/policies, log group, dependency metric filter, and three alarms. No resources were updated or deleted in that apply. A separately reviewed saved plan updated exactly the existing resolver SNS topic policy to accept three named assessment alarm sources; no resolver runtime/network/caller changes.

The legacy `trustcheckradar-dev-web-risk-communication` handler still has the previously identified missing subscription/allowance gate. Automatic approval review rejected a proposed temporary pause; the user explicitly chose **Keep it running for now**. It remains unchanged with reserved concurrency 5. No alternate route, IAM restriction or code change was used to bypass that decision.

| Item | Verified value |
| --- | --- |
| Function / alias | `trustcheckradar-dev-url-assessment:live` |
| Published version | 1, Active / Successful |
| Runtime / architecture | Python 3.14 / ARM64 |
| Limits | 256 MiB, 35 seconds, concurrency 2 |
| Artifact bucket | `trustcheckradar-dev-107827791950-artifacts` |
| Artifact key | `releases/1f47f5b90fbff19d27a981206a70ef60e88ed267/url_assessment.zip` |
| S3 version | `RfyEhgRrMSD3MMztj.VMwnNBOrZ1eWmA` |
| SHA256 base64 | `k4aHp3JkRAzIQp69vpQRxRkAxos3QgGySl4csW+UvVQ=` |
| Size | 339912 bytes |
| Test role | `trustcheckradar-dev-url-assessment-dev-test` |
| Alerts | Existing confirmed `support@andmorethings.com` resolver-topic subscription |

Root independently downloaded the exact S3 version and verified SHA256 and size before applying. The deployed function hash matches. Source implementation is [Lambda PR #9](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/9); its local full suite passed 533 tests plus 162 subtests, and exact-head CI passed. [Lambda PR #10](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/10) records acceptance evidence and corrects the automatic publisher's package count; the failed first publisher attempt stopped before AWS credentials/uploads and did not affect this manual deployment. The correction is merged at `7cd2e6fd4c2e553f09d0eb82c018d2cd0467c5b0`; main CI 35513668721 and publisher 35513694321 passed, with `assessment_manual` scope and all AWS/authentication/upload steps skipped.

## Live acceptance evidence

The Lambda agent assumed the restricted role without persisting its credentials and ran eight cases:

- Metadata/private IP, userinfo, encoded header injection, sensitive query token and non-HTTP URL: rejected with zero provider calls and zero observed hops.
- `https://example.com/`: complete supported inspection, `no_known_threat_detected`, one provider call. This is not a guarantee of safety.
- Google's documented harmless malware-test URL: `high_risk`, one provider call. Processing is deliberately partial after the known match stops further checks; the positive threat evidence is retained.

The result includes no raw URLs/hops, provider key or fabricated risk score. It explicitly declares `consumerAccessEnabled=false`. The [sanitized smoke results](url-assessment-dev-evidence/smoke.jsonl) distinguish case outcomes from runtime/transport success.

Root independently verified:

- Actual unqualified function invocation is denied to the dedicated operator role; its sole invocation grant targets `:live`.
- Execution role reads only the exact provider secret and invokes only the exact resolver alias, with own-log writes and consumer-storage/role-chaining denies. Neither role has attached managed policies.
- No Function URL, alias resource invocation policy or event-source mapping exists. Terraform creates no API Gateway resource or mobile grant. Existing administrators retain administrative authority.
- Eight application log events contain exactly the allowlisted operational fields, with no URLs, API keys, check identifiers or raw exception/provider content. Standard Lambda runtime records are separate. See [privacy evidence](url-assessment-dev-evidence/log-privacy.json).
- A subsequent reviewed apply changed only the assessment metric filter to include unavailable outcomes even when no provider call occurs. The CloudWatch filter matched all ten synthetic operational-failure reasons plus two unavailable outcomes, and excluded known-threat, invalid-input, no-match and blocked-input events (12 matches across 16 cases). This validates metric matching, not an alarm-delivery transition. The shared email subscription was already confirmed; no new recipient/subscription was created.
- Assessment post-apply plan reports no changes. The existing resolver post-update plan also reports no changes.

Local infrastructure checks: five mocked assessment tests, nine mocked resolver tests, 41 helper tests, Terraform validate/fmt, Actionlint, shell syntax and whitespace checks passed. [IAM/exposure evidence](url-assessment-dev-evidence/infrastructure.json) contains only sanitized outcomes.

## Remaining work

There is no new public endpoint and the existing public endpoint was not replaced. Google Lookup and the redirect resolver now work together for controlled Dev operator checks. Public integration still requires approved URL/privacy projection, authenticated account and active-device enforcement, paid/trial/complimentary authority, logical-check idempotency/accounting, accepted response/error compatibility and mobile implementation. The draft consumer contract and private protocol are deliberately different surfaces.

This acceptance does not claim a newly executed shortened-link fixture, production load/availability, customer-data processing, physical-device testing, store-billing acceptance or a new alarm-email transition. Earlier resolver-specific redirect/SSRF evidence remains separately recorded. UAT/Prod remain disabled. The two sprint stories remain In Progress until their full acceptance criteria are satisfied.
