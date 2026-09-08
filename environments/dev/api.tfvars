aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

campaign_intelligence_enabled = true

campaign_participation_notice_version          = "2026-09-07"
campaign_participation_policy_version          = "policy-1"
campaign_participation_audit_retention_days    = 400
campaign_participation_deletion_sla_hours      = 24
campaign_participating_free_monthly_scan_limit = 15

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

disable_execute_api_endpoint  = false
purchase_verification_mode    = "stub"
analysis_legacy_path_enabled  = false
enable_device_recovery        = true
enable_web_risk_communication = true
cors_allow_origins            = ["*"]

api_throttle_burst_limit = 20
api_throttle_rate_limit  = 10
