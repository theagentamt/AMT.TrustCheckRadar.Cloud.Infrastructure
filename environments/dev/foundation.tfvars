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

# Live-deletion work requires the approved recovery store for complete cleanup.
# Provisioning storage does not enable account deletion or recovery consumers.
device_recovery_control_enabled = true
device_recovery_policy = {
  approved               = true
  approval_reference     = "docs/ACCOUNT-DATA-POLICY-DECISIONS.md#owner-approval-2026-09-14"
  audit_retention_days   = 90
  receipt_retention_days = 7
  rate_retention_hours   = 24
  pitr_days              = 7
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

# SECUR4ALL-207: sparse index preparation only; producers and recovery remain disabled.
campaign_recovery_index_enabled = true

# SEC340: persist the reviewed sparse History index selection before its
# guarded Dev CI/CD apply. Ordinary deployment still refuses index transitions.
governed_history_index_enabled = true
