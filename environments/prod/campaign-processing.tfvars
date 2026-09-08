aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "prod"

campaign_processing_enabled = false
promotion_approved          = false
kill_switch_enabled         = true
activation_approved         = false
log_retention_days          = 90

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
