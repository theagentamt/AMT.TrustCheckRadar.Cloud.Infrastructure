aws_region                   = "us-east-1"
project_name                 = "trustcheckradar"
environment                  = "dev"
lifecycle_deployment_enabled = true
lifecycle_active             = true
promotion_approved           = false
artifact = {
  release_id     = "1dd917057527e58cf07c70eb0155991cb6c5bb3c"
  object_version = "90QNrBATjzc1VOUYsi_gU43xuZdWSrcT"
  source_hash    = "M3HltayXPA3yle/4K7YeQXGnXyiRMgBliT8FN6o9zqo="
}
# Dev mutation receipts: owner-approved seven days. Current empty-store bootstrap
# and bounded cleanup cadence are bound to the reviewed qualification manifest.
runtime_policy = {
  "acceptance_approved" : true,
  "approval_reference" : "docs/evidence/live-account-deletion-2026-09-26/history-deployment-readback.json; docs/evidence/live-account-deletion-2026-09-26/all-component-runtime.json; docs/evidence/live-account-deletion-2026-09-26/account-qualified-manifest.json",
  "mutation_retention_days" : 7,
  "start_epoch_hour" : 1790431200,
  "max_items_per_sweep" : 100,
  "max_bucket_queries_per_sweep" : 100,
  "expiration_reconciliation_hours" : 24,
  "erasure_batch_size" : 25,
  "completion_stuck_seconds" : 900,
  "completion_recheck_seconds" : 300
}
alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-campaign-budget-alerts"

account_deletion_artifact = {
  release_id     = "1dd917057527e58cf07c70eb0155991cb6c5bb3c"
  object_version = "NXD98uIY5D9TJiKkQWS1lTo3r1BcRFEI"
  source_hash    = "z30oWQNIh/9C4iMmgw6b31RmXbLP2RjZd3HFgYW2zuw="
}
account_deletion_active                 = true
account_deletion_observability_approved = true

# Corrected immutable receipt producers; reviewed cleanup activation selected below.
account_deletion_terminal_candidate = true

# Reviewed cleanup-only Dev qualification; all unrelated admission stays closed.
account_deletion_terminal_activation = {
  "source_sha" : "1dd917057527e58cf07c70eb0155991cb6c5bb3c",
  "runtime_reference" : "docs/evidence/live-account-deletion-2026-09-26/all-component-runtime.json",
  "permissions_reference" : "docs/evidence/live-account-deletion-2026-09-26/history-bridge-iam.json; docs/evidence/live-account-deletion-2026-09-26/history-lifecycle-iam.json"
}
