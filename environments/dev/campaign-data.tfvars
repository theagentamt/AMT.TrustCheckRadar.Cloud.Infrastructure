aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

# Enable only after SECUR4ALL-213 through SECUR4ALL-215 handoffs are accepted.
campaign_intelligence_enabled = false
promotion_approved            = false
campaign_budget_limit_usd     = 25

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
