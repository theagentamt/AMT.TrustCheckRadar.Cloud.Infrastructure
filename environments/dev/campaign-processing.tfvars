aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

# Dev is activated only after the contract, model, and security handoffs are accepted.
campaign_processing_enabled = true
promotion_approved          = false
kill_switch_enabled         = false
activation_approved         = true
log_retention_days          = 14

# Deploy this locator-aware publisher before the new analysis producer.
publisher_fence_artifact = {
  release_id         = "8d25e19b691d82caf630edc7ebd84c0b45de0c5c"
  object_version     = "gE.dOLJKp_lVVAKlP874uF9b9U.Uog65"
  source_hash        = "tDoCApsIA14by+yljjfQlzuY04O6sBeWPOk69t12y20="
  approval_reference = "docs/HISTORY-DEV-RELEASE-2026-09-16.md"
  promotion_approved = false
}

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
