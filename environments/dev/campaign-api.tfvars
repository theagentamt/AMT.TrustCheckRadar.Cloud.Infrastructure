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

# SECUR4ALL-207: reviewed Dev indexed lifecycle configuration.
campaign_review_reserved_concurrency = 1

# SECUR4ALL-207: reviewed Dev indexed lifecycle configuration.
campaign_review_expiry_deployment = {
  "source_sha" : "9147d545b719e54c1f967e35042bc502d79bc0f1",
  "object_version" : "Ui28hPJLkxUJcJZFcraPZJ4gWeuYmPmS",
  "source_hash" : "Wa9bTRhpH4HyRtrwp+eyLb+lumOsXpFKEgOnRl5EBkc=",
  "review_reference" : "docs/SECUR4ALL-207-DEV-ACCEPTANCE.md"
}
