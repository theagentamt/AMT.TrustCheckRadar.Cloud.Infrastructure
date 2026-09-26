aws_region                   = "us-east-1"
project_name                 = "trustcheckradar"
environment                  = "dev"
lifecycle_deployment_enabled = true
lifecycle_active             = false
promotion_approved           = false
artifact = {
  release_id     = "997e265f7edf10ce7369481f7d576b4276e8c418"
  object_version = "SvmeivNaRX6jvi1gAk6cLRknboQVnUNi"
  source_hash    = "zHa0WXJftct6dx1aAfpfSyEGnKNM7ak5t49FbhV0+n8="
}
# Dev mutation receipts: owner-approved 7 days. Operational policy and live
# acceptance remain pending; do not activate by substituting test values.
runtime_policy  = null
alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-campaign-budget-alerts"

account_deletion_artifact = {
  release_id     = "997e265f7edf10ce7369481f7d576b4276e8c418"
  object_version = "yCNWRY9QiwqgvSkNwJiij3I.GZ7LmZ58"
  source_hash    = "z30oWQNIh/9C4iMmgw6b31RmXbLP2RjZd3HFgYW2zuw="
}
account_deletion_active                 = false
account_deletion_observability_approved = false

# Corrected immutable receipt producers; coordinated activation remains off.
account_deletion_terminal_candidate = true
