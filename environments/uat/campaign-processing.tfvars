aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "uat"

campaign_processing_enabled = false
promotion_approved          = false
kill_switch_enabled         = true
activation_approved         = false
log_retention_days          = 30

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
