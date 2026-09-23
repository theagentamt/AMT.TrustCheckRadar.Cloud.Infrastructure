# Dev closed Play account privacy candidates

SECUR4ALL-244/125 selects the published `account_export_api` and `account_data_api`
artifacts from Lambda source `39cce61623794a123e61d25f5248b0c081eccf4a` for an
owner-authorized disabled Dev deployment. The exact versions and hashes are in
`environments/dev/api.tfvars` and the existing
[publication record](evidence/play-lifecycle-dev-2026-09-23/publication.json).
This is a deployment selection, not evidence of applied resources or enabled
export/deletion. An applied record will be added after saved-plan qualification.

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
