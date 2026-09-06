# Campaign Intelligence V1 Cost Model

Status: **Proposed v1** for `SECUR4ALL-202`

Region: `us-east-1`

This estimate is incremental to the existing TrustCheckRadar infrastructure. It
does not count promotional AWS credits or free-tier capacity because those limits
are shared by the account and might already be consumed.

## Expected Monthly Cost

| Usage | Dev-only estimate | Main driver |
| --- | ---: | --- |
| Idle architecture | $4-$6 | Customer-managed KMS keys |
| Up to 10,000 eligible scans | $5-$8 | Fixed KMS plus light Lambda use |
| 100,000 eligible scans | $10-$18 | Multilingual model Lambda duration |
| 1,000,000 eligible scans | $75-$150 | Model memory and inference duration |
| Idle Dev, UAT, and Production | $12-$20 | Tripled keys, artifacts, and alarms |

These are planning ranges, not a quote. The wide high-volume range accounts for
the multilingual encoder, whose memory and duration are not selected yet.

## Assumptions

The usage estimate assumes, per eligible scan:

- about 3.3 GB-seconds across publisher, feature, and clustering Lambda work;
- three Lambda invocations;
- 12 DynamoDB 1 KB write request units including index writes;
- 20 DynamoDB eventually consistent read request units;
- six SQS API requests across send, receive, and delete operations;
- one contributor `GenerateMac` plus bounded service-encryption KMS usage; and
- approximately 3 KB of content-free logs.

The estimate uses the higher x86 Lambda duration rate as a conservative baseline.
Arm64 is preferred when the selected model supports it without reducing quality or
increasing duration.

## Fixed Cost

An enabled environment has two long-lived customer-managed encryption keys. It
also averages approximately 1.5 billable period HMAC keys because a key is usable
for a 14-day period plus a 7-day recovery window. At $1 per key-month, prorated
hourly, expected KMS key storage is approximately $3.50 per enabled environment.
Keys scheduled for deletion are not billed during the mandatory pending-deletion
window.

Other expected low-volume fixed or near-fixed costs are:

- about $0.20 per environment for one retained 2 GB model image in ECR;
- $0-$2 for standard CloudWatch alarms depending on how much of the account-level
  free tier is already consumed; and
- pennies for small aggregate-table storage and PITR.

There is no idle charge for Lambda, DynamoDB on-demand request capacity, SQS, or
EventBridge Scheduler.

## Usage Cost Formula

The working estimate before account-level free tiers is:

```text
monthly cost ~= enabled-environment fixed cost
             + scans * Lambda GB-seconds * Lambda regional rate
             + DynamoDB request units
             + SQS requests
             + KMS requests
             + CloudWatch log ingestion/storage
```

Reference rates used for the estimate:

| Service | Planning rate |
| --- | ---: |
| AWS KMS key storage | $1 per customer-managed key-month, hourly prorated |
| AWS KMS symmetric/HMAC requests | $0.03 per 10,000 after 20,000 free requests |
| Lambda requests | $0.20 per million requests |
| Lambda x86 duration | $0.0000166667 per GB-second |
| DynamoDB on-demand writes | $0.625 per million 1 KB WRUs |
| DynamoDB on-demand reads | $0.125 per million 4 KB RRUs |
| Standard SQS | Approximately $0.40 per million requests; first million free |
| ECR private storage | $0.10 per GB-month |
| CloudWatch log ingestion | $0.50 per GB after account free tier |
| Standard CloudWatch alarm metric | $0.10 per month after account free tier |
| EventBridge Scheduler | First 14 million invocations per month free |

Rates can change. Recalculate them before approving UAT or Production.

## Cost Guardrails

1. Enable campaign resources only in Dev for V1 development.
2. Keep OpenSearch in V2 or later. V1 provisions no collection, domain, or vector
   index service.
3. Provision no NAT gateway, paid VPC interface endpoints, provisioned concurrency,
   Step Functions, Global Tables, cross-Region replicas, or always-on compute.
4. Reuse the transient customer-managed key for the transient table and SQS queues.
   Do not create a key per queue or log group.
5. Use DynamoDB on-demand capacity with explicit maximum read/write throughput and
   CloudWatch throttling alarms. Raise caps only with measured demand.
6. Cap Lambda reserved concurrency per stage. Do not enable provisioned concurrency.
7. Package the model in ECR and retain only approved digests. Never download model
   weights at runtime.
8. Use sampled, content-free logs and the shortest approved retention period.
9. Keep at most 10 standard alarm metrics in the initial Dev package when practical.
10. Create a $25 monthly campaign budget with alerts at 50, 80, and 100 percent.
11. Tag every resource with project, environment, stack, owner, and cost category.
12. Provide a kill switch that disables event-source mappings and schedules without
    deleting state.

The budget is an alerting control, not a real-time hard stop. AWS Budgets can lag
actual usage, so service-level throughput and concurrency caps remain required.

The Dev ceiling is product-approved. The initial Production monthly ceiling is
still an open product-owner decision and must be recorded before Production
resources are enabled.

## Services Deliberately Avoided

- **OpenSearch:** not needed for V1 and may introduce avoidable indexing/search
  compute. Reconsider only after measured DynamoDB candidate limits in V2 or later.
- **NAT Gateway:** one gateway can add an always-on hourly charge before processing
  any data.
- **Interface VPC endpoints:** each endpoint ENI has an hourly charge; several
  services across multiple availability zones quickly exceed the application cost.
- **Provisioned concurrency or EC2/ECS services:** creates idle compute charges.
- **Secrets Manager HMAC secrets:** replaced with KMS HMAC keys so raw pseudonym
  material is never returned to application code.

## AWS Pricing References

- [AWS KMS pricing](https://aws.amazon.com/kms/pricing/)
- [AWS Lambda pricing](https://aws.amazon.com/lambda/pricing/)
- [Amazon DynamoDB pricing](https://aws.amazon.com/dynamodb/pricing/)
- [Amazon SQS pricing](https://aws.amazon.com/sqs/pricing/)
- [Amazon ECR pricing](https://aws.amazon.com/ecr/pricing/)
- [Amazon CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)
- [Amazon EventBridge pricing](https://aws.amazon.com/eventbridge/pricing/)
- [AWS Budgets pricing](https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/)
