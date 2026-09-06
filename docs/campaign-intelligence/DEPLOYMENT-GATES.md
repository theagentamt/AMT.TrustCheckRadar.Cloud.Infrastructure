# Campaign Intelligence Deployment Gates

This runbook controls activation of the Terraform already present in
`campaign-data`, `campaign-processing`, and `campaign-api`. Committing the stacks
does not authorize campaign data collection.

## Current State

All environments are disabled. A disabled plan creates no campaign resources.
The CI tests exercise both the disabled configuration and a mocked enabled Dev
configuration.

## Dev Activation Inputs

The following work must be accepted before any Dev flag changes:

- `SECUR4ALL-213`: canonical schemas, compatibility tests, and bilingual taxonomy
- `SECUR4ALL-214`: approved model digest, provenance, benchmarks, and calibration
- `SECUR4ALL-215`: privacy/security review and evidence plan
- `SECUR4ALL-204` through `SECUR4ALL-207`: immutable worker artifacts matching
  the accepted contracts
- `SECUR4ALL-208`: immutable review artifact and the sole reviewer account
- `SECUR4ALL-211`: immutable trends API artifact

Configure these protected GitHub `dev` environment values:

```text
CAMPAIGN_BUDGET_NOTIFICATION_EMAILS=["approved-recipient@example.com"]
CAMPAIGN_FEATURE_IMAGE_DIGEST=sha256:<64 lowercase hex characters>
CAMPAIGN_MODEL_VERSION=<approved version>
CAMPAIGN_REVIEWER_USERNAME=<GitHub environment secret>
```

`ARTIFACT_RELEASE` must identify a release containing every required campaign zip
listed in `docs/RELEASES.md`. The model image must already exist in the Dev ECR
repository at the approved digest and must not exceed 2 GB.

## Dev Activation Change

Use staged reviewed changes:

1. Set `campaign_intelligence_enabled=true` in Dev `foundation.tfvars` and
   `campaign-data.tfvars`, then deploy with `deployment_scope=campaign-data`.
2. Upload and verify the immutable zip artifacts and ECR digest.
3. Set `campaign_intelligence_enabled=true` in Dev `api.tfvars` and set
   `campaign_processing_enabled=true` while keeping
   `kill_switch_enabled=true`; deploy and inspect IAM, logs, alarms, schedules,
   event mappings, and outputs.
4. Set `campaign_api_enabled=true` and, when its separate handoff is accepted,
   `campaign_review_api_enabled=true`; deploy and run authenticated negative and
   positive smoke tests.
5. Set `kill_switch_enabled=false` only after deletion, suppression, retry, and
   privacy-negative tests pass.

The budget email subscription must be confirmed by its recipient before the kill
switch is released. The `CostCategory=campaign-intelligence` cost-allocation tag
must be active in AWS Billing for the campaign-only budget filter to report spend.

## UAT and Production

UAT and Production repeat the Dev sequence using the identical artifact release
and model digest. They additionally require `promotion_approved=true` in all
three campaign variable files. Production requires the approved $50 monthly
ceiling, table deletion protection, a GitHub environment approval, and a signed
go/no-go record from `SECUR4ALL-210`.

No promotion may introduce OpenSearch, a NAT gateway, paid VPC endpoints,
provisioned concurrency, Step Functions, Global Tables, cross-Region replicas, or
always-on compute through an unreviewed variable override.
