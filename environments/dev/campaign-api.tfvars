aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

# The immutable API artifacts and V1 contracts are approved for Dev.
campaign_api_enabled        = true
campaign_review_api_enabled = true
promotion_approved          = false
log_retention_days          = 14

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
