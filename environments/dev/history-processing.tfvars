aws_region                   = "us-east-1"
project_name                 = "trustcheckradar"
environment                  = "dev"
lifecycle_deployment_enabled = true
lifecycle_active             = false
promotion_approved           = false
artifact = {
  release_id     = "8d25e19b691d82caf630edc7ebd84c0b45de0c5c"
  object_version = "R_oBvxMKtEKSjiBhueaCFf1TDMnUDN9R"
  source_hash    = "HhNfYQWlaB6naDnKqc4qvtjN6a2p6cVwpjQ7Joy8aW4="
}
# Dev mutation receipts: owner-approved 7 days. Operational policy and live
# acceptance remain pending; do not activate by substituting test values.
runtime_policy  = null
alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-campaign-budget-alerts"

account_deletion_artifact = {
  release_id     = "8d25e19b691d82caf630edc7ebd84c0b45de0c5c"
  object_version = "6EcmJQeWQj6QOyGexwh4Spf.e6lZ5DIH"
  source_hash    = "w6o4BXKMxW2whO/36eQTOUFhsoj7sDyJ5kTStvlkbSU="
}
account_deletion_active                 = false
account_deletion_observability_approved = false
