aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

custom_domain_enabled        = false
purchase_verification_mode   = "stub"
analysis_legacy_path_enabled = false
cors_allow_origins           = ["*"]

api_throttle_burst_limit = 20
api_throttle_rate_limit  = 10
