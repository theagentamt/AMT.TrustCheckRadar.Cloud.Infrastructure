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

# Final state; reviewed rollout uses explicit prepare/install overrides first.
post_confirmation_lambda_runtime = "python3.14"
profile_fence_transition_enabled = false
profile_fence_deployment = {
  release_id         = "c4b1cae34b9a90a9803022302a6ad7f2d8a13e38"
  object_version     = "Q3mNvjrnCsqfPOZUCO9LB22jTH5nuWHi"
  source_hash        = "ligB5iVrgSMB5kBfvYveM764yzTX2rFzN1se/Uvybog="
  approval_reference = "SECUR4ALL-244 owner-authorized Dev profile-writer safeguards; reviewed staged rollout"
  promotion_approved = false
}
