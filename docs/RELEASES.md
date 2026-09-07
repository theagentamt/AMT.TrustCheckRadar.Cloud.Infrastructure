# Lambda Releases

Application CI should build the Lambda packages, assign an immutable release identifier, and upload the packages to each environment's foundation artifact bucket.

For release `2026.09.03-1`, the required object layout is:

```text
releases/2026.09.03-1/age_attestation.zip
releases/2026.09.03-1/conversation_analysis.zip
releases/2026.09.03-1/device_registration.zip
releases/2026.09.03-1/device_recovery.zip
releases/2026.09.03-1/purchase_handoff.zip
releases/2026.09.03-1/entitlement_snapshot.zip
releases/2026.09.03-1/campaign_participation.zip
releases/2026.09.03-1/post_confirmation.zip
releases/2026.09.03-1/web_risk_communication.zip
```

When campaign processing or APIs are enabled, the same release also contains:

```text
releases/2026.09.03-1/campaign_observation_publisher.zip
releases/2026.09.03-1/campaign_cluster_aggregator.zip
releases/2026.09.03-1/campaign_lifecycle.zip
releases/2026.09.03-1/campaign_deletion_bridge.zip
releases/2026.09.03-1/campaign_trends.zip
releases/2026.09.03-1/campaign_review.zip
```

Feature extraction runs in the app. Infrastructure releases must not contain or
reference a feature-extractor container image, model repository, or server-side
model runtime. The app and Lambda owners must return a versioned, bounded feature
contract before campaign processing is activated.

Lambda source commit `9ef72258614ba9fc8639ee7c084c429cc454b33b` is the first
validated server-side implementation of that contract. Its CI and local campaign
evidence pass, but it is not a deployable release identifier until the Lambda
release workflow uploads its immutable ZIPs and `SHA256SUMS` to the environment
artifact bucket.

Never overwrite an existing release object. Build once, verify checksums, and promote the same files to UAT and production.

Example upload:

```bash
aws s3 cp dist/age_attestation.zip \
  "s3://ARTIFACT_BUCKET/releases/2026.09.03-1/age_attestation.zip" \
  --only-show-errors
```

The infrastructure workflow verifies required objects with `HeadObject` before planning dependent stacks. A missing package stops the deployment before API resources change.

Campaign reviewer inputs come from the protected GitHub environment, not
committed `.tfvars` files.

For automatic development deployments, update the `ARTIFACT_RELEASE` variable in the GitHub `dev` environment before merging the infrastructure change. For UAT and production, supply the release identifier to the manual deployment workflow.
