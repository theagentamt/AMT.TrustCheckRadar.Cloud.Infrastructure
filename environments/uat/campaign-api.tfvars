aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "uat"

campaign_api_enabled        = false
campaign_review_api_enabled = false
promotion_approved          = false
log_retention_days          = 30

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
