aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "prod"

campaign_intelligence_enabled          = false
promotion_approved                     = false
campaign_budget_limit_usd              = 50
persistent_deletion_protection_enabled = true

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}
