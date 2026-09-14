# History Dev deployment: 2026-09-14

Status: partial deployment complete; feature activation blocked.
Owner: SECUR4ALL-223; policy SECUR4ALL-185; Lambda SECUR4ALL-224/225/226;
account lifecycle SECUR4ALL-200. No story was closed.

## Authorization and scope

The user requested deployment and activation, scoped here to Dev. They separately
approved 7-day PITR for both History tables, 120-day minimal dedup/deletion
metadata, and 7-day mutation receipts. History remains 90 days from completion,
with immediate read exclusion and a required 24-hour active-data purge deadline.
The latter are contracts to validate, not guarantees proven by this deployment.

AWS CLI verified account `107827791950`, region `us-east-1`, using the existing
`trustcheckradar` SSO administrator profile. No browser login was performed.
UAT/Prod, existing API routes and existing Lambda functions were not changed.
No push to main or broad deployment workflow was used.

## Applied resources

Two reviewed, isolated saved plans were applied through Terraform:

- `history-data`: 2 additions, 0 changes, 0 destructions. Created
  `trustcheckradar-dev-history-content` and `trustcheckradar-dev-history-control`.
- `history-processing`: 8 additions, 0 changes, 0 destructions. Created the
  `trustcheckradar-dev-history-lifecycle` Lambda, scoped IAM role/policy, 14-day
  log group, five-minute EventBridge rule/target, invocation permission and
  bounded asynchronous retry configuration.

State bucket: `amt-trustcheckradar-107827791950-tfstate`; keys:
`trustcheckradar/dev/history-data.tfstate` and
`trustcheckradar/dev/history-processing.tfstate`.

The lifecycle schedule is DISABLED and all lifecycle/read/write/replay/mutation/
recognition runtime flags on the worker remain false. Dedup is configured as
120 days. Other runtime policy is intentionally null pending operational
acceptance; the approved 7-day receipt duration is recorded, not yet activated.
No History monitoring, cursor secret, read/mutation API routes or producer IAM
integration was deployed. No customer data was written or queried by this work.

## Artifact

The Lambda task published a corrected immutable release under separately
coordinated authorization. Infrastructure verified its S3 version and checksum:

- Commit/release: `68dd8dff55bdb2c857cca00133ee3530de767fa7`.
- Bucket: `trustcheckradar-dev-107827791950-artifacts`.
- Key: `releases/68dd8dff55bdb2c857cca00133ee3530de767fa7/history_lifecycle.zip`.
- Version: `n9NENikX9bJRt7QvFuUD5vpQ3d.22kW6`.
- Bytes: 14722.
- Base64 SHA-256: `jSku/3u73ulwBAt6VKV174VEtcM+i/h3f1JPbnfiHXY=`.

The deployed Lambda CodeSha256 matches. Do not select predecessor `0fad0cc`,
which lacks mandatory retention-floor validation. Other artifacts in the new
coherent release were uploaded by the Lambda owner but not deployed here.

## Verification

- Both tables and all three GSIs report ACTIVE, with KEYS_ONLY projections.
- Both tables report TTL ENABLED on expiresAt and PITR ENABLED for 7 days.
- Tables use on-demand billing, AWS-owned encryption and caps of 25 read/10
  write request units per table/index. These caps are not a global cost budget.
- Lifecycle reports State=Active and LastUpdateStatus=Successful. AWS's Active
  function status is not History feature activation; its runtime flag is false.
- EventBridge reports DISABLED with rate(5 minutes).
- IAM per-resource simulation allows Query on all three exact Dev GSIs using
  the allowed leading-key family and implicitly denies the tested Prod GSI.
  The simulator's combined top-level denial includes intentionally unauthorized
  resources; per-resource results were inspected. This is not a real cleanup run.
- Both post-apply Terraform plans returned exit 0 with no changes.
- Prior local suites passed: 19 History data and 14 processing mocked Terraform
  tests, plus 7 helper tests. Formatting and whitespace checks passed.

No end-to-end Lambda invocation, authenticated API, deletion/restore test, model
call or load test was performed. Empty provisioned stores do not prove erasure.

## Activation blockers

1. Final API/cursor/schema/catalog and recognition qualification decisions.
2. Account-state bootstrap and SECUR4ALL-200 deletion fence, durable erasure
   integration and backup reconciliation. Account export contract/owner remains
   unresolved where required by the agreed lifecycle promises.
3. Read/mutation route and producer IAM/configuration integration.
4. Full operational runtime policy, approved alarm destination, deployed alarms
   and verified notification delivery. Only a campaign-budget SNS topic currently
   exists; it was not silently reused for History operational alerts.
5. Authenticated Dev isolation/replay/deletion tests, recovery/load evidence and
   validated 24-hour purge/restore behavior; longer outage coverage and cost review.

Do not remove resource-provisioning flags to stop the feature: that would request
destruction. Complete the remaining work before enabling ingestion or schedules.
Deployment was performed from the local infrastructure branch before its commit
and push. Preserve this reviewed Dev configuration in future releases/merges.
