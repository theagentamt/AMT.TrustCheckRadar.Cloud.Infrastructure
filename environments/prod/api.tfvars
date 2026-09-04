aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "prod"

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

disable_execute_api_endpoint  = true
purchase_verification_mode    = "live"
analysis_legacy_path_enabled  = false
enable_device_recovery        = true
enable_web_risk_communication = true
cors_allow_origins            = ["*"]

api_throttle_burst_limit = 100
api_throttle_rate_limit  = 50
