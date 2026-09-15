# Account data and device recovery integration

Status: infrastructure preparation and Lambda implementation in progress.
No changes in this document are evidence of a live deployment or activation.

Prepared infrastructure was committed as `297b654` on
`codex/history-badges-activation`. Continued inventory and policy gaps are in
[ACCOUNT-DATA-INVENTORY.md](ACCOUNT-DATA-INVENTORY.md). No main merge or
deployment is authorized by the follow-up instruction to commit and continue.

## Ownership

Infrastructure changes belong to this repository. Application behavior, request
schemas and Lambda packages belong to the existing AMT Trust Check Radar Lambda
task (repository AMT.TrustCheckRadar.Lambdas, branch
`codex/sprint-7-history-badges`). Android/iOS changes are outside this work.
ITCR-17/38/39, ITCR-18/40, ITCR-41 and ITCR-59 are consumer dependencies,
not evidence that backend acceptance is complete. No YouTrack updates were made.

## Prepared infrastructure

- `terraform/api`: the legacy `POST /device-recovery` uses AWS_IAM, with
  an exact method/path Lambda invocation permission. Its output explicitly
  excludes consumer use. The corrected handler receives a validated exact
  same-account operator principal allowlist; default empty means deny all.
- `terraform/foundation`: optional environment-scoped recovery control table,
  PK/SK, `expiresAt` TTL, on-demand throughput capped at 25 reads/10 writes,
  no stream, AWS-owned encryption key and explicit backup policy. Production
  enables deletion protection and requires separate promotion approval.
- `terraform/api`: an optional version/hash-pinned recovery/registration release
  pair, shared profile/deletion-fence read and condition-check permissions,
  recovery-only control-table permissions, strict identity configuration and
  independent consumer activation switch. Activation also requires the three
  History/analysis reader artifacts to share that same pinned release ID.
- Consumer recovery is `POST /v1/users/device-recovery`, using the existing
  Cognito authorizer and `aws.cognito.signin.user.admin` scope. Its invocation
  permission is route-specific. Stage throttling is 2 requests/second with a
  burst of 4; this is not a substitute for the Lambda's per-subject rate limit.

All new deployment inputs remain null, storage remains opt-in, and consumer
activation remains false. Dev foundation tfvars now record the approved recovery
policy with provisioning explicitly false. The legacy
authorization correction itself changes the existing route when applied; review
its plan and coordinate the corrected operator handler before any apply.

## Candidate Recovery Contract

The Lambda owner has corrected the conflicting preliminary handoff and confirmed
these names and key formats against source. Its final tested/pushed release
manifest is still pending; this is not yet an approved mobile release contract.

| Setting | Prepared value |
| --- | --- |
| Device table | `DEVICE_BINDINGS_TABLE_NAME` |
| Recovery table | `DEVICE_RECOVERY_CONTROL_TABLE_NAME` |
| Identity | `USERS_TABLE_NAME`, `DELETION_LEDGER_TABLE_NAME`, `APP_ENVIRONMENT`, `COGNITO_ISSUER`, `COGNITO_APP_CLIENT_ID`, `COGNITO_REQUIRED_SCOPE` |
| Activation | `DEVICE_SELF_RECOVERY_ENABLED=false` |
| Policy | `DEVICE_RECOVERY_POLICY_STATUS=pending` until explicit approval |
| Fresh authentication | `DEVICE_RECOVERY_MAX_REAUTH_AGE_SECONDS=300` |
| Per-subject rate | `DEVICE_RECOVERY_RATE_WINDOW_SECONDS=3600`, `DEVICE_RECOVERY_RATE_MAX_REQUESTS=3` |
| Rate record expiry | `DEVICE_RECOVERY_RATE_STATE_TTL_SECONDS=86400` |
| Retry receipt expiry | `DEVICE_RECOVERY_RECEIPT_RETENTION_DAYS=7` |
| Audit expiry | `DEVICE_RECOVERY_AUDIT_RETENTION_DAYS=0` until approved |
| Operator authorization | `DEVICE_RECOVERY_ALLOWED_PRINCIPAL_ARNS_JSON=[]` until exact operators are configured |

The owner approved 90-day minimal audit records, 7-day receipts, 24-hour rate
records and 7-day recovery PITR on 2026-09-14. See the full
[decision record](ACCOUNT-DATA-POLICY-DECISIONS.md), including deletion receipts,
consent evidence and export cancellation. Runtime defaults above remain gated
until approved storage and a reviewed release are selected.
TTL cleanup is eventual; handlers must
enforce logical expiry and distinguish an expired receipt from a valid retry.

Current source uses recovery control PK `USER#<sub>` and SK
`RECOVERY#<operationId>`, `RATE#<window>`, or `AUDIT#<epoch>#<operationId>`;
the device table pointer is `USER#<sub>` / `ACTIVE_BINDING`. IAM leading-key
conditions follow these source conventions. Do not deploy if the final handler
uses a different key scheme until policy and tests are reconciled.

The consumer request contains only schemaVersion, operationId, action,
bindingFingerprint, platform and osVersion. Subject comes exclusively from the
verified access-token sub. Freshness is based on signed auth_time, not token iat
or a client-provided verification flag. Recovery must not require the lost
device's binding. Final schemas/errors will be owned and published by Lambda.

## Lambda Work And Acceptance

1. Fix History pagination at exact page limits with DynamoDB continuation;
   cover expired records, byte limits, cursor expiry and concurrent mutations.
2. Finalize History bootstrap/detail/list/export, progress, badge thresholds,
   qualification/reset behavior and cache invalidation contracts.
3. Harden support recovery and implement consumer recovery: strict identity,
   fresh authentication, receipts, rate limits, minimal audit, authority fences,
   and atomic replacement. Normal registration and support recovery must use
   the same active-binding pointer protocol.
4. Audit every device-binding reader. A paired writer release alone does not
   prove immediate old-device rejection if protected APIs still trust stale GSI
   records. Return every changed reader artifact and any required IAM changes.
5. Implement product-wide account deletion request/status, immediate durable
   authority fence, idempotency, global sign-out, retryable component cleanup
   and honest completion reporting. Profile/deletion-fence parsers must agree
   across all affected Lambdas before activation.
6. Define status retrieval after global sign-out/account removal. Do not promise
   indefinite normal authenticated polling after credentials have been revoked.
7. Prove a complete account-data inventory and a protected, subject-scoped
   paginated JSON export. No new S3 export bucket is requested. Explicitly
   distinguish unavailable/retained data; no credentials or cross-user data.
8. Return reconciliation success/full-pass-age metrics and missing-heartbeat
   behavior so infrastructure can alert on stalled deletion work, not only
   Lambda failures and stream iterator age.

The proposed product deletion routes are POST and GET
`/v1/users/account-deletion`; no public routes are provisioned yet. The disabled
`account_data_api.zip` candidate function and filtered stream mapping are
prepared in `terraform/api/account-data.tf`; deployment input remains null.
The package and any component cleanup artifacts await final Lambda handback.
History-only deletion/export must not be presented as full-account operations.
Retention of billing/security records needs an explicit policy, not automatic
reuse of History retention or an unqualified promise to erase everything.

DynamoDB transactions require the constituent item permissions, including
`dynamodb:ConditionCheckItem` for condition checks, not a blanket transaction
permission. See [AWS transaction IAM documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis-iam.html).

## Release Sequence

1. Reconcile final source contracts, tests and immutable artifact manifest.
2. Implement the approved Dev policy; verify backup/replay coverage, resolve
   remaining purchase anti-replay treatment and obtain any operator principal list.
3. Finish exact account-data/cleanup/metrics infrastructure from that handback.
4. Restore AWS CLI authentication when deployment is requested; no browser
   login automation. Review foundation/API/processing/bootstrap plans scoped
   to Dev; do not apply unrelated bootstrap drift.
5. Deploy reviewed disabled candidates, run disposable-user negative-auth,
   recovery-race, stale-binding, cross-subject and deletion/export tests.
6. Activate only after security, cleanup, alert delivery and cost checks pass.

No main merge, AWS apply, new artifact upload, real-user destructive test or
mobile change has been performed in this orchestration work.

## Local Verification

73 mocked Terraform tests pass cumulatively across the continued preparation: API 36,
identity-workflows 5, History-processing 19, foundation 5, campaign-processing 4
and focused bootstrap/access 4. The 12 helper-script tests also pass.
All affected Terraform roots validate; recursive formatting and whitespace
checks pass. These tests prove configuration guardrails, not live identity,
transaction behavior, erasure deadlines or alert delivery. Recovery source and
staged checksums are verified below; account-data work is still in progress.

## Recovery Source Handback

Verified locally and through the GitHub API: Lambda commit
`23300091d1549a87e41cdf50980e46cf418d3940`, "Secure device recovery and binding
consistency", exists on the feature branch. Its changes include transactional
registration/recovery, pointer-aware shared readers and the History pagination
fix. Lambda reports 261 tests and 126 subtests passing, plus a 36-test focused
slice; those application tests were not independently rerun by infrastructure.

The preliminary handback supplied an incorrect full SHA; use only the verified
commit above. Its corrected artifact handback points to
`/tmp/amt-lambda-release-critical`, not the repository's older `dist` files.
Infrastructure independently verified all five staged files with
`shasum -a 256 -c SHA256SUMS` and compared the manifest to the handback.

| Artifact | Verified SHA-256 |
| --- | --- |
| device_recovery.zip | `3c740a14c1e27b9d17048b327cf931bb7d0ba59493177232049e482f0919fae0` |
| device_registration.zip | `ce44dafdbb6f129065ff562dac17d5e1544372f7bfa8c2e0b73e9af81acd3d2b` |
| history_read_api.zip | `99a8020924db5ad1eb02fc5b7dd14d1adf6fae957d7ea55e7a122eb519af41f1` |
| history_mutation_api.zip | `ff4d45a66bda9580815d5163ab82bd1a32d614d1559169a0593014a5e33a8136` |
| conversation_analysis.zip | `2f76edd57d6d2b4e54cd4f60e597a82d3b762e392fafd39f3cef94ef3651517e` |

Temporary local paths are not immutable S3 versions. Recheck checksums before
any future publication. No release ID, S3 version or activation input has been
populated, and no package was uploaded. Account-data operations and
reconciliation metrics are not part of this source commit.

## Account-Data Candidate Contract

Final source handback is verified below; no live endpoint exists yet.
POST requires a strict Cognito access token, signed auth_time within 300 seconds,
no query parameters and exactly this body:

```json
{"schemaVersion":1,"operationId":"<canonical UUIDv4>","action":"DELETE_ACCOUNT"}
```

Identity comes exclusively from token sub. The transaction fences
`USER#<sub>/PROFILE` as DELETION_REQUESTED and creates the fixed
`ACCOUNT#<sub>/ACCOUNT_DELETION` request. POST then attempts global sign-out.
GET has no body/query, reads only that subject's status, and does not require
the profile to remain ACTIVE. Both responses are private/no-store. Same
operationId retries are idempotent; another operationId conflicts.

The optional stream consumer retries session revocation, filtered to fixed
REQUESTED commands in its environment. It is disabled and supports partial
batch failures. Failures must identify `dynamodb.SequenceNumber`, not eventID;
configuration/setup failures must retry rather than return an HTTP envelope.
The corrected stream handler is included in the verified pushed source and
staged account-data artifact described below.
See [AWS DynamoDB partial-batch response rules](https://docs.aws.amazon.com/lambda/latest/dg/services-ddb-batchfailurereporting.html).

The function uses the documented account-data env keys, with explicit values:
ACCOUNT_DELETION_ENABLED=false, ACCOUNT_DELETION_POLICY_STATUS=pending,
ACCOUNT_DATA_INVENTORY_STATUS=pending, COGNITO_USERNAME_IS_SUB=false and
ACCOUNT_DELETION_REQUIRED_COMPONENTS_JSON=[]. No generic environment override
can approve them. Live Cognito identity mapping must be verified before using
token sub as AdminUserGlobalSignOut's Username.
ACCOUNT_DELETION_COMPLETION_STATUS is explicitly incomplete until finalization
and all required component coverage are accepted.

IAM grants transactional profile UpdateItem, ledger GetItem/PutItem/DeleteItem
restricted to ACCOUNT#* partition keys, global sign-out in the exact pool,
own-stream reads and own-log writes. Resumable device cleanup has Query and
DeleteItem only on USER#* keys in the exact device table. IAM does not enforce
sort keys: handler tests must prove ledger deletion only removes the resumable
DEVICE_BINDINGS_PROGRESS record and receipt writes match their component.
No export bucket, AdminDeleteUser or public API invocation permission is added.

An additional Scan exception is bounded background account reconciliation on
the exact deletion ledger, never History content. Defaults are 100 evaluated
records/page, at most 10 pages/invocation, concurrency 1, five-minute schedule.
The checkpoint is LIFECYCLE#<environment> /
ACCOUNT_DELETION_SESSION_REVOCATION_RECONCILIATION, scoped separately in IAM.
The schedule is disabled, uses the exact event
`{"schemaVersion":1,"operation":"reconcile-session-revocation"}`, and has bounded
retry/age settings. The only invocation grant is for its exact EventBridge rule.
Bootstrap prepares a separate same-environment rule-management policy; do not
full-apply bootstrap and remove unrelated drift incidentally.

Receipts bind component completion to operationId and requestOccurredAtEpoch.
SESSION_REVOCATION, HISTORY, CAMPAIGN and DEVICE_BINDINGS receipts are not a
complete inventory. `completionEligible` is not an overall deletion result.
Device-binding cleanup and durable session reconciliation are implemented in
the verified source release but still need deployed acceptance.
Identity removal, profile/entitlement treatment, finalization and ledger
retention still require complete coverage. Recovery beyond stream retention,
account reconciliation alerts, scan cost and the 24-hour deadline must be
verified before activation; the disabled candidate does not prove them.

## Reconciliation Observability

The new source metrics use namespace AMT/TrustCheckRadar/History and the
Environment dimension only. Infrastructure prepares four alarms when the
account-deletion bridge is active: no successful reconciliation for 15 minutes,
reported failure, no completed full pass in six hours, and full-pass age at
least six hours. The full-pass-count alarm covers the initial period where no
full-pass-age metric exists. These are early warning thresholds, not proof of
the 24-hour erasure deadline.

`account_deletion_observability_approved` defaults false and is required for
bridge activation, alongside active lifecycle cleanup. Confirm the final
pinned bridge emits these metrics and test notification delivery before setting
it. Existing History source candidates without those metrics are insufficient.

## Final Disabled Integration Release

Verified locally and through the GitHub API:
`195859848cde7de04b26da83f2fa34b9ff5922f4`, "Add guarded account deletion
orchestration", on Lambda branch `codex/sprint-7-history-badges`.
This release supersedes the five-package recovery candidate for coordinated
integration; recovery/registration/read/mutation/analysis bytes are unchanged.

Infrastructure independently verified all nine checksums in
`/tmp/amt-lambda-release-1958598/SHA256SUMS`, compared them with the handback,
and compared every ZIP's app.py to that exact Git commit. These local staged
artifacts have not been uploaded and have no recorded S3 object versions.

| Artifact | Verified SHA-256 |
| --- | --- |
| account_data_api.zip | `d65dce8d3a1daa6d9513c00f23ba3f152e3f35f25fdc516ec2f3a30bb67a10a9` |
| campaign_deletion_bridge.zip | `2da8fefec718de84a08db1f12ce104e72d24710f0b653ea6809f83ea2b4f9dff` |
| conversation_analysis.zip | `2f76edd57d6d2b4e54cd4f60e597a82d3b762e392fafd39f3cef94ef3651517e` |
| device_recovery.zip | `3c740a14c1e27b9d17048b327cf931bb7d0ba59493177232049e482f0919fae0` |
| device_registration.zip | `ce44dafdbb6f129065ff562dac17d5e1544372f7bfa8c2e0b73e9af81acd3d2b` |
| history_account_deletion_bridge.zip | `7cc462f3634e7a4ed80285060e65b3f117175db7116eb72b379dd382eb835494` |
| history_lifecycle.zip | `5308f3430fc98fc77de46107a5e2306a9347b6a2be24398d1f78701de8c12410` |
| history_mutation_api.zip | `ff4d45a66bda9580815d5163ab82bd1a32d614d1559169a0593014a5e33a8136` |
| history_read_api.zip | `99a8020924db5ad1eb02fc5b7dd14d1adf6fae957d7ea55e7a122eb519af41f1` |

Lambda reports 279 tests and 129 subtests passing, compileall, shellcheck,
whitespace checks, and deterministic packaging checks. Those application tests
were not independently rerun in this infrastructure workspace. The legacy
device CLI is now dry-run-only; do not use an older copy to bypass pointer
transactions.

Disabled integration source is ready for infrastructure review. It is not a
complete product account lifecycle. Keep every account-data false/pending gate,
completion=incomplete, username-is-sub=false, stream/schedule disabled and no
public routes. Remaining work is the approved complete inventory, all missing
cleanup components, final Cognito identity removal, overall finalizer,
deletion-fence retention/removal, full paginated account export, verified
recovery retention, operational alerts and authenticated deployed acceptance.
At the source handback, infrastructure was still uncommitted. The owner has
since authorized a feature-branch commit and continued inventory work, not a
main merge or AWS deployment. All deployment and activation inputs stay unset.
