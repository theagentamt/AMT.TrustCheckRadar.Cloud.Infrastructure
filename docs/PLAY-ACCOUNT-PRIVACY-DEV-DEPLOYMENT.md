# Dev closed Play account privacy candidates

SECUR4ALL-244/125 selects the published `account_export_api` and `account_data_api`
artifacts from Lambda source `39cce61623794a123e61d25f5248b0c081eccf4a` for an
owner-authorized disabled Dev deployment. The exact versions and hashes are in
`environments/dev/api.tfvars` and the existing
[publication record](evidence/play-lifecycle-dev-2026-09-23/publication.json).
The closed deployment was applied as recorded below. This is not evidence of
enabled export/deletion or completed live retention/erasure acceptance.

Export receives owned-partition token metadata read permissions and the token
table name. Both export switches remain false; candidate.3 is not enabled and
candidate.2 compatibility remains available in the code. Account-data deletion,
session-revocation reconciliation, identity mapping and finalization remain
disabled. The finalization candidate stays unset because a new qualified
PLAY_TOKENS inventory is not yet available; no AdminDeleteUser grant is added.
There are no new public export/account-data routes. Stream mapping and scheduled
reconciliation remain disabled. The export cursor secret is an empty container;
no keyring is created by this selection. Alerts use the existing confirmed
support destination, with scheduled-only missing-heartbeat actions disarmed.

Account-data IAM separates regional `ListStreams` discovery (`Resource: "*"`
with `aws:RequestedRegion`) from exact-stream content reads. AWS lists no resource
type for [ListStreams](https://docs.aws.amazon.com/service-authorization/latest/reference/list_dynamodb.html);
binding that action only to a stream ARN does not grant the required discovery.
The dedicated preparation-route throttle is selected now that its existing
JWT-protected route has been deployed; it does not activate paid processing.

Before activation, qualify the full inventory including PLAY_TOKENS, subject
mapping, cursor key setup, erasure/export and cleanup deadlines. The five-minute
cleanup checkpoint retention decision remains separate and pending. Google
authenticated delivery and actual store transactions remain unproven by disabled
smoke or synthetic SDK tests. Physical testing remains in the existing follow-up.

## Applied and verified, 2026-09-23

Source PR63 merged at `784828cedb7f6a3dddf81404d73178869354bdfa` after independent
source and exact-plan review. The saved plan created 33 resources and updated only
the API stage to add the existing prepare route's 4/2 throttle; there were no
deletes or changes to other functions. All 46 privacy and 19 route-throttle
Terraform tests passed. The exact saved plan was applied and a fresh plan returned
exit code 0 (no drift).

Both functions are unqualified **$LATEST** candidates, not published versions or
live aliases. AWS readback verified the manifest code hashes, Python 3.14 ARM64,
resolved disabled feature flags, pending inventory and disabled username mapping.
Neither role grants AdminDeleteUser. Export has GetItem/Query token metadata
permissions and no Play-token CMK decryption grant; its separate campaign KMS
permissions remain scoped to their existing purpose. The export cursor secret
has no versions. The deletion mapping and reconciliation rule remain disabled.

Five installed identity-policy simulations passed: same-region stream discovery
and own-stream reads allowed; other-region discovery, unrelated-stream reads and
export decryption with the Play-token CMK denied. This does not prove runtime KMS
or end-to-end deletion behavior.

The Lambda owner separately invoked each candidate once with an empty event,
checking exact code hash, flags and RevisionId before and after. Export returned
503 SERVICE_NOT_ENABLED and account-data returned 503 FEATURE_DISABLED, with no
FunctionError. These validate disabled entrypoints only; no provider/customer
operation, cursor value, inventory approval or activation was performed.

- [Saved-plan deployment record](evidence/play-lifecycle-dev-2026-09-23/privacy-deployment.json)
- [Resolved configuration readback](evidence/play-lifecycle-dev-2026-09-23/privacy-readback.json)
- [Installed IAM simulations](evidence/play-lifecycle-dev-2026-09-23/privacy-iam-simulation.json)
