# Campaign Intelligence Deployment Gates

This runbook controls activation of the Terraform already present in
`campaign-data`, `campaign-processing`, and `campaign-api`. Committing the stacks
does not authorize campaign data collection.

## Current State

Dev campaign data and API resources were deployed on 2026-09-06. The data plane
includes the encrypted on-demand DynamoDB tables, TTL policies, required indexes,
legacy feature/clustering queues and DLQs, KMS keys, a legacy ECR repository,
alarms, and campaign budget. The
authenticated review and trend routes are available through
`api-dev.andmorethings.net`; the sole reviewer is assigned to the Cognito
`campaign-reviewer` group and must complete the first-password change.
The campaign budget email subscription for `support@andmorethings.com` is
confirmed.

Campaign source publishing and all background workers remain disabled. The
processing kill switch remains enabled and AWS has no campaign event-source
mappings or lifecycle schedules. Product direction on 2026-09-07 moved feature
extraction permanently to the app. The next reviewed campaign-data apply must
remove the legacy feature queue, feature DLQ, ECR repository, and image policies.
No feature image may be deployed or replaced.

Lambda commit `9ef72258614ba9fc8639ee7c084c429cc454b33b` implements the
server side of the app-feature contract: analysis validation and transactional
outbox persistence, publisher revalidation and direct clustering enqueue, and
cluster input validation. Its GitHub CI and independent local campaign-evidence
gate pass. The release workflow was intentionally skipped, so this commit has
not been uploaded as an immutable S3 release or deployed to any Lambda function.

UAT and Production remain disabled. CI continues to exercise both disabled
configurations and mocked enabled configurations.

## Dev Activation Inputs

The following work must be accepted before any Dev flag changes:

- `SECUR4ALL-213`: canonical schemas, compatibility tests, and bilingual taxonomy
- `SECUR4ALL-205` and `SECUR4ALL-214`: versioned app feature contract, platform
  parity, benchmarks, and calibration
- `SECUR4ALL-215`: privacy/security review and evidence plan
- `SECUR4ALL-204` through `SECUR4ALL-207`: immutable worker artifacts matching
  the accepted contracts
- `SECUR4ALL-208`: immutable review artifact and the sole reviewer account
- `SECUR4ALL-211`: immutable trends API artifact

Configure these protected GitHub `dev` environment values:

```text
CAMPAIGN_BUDGET_NOTIFICATION_EMAILS=["approved-recipient@example.com"]
CAMPAIGN_REVIEWER_USERNAME=<GitHub environment secret>
```

`ARTIFACT_RELEASE` must identify a release containing every required campaign zip
listed in `docs/RELEASES.md`. The release must implement the accepted app-feature
schema and direct publisher-to-clustering handoff.

## Dev Activation Change

Use staged reviewed changes:

1. Accept the app feature and Lambda contracts before changing collection flags.
2. Plan `campaign-data` and verify that the only intended removals are the legacy
   feature queue, feature DLQ, ECR repository, and their policies; then apply the
   reviewed cleanup.
3. Upload and verify the immutable ZIP artifacts.
4. Set `campaign_intelligence_enabled=true` in Dev `api.tfvars` and set
   `campaign_processing_enabled=true` while keeping
   `kill_switch_enabled=true`; deploy and inspect IAM, logs, alarms, schedules,
   event mappings, and outputs.
5. Set `campaign_api_enabled=true` and, when its separate handoff is accepted,
   `campaign_review_api_enabled=true`; deploy and run authenticated negative and
   positive smoke tests. Dev infrastructure is at this stage: unauthenticated
   requests return `401`, while authenticated tests remain pending the reviewer's
   first-password change.
6. Set `kill_switch_enabled=false` only after deletion, suppression, retry, and
   privacy-negative tests pass.

The budget email subscription must be confirmed by its recipient before the kill
switch is released. The `CostCategory=campaign-intelligence` cost-allocation tag
must be active in AWS Billing for the campaign-only budget filter to report spend.

## UAT and Production

UAT and Production repeat the Dev sequence using the identical artifact release.
They additionally require `promotion_approved=true` in all
three campaign variable files. Production requires the approved $50 monthly
ceiling, table deletion protection, a GitHub environment approval, and a signed
go/no-go record from `SECUR4ALL-210`.

No promotion may introduce OpenSearch, a NAT gateway, paid VPC endpoints,
provisioned concurrency, Step Functions, Global Tables, cross-Region replicas, or
always-on compute through an unreviewed variable override.
