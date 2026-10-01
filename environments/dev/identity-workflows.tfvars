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

age_attestation_contract = {
  approval_reference = "ATCR-74 owner-approved Dev adult self-attestation rollout; reviewed Lambda f8f091c, Android cd6e29b, infrastructure c586537"
  promotion_approved = false
  artifacts = {
    age_attestation = {
      release_id     = "atcr74-age-authority-f8f091c"
      object_version = "xw2._HvBtaROylLJnMTI_.s2TOa7b1O1"
      source_hash    = "GIxLSZ2egFTrPr/zH9FLMPdCkoGzeW7o3UTQ37fY8sU="
    }
    post_confirmation = {
      release_id     = "atcr74-age-authority-f8f091c"
      object_version = "lgl3gBUczrha6AzRrpUYhB8bF6955rB."
      source_hash    = "hef5SOmcheAm4N9/qj5Slq4E8gPmGvudM0cwJggOVSg="
    }
  }
}
