# Campaign Intelligence Deployment Gates

This runbook controls activation of the Terraform already present in
`campaign-data`, `campaign-processing`, and `campaign-api`. Committing the stacks
does not authorize campaign data collection.

## Current State

Dev campaign data and API resources were deployed on 2026-09-06. The data plane
includes the encrypted on-demand DynamoDB tables, TTL policies, required indexes,
the clustering queue and DLQ, KMS keys, alarms, and campaign budget. The legacy
server feature queue, feature DLQ, ECR repository, and image policies were
removed on 2026-09-07 after feature extraction moved permanently to the app. The
authenticated review and trend routes are available through
`api-dev.andmorethings.net`; the sole reviewer is assigned to the Cognito
`campaign-reviewer` group and must complete the first-password change.
The campaign budget email subscription for `support@andmorethings.com` is
confirmed.

Campaign source publishing and all four background workers were activated in
Dev on 2026-09-08 after a staged deployment. The first apply provisioned the
workers, event-source mappings, and lifecycle schedules with the kill switch on;
the second apply enabled all three mappings and all three schedules and released
the kill switch. No feature image may be deployed or replaced.

Lambda release `e7b9e84211406cc6e1587f86ac0bd0a67af4d3c2` was published and
deployed to every enabled Dev campaign Lambda on 2026-09-08. It contains the
canonical contract package, server-side app-feature validation, participation
revalidation at publication time, signed trend pagination, and explicit indexed
expiration for transient pipeline records. The JWT-protected campaign
participation, trends, and review routes are available at
`api-dev.andmorethings.net`; post-deployment unauthenticated smoke requests return
`401` as expected. Authenticated participation, quota, publication, withdrawal,
and deletion smoke tests remain pending an app or test-user JWT. The complete
Lambda suite, campaign evidence gate, Terraform contracts, package integrity
checks, infrastructure CI, and Dev apply passed. The product owner authorized Dev
activation with that remaining app-level validation recorded.

UAT and Production remain disabled. CI continues to exercise disabled,
kill-switched, and active configurations.

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
   privacy-negative tests pass, and record the release with
   `activation_approved=true`.

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
