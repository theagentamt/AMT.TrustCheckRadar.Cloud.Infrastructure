# Campaign Intelligence V1 Cost Model

Status: **Product-approved v1 guardrails** for `SECUR4ALL-202`

Region: `us-east-1`

This estimate is incremental to the existing TrustCheckRadar infrastructure. It
does not count promotional AWS credits or free-tier capacity because those limits
are shared by the account and might already be consumed.

## Expected Monthly Cost

| Usage | Dev-only estimate | Main driver |
| --- | ---: | --- |
| Idle architecture | $4-$6 | Customer-managed KMS keys |
| Up to 10,000 eligible scans | $4-$7 | Fixed KMS plus light Lambda use |
| 100,000 eligible scans | $6-$12 | DynamoDB, KMS, and clustering Lambda use |
| 1,000,000 eligible scans | $20-$45 | DynamoDB, KMS, and clustering Lambda use |
| Idle Dev, UAT, and Production | $12-$20 | Tripled keys, artifacts, and alarms |

These are planning ranges, not a quote. App-side feature extraction has no AWS
inference, container-storage, or model cold-start cost.

## Assumptions

The usage estimate assumes, per eligible scan:

- about 0.75 GB-seconds across publisher and clustering Lambda work;
- two Lambda invocations;
- eight DynamoDB 1 KB write request units including index writes;
- 16 DynamoDB eventually consistent read request units;
- four SQS API requests across send, receive, and delete operations;
- one contributor `GenerateMac` plus bounded service-encryption KMS usage; and
- approximately 3 KB of content-free logs.

The estimate uses the higher x86 Lambda duration rate as a conservative baseline;
the deployed ZIP workers use Arm64.

## Fixed Cost

An enabled environment has two long-lived customer-managed encryption keys. It
also averages approximately 1.5 billable period HMAC keys because a key is usable
for a 14-day period plus a 7-day recovery window. At $1 per key-month, prorated
hourly, expected KMS key storage is approximately $3.50 per enabled environment.
Keys scheduled for deletion are not billed during the mandatory pending-deletion
window.

Other expected low-volume fixed or near-fixed costs are:

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
7. Provision no server feature model, container image, ECR repository, or inference
   runtime. Treat app-produced features as untrusted input.
8. Use sampled, content-free logs and the shortest approved retention period.
9. Keep at most 10 standard alarm metrics in the initial Dev package when practical.
10. Create a $25 Dev monthly campaign budget and a $50 Production monthly campaign
    budget, each with alerts at 50, 80, and 100 percent. UAT receives an explicit
    ceiling as part of its promotion approval and remains disabled until then.
11. Tag every resource with project, environment, stack, owner, and cost category.
12. Provide a kill switch that disables event-source mappings and schedules without
    deleting state.

The budget is an alerting control, not a real-time hard stop. AWS Budgets can lag
actual usage, so service-level throughput and concurrency caps remain required.

The Dev and Production ceilings are product-approved. Production resources remain
disabled until the privacy, security, quality, abuse, rollback, and cost evidence
gates pass; the ceiling does not itself authorize deployment.

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
- [Amazon CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)
- [Amazon EventBridge pricing](https://aws.amazon.com/eventbridge/pricing/)
- [AWS Budgets pricing](https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/)
