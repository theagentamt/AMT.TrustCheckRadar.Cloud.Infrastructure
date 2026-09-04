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
releases/2026.09.03-1/post_confirmation.zip
releases/2026.09.03-1/web_risk_communication.zip
```

Never overwrite an existing release object. Build once, verify checksums, and promote the same files to UAT and production.

Example upload:

```bash
aws s3 cp dist/age_attestation.zip \
  "s3://ARTIFACT_BUCKET/releases/2026.09.03-1/age_attestation.zip" \
  --only-show-errors
```

The infrastructure workflow verifies required objects with `HeadObject` before planning dependent stacks. A missing package stops the deployment before API resources change.

For automatic development deployments, update the `ARTIFACT_RELEASE` variable in the GitHub `dev` environment before merging the infrastructure change. For UAT and production, supply the release identifier to the manual deployment workflow.
