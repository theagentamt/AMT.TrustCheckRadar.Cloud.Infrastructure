# Private result feedback candidate

This isolated root supports ATCR-122 / SECUR4ALL-238. All checked-in environments default to disabled. It changes no existing API, table, backup, expiry worker or provider setting. Source provisioning and live qualification are separate.

## Scope

Only an immutable Dev candidate in account `107827791950`, region `us-east-1`, is allowed. The package is `releases/<40-character source commit>/result_feedback.zip`, pinned by S3 object version and SHA256. Handler `result_feedback.app.lambda_handler` uses Python 3.14 ARM64, 256 MiB, timeout 10 seconds and reserved concurrency two. Asynchronous retries are disabled. Main-only CI validates this root; automatic deployment explicitly excludes it. Manual helper state key is `trustcheckradar/dev/result-feedback.tfstate`.

The execution role reads only the exact existing users/device-bindings/deletion-ledger/authority tables and current authority HMAC secret. It can perform V1-prefixed authority updates only inside transactions; the runtime must condition those writes on existing eligible owned CHECK records and current account/device/deletion fences. The same role covers existing bounded security-attempt counters. It has no PutItem, DeleteItem, Query, Scan, object storage, role chaining or downstream Lambda invocation. IAM table permissions alone cannot enforce per-account ownership or field immutability; runtime tests and live acceptance must verify those boundaries.

No feedback table, model, API-provider secret or subscriber-only entitlement gate is added. Existing whole-row explicit receipt expiry and account deletion own cleanup. Seven-day active retention is anchored to the original receipt deadline, never submission time; shared historical backups can outlast it. See `docs/PRIVATE-RESULT-FEEDBACK-DECISIONS.md` and `docs/ACCOUNT-DATA-INVENTORY.md`. PITR was last audited at 35 days; the new verification attempt failed due expired AWS SSO. Current backups/extra copies and lifecycle deployments must be verified before activation. Do not claim physical deletion of every copy at day seven or complete account export.

## Inactive settings and activation

`RESULT_FEEDBACK_ENABLED=false` is fixed. The approved policy version is `private-result-feedback-2026-09-21-v1`, proposal SHA256 `9e3485588daeae698b139cb070b4de16bb9298348135271e7d9adafd9968bee6`. Existing Cognito, identity table and HMAC secret references are supplied; no secret value enters Terraform state.

The disabled candidate deliberately omits `DEV_SUBJECT_ALLOWLIST_JSON`, `ATTEMPT_WINDOW_SECONDS` and `ATTEMPTS_PER_WINDOW`. The enabled runtime must validate explicit subject admission and bounded request limits; missing values must fail closed. These are technical request limits, not paid analysis allowances. Pin and review them with the exact runtime before activation rather than inventing production limits here.

No API Gateway integration, route, invocation grant, function URL, event source or schedule is created. The intended future route is authenticated `POST /v1/result-feedback`. Before adding it, qualify canonical Android/backend fixtures, authorization and active-device fences, owned result pairing, exact replay/already-received/conflict semantics, original expiry, concurrent deletion and expiry races, log minimization and backup/restore lifecycle. Perform live verification separately from mocked Terraform tests.

Fourteen-day operational logs follow the existing baseline and must contain no request payload, feedback category, operation proof, result/account identifier or exception payload. Three native error/throttle/duration alarms use the existing confirmed `support@andmorethings.com` SNS path. The thresholds are engineering defaults (one error/throttle in five minutes, duration seven seconds), not measured production SLOs. These metrics do not count accepted feedback, rejected HTTP200 responses or a daily product report.

## Validation

Run `terraform init -backend=false`, `terraform validate`, `terraform test`, and `python3 -m unittest discover -s scripts/tests -p test_terraform_helper.py`. Mocked tests verify no-op defaults, exact private disabled package, least privilege, existing alert destination, and rejection of missing/mutable/unrelated/foreign-environment artifacts and dependencies. They make no AWS calls and cannot establish live behavior.
