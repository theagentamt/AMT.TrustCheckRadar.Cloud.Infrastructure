aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

# Existing log group is adopted by the reviewed Dev import block.
post_confirmation_log_policy = {
  retention_days     = 14
  approval_reference = "ACCOUNT-DATA-POLICY-DECISIONS.md owner approval 2026-09-14; SECUR4ALL-244 reviewed Dev rollout"
}
