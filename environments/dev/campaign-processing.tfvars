aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

# Dev is activated only after the contract, model, and security handoffs are accepted.
campaign_processing_enabled = true
promotion_approved          = false
kill_switch_enabled         = false
log_retention_days          = 14

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
