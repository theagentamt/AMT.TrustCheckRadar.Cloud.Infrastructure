aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

artifact_bucket_force_destroy = true
hosted_ui_enabled             = false
users_status_gsi_enabled      = true

backend_assume_role_principals  = ["lambda.amazonaws.com"]
deletion_assume_role_principals = ["lambda.amazonaws.com"]
campaign_intelligence_enabled   = true

# Policy approval does not authorize provisioning or consumer activation.
device_recovery_control_enabled = false
device_recovery_policy = {
  approved               = true
  approval_reference     = "docs/ACCOUNT-DATA-POLICY-DECISIONS.md#owner-approval-2026-09-14"
  audit_retention_days   = 90
  receipt_retention_days = 7
  rate_retention_hours   = 24
  pitr_days              = 7
}

# SECUR4ALL-207: sparse index preparation only; producers and recovery remain disabled.
campaign_recovery_index_enabled = true
