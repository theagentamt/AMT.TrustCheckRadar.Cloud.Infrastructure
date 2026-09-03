aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "staging"

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

custom_domain_enabled        = false
purchase_verification_mode   = "live"
analysis_legacy_path_enabled = false
cors_allow_origins           = ["*"]

api_throttle_burst_limit = 50
api_throttle_rate_limit  = 25
