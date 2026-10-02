# SECUR4ALL-232 complimentary-access operator runbook

This control grants or revokes complimentary access for one stable account ID.
It does not accept phone numbers, email addresses, purchase tokens, messages or
URLs. It does not change research consent, administrative roles, device binding,
provider budgets, rate limits or in-flight limits.

## Access boundary

- Assume `trustcheckradar-dev-complimentary-operator` from the exact reviewed
  administrator role. The session lasts at most one hour.
- Sign one `POST /v1/operator/complimentary-access` request with AWS SigV4.
- The role can invoke only the `$default` stage, `POST` method and this path. It
  has no direct Lambda, DynamoDB, Secrets Manager or object-storage access.
- Never call the Lambda directly. Never put operator identity in the body; the
  service derives it from API Gateway's signed IAM context.

## Request procedure

1. Resolve the user's stable account ID through an approved support process.
   Do not save their phone number or email in the request file.
2. Create a unique `operationId` of at most 64 letters, numbers, underscores or
   hyphens. Reuse that exact ID and body only when retrying a lost response.
3. Store the JSON request in a temporary file readable only by its owner.
4. For an indefinite owner grant, send:

   ```json
   {
     "schemaVersion": 1,
     "operationId": "owner-grant-unique-id",
     "accountId": "stable-account-id",
     "action": "grant",
     "reasonCode": "OWNER_GRANT",
     "expiresAtEpoch": null
   }
   ```

5. For a fixed grant, use a future integer epoch in `expiresAtEpoch`. For a
   revoke, use `action: "revoke"`, `reasonCode: "REVOKE"`, and
   `expiresAtEpoch: null`.
6. Sign and send the request with an AWS SigV4-capable client. Require HTTP 200
   and record only the operation ID, returned revision/state/basis, operator and
   completion time in the support case.
7. If the response is lost, retry the identical body with the same operation ID.
   A changed body requires a new operation ID.
8. Verify effective access through the normal account access snapshot. Do not
   read or edit DynamoDB directly.
9. Securely delete the temporary request file.

## Retention and rollback

An active no-expiry grant audit remains while the grant is active. A fixed grant
expires one year after its access expiry. Revoke or replacement retains the
affected audit for one year from that action. Account deletion removes still
linked authority and audit rows; disclosed backups may retain deleted data for
up to 35 additional days.

Set `complimentary_operator.active = false` and deploy the reviewed Terraform
plan to close the service before the authority secret is read. The role and
AWS_IAM route may remain provisioned for a later reviewed reactivation.
