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

# Owner-authorized Dev deployment; activation requires live acceptance separately.
history_deployment = {
  release_id         = "8d25e19b691d82caf630edc7ebd84c0b45de0c5c"
  approval_reference = "docs/HISTORY-DEV-RELEASE-2026-09-16.md"
  promotion_approved = false
  artifacts = {
    read = {
      object_version = "u04P8w6W2JYl.KRGzimBmTv41OxpEp4D"
      source_hash    = "1fc+oH3pVjk3L/dyVlX9fy9tXgNWjlmpQonAml9SaLg="
    }
    mutation = {
      object_version = "WMThHcecTd6ncm2QfXcJbp76.mN30hFF"
      source_hash    = "dRT2+7WAc/AX7WRk3RGkZCxNiYv8ierMMXw8x5T2VnU="
    }
    analysis = {
      object_version = "Cx14E6dwXcnL5d.VduhOr2kgE3_MH7.X"
      source_hash    = "HYPqkq+XAQ0xR2HwJkJqxRFKiVxnsGzU3TI1kQuFIUQ="
    }
  }
}

history_features = {
  reads          = false
  writes         = false
  mutations      = false
  recognition    = false
  durable_replay = false
}

device_recovery_deployment = {
  release_id         = "8d25e19b691d82caf630edc7ebd84c0b45de0c5c"
  approval_reference = "docs/HISTORY-DEV-RELEASE-2026-09-16.md"
  promotion_approved = false
  artifacts = {
    registration = {
      object_version = "waJur7d8Ko6AhwfwLWh3HuUA.379jJgB"
      source_hash    = "444P9ooO3cfqGUMlIGFEVXIh2YzuRkVxlaw7edHjheY="
    }
    recovery = {
      object_version = "GnvoHx6mYLig05E3msmOFTQ.lfQSInW3"
      source_hash    = "PcZ8tfY6Hu91NeI/IWTIz719S9vRHi3cjdcS1nT7U7U="
    }
  }
}
