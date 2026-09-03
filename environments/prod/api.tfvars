aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "prod"

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

custom_domain_enabled        = true
api_domain_name              = "api.andmorethings.net"
route53_zone_name            = "andmorethings.net"
api_mapping_key              = "TrustCheckRadar/Api"
purchase_verification_mode   = "live"
analysis_legacy_path_enabled = false
cors_allow_origins           = ["*"]

api_throttle_burst_limit = 100
api_throttle_rate_limit  = 50
