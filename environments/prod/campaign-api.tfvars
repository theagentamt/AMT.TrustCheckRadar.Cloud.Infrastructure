aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "prod"

campaign_api_enabled        = false
campaign_review_api_enabled = false
promotion_approved          = false
log_retention_days          = 90

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
