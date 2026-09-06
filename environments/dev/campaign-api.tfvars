aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

# Enable only after SECUR4ALL-211 returns an immutable artifact and the
# SECUR4ALL-213 contract is accepted.
campaign_api_enabled        = false
campaign_review_api_enabled = false
promotion_approved          = false
log_retention_days          = 14

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
