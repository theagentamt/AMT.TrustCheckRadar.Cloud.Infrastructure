aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

# Enable only after the contract, model, and security handoffs are accepted.
campaign_processing_enabled = false
promotion_approved          = false
kill_switch_enabled         = true
log_retention_days          = 14

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
