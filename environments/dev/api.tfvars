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
  release_id         = "c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca"
  approval_reference = "docs/HISTORY-DEV-CORRECTION-2026-09-16.md"
  promotion_approved = false
  artifacts = {
    read = {
      object_version = "Ki9acQ0La1lmYO2LVH2gVe5fzKphJADt"
      source_hash    = "1fc+oH3pVjk3L/dyVlX9fy9tXgNWjlmpQonAml9SaLg="
    }
    mutation = {
      object_version = "lPScl1FCImts92iSt3qy9DfCToBUIwxN"
      source_hash    = "dRT2+7WAc/AX7WRk3RGkZCxNiYv8ierMMXw8x5T2VnU="
    }
    analysis = {
      object_version = "mq8Y2J5qJTbXdVHet3DKRFezoBnpTm1z"
      source_hash    = "b1Qzzpm5PcJl/3jkTPrK1soU833O7N/hw6040QUTZ5o="
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

# Apply after the same-release paused campaign contract.
research_consent_migration_deployment = {
  release_id         = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
  approval_reference = "docs/DEV-RESEARCH-RUNTIME-MIGRATION.md"
  promotion_approved = false
  consent_enabled    = false
  artifacts = {
    analysis = {
      object_version = "K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1"
      source_hash    = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4="
    }
    participation = {
      object_version = "JFtcjKqccqtDkTVQREwMn8R7mlSPGNJZ"
      source_hash    = "p+wPYSC7BSxN5jYSffePQAu2DLZLfDhZ+cJLKP2dnX8="
    }
    snapshot = {
      object_version = "wm7VjLE.iVAv9r.MwZwgWsAYwdHm6jxP"
      source_hash    = "3HxxsEAtAEKls89OxN91CfNQo1edq6ucNus4r+o2RVo="
    }
    web_risk = {
      object_version = "kD.vAr62k1w78y_K4VA_s5ooBctKpb8."
      source_hash    = "rOF7rlDO8hJA/u1SHOiC1ebYM5I3czocmUtj77wwnCI="
    }
    purchase = {
      object_version = "zUIPAp_ZSg.QN2XoDtEBBRiGWvb19A2d"
      source_hash    = "fbF+jSPpXRPrYKqDtE3jcosIMAfnpZLlsztfkaSyvRI="
    }
  }
}

# Installed code and IAM restrictions verified before restoring normal API capacity.
analysis_lambda_reserved_concurrency               = 5
campaign_participation_lambda_reserved_concurrency = 5
entitlement_snapshot_lambda_reserved_concurrency   = 5
purchase_handoff_lambda_reserved_concurrency       = 5
web_risk_communication_lambda_reserved_concurrency = 5

play_verification_route_throttle_enabled = true
play_preparation_route_throttle_enabled  = true

# Closed privacy candidates; inventory/finalization and public routing remain gated.
account_export_deployment = {
  release_id                = "e1651f86e30fc1478f69ba16a4049be8baf0e5f3"
  object_version            = "YNLn3_R23z7m.OIi_0AfJCu5abU2btay"
  source_hash               = "ynYTDY4o8nhqZOq+uIuyFTckEamaec1TWt9TKmRdsSk="
  approval_reference        = "docs/PLAY-ACCOUNT-PRIVACY-DEV-DEPLOYMENT.md"
  promotion_approved        = false
  authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-C7v1hG"
}
account_export_play_token_table_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens"
account_data_deployment = {
  release_id         = "eba5d938c1da5cf36540cf654e674f46bba3fa71"
  object_version     = "Hmz9pOvMLuHr4x45wL3B05i.EaVe4CZg"
  source_hash        = "7gXjecACio4Di2m383J+pwUkFz1yzLCcGqbNJ3359kY="
  approval_reference = "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md"
  promotion_approved = false
}
account_export_monitoring = {
  alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
}
account_data_monitoring = {
  alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
}

# Final state; reviewed rollout uses explicit prepare/install overrides first.
age_attestation_lambda_runtime   = "python3.14"
profile_fence_transition_enabled = false
profile_fence_deployment = {
  release_id         = "c4b1cae34b9a90a9803022302a6ad7f2d8a13e38"
  object_version     = "oC3vBJfvil2SDUji4XbWM3fjUlmrfEXV"
  source_hash        = "4fcLN8YHPOZNgY3iTt4gzlicbXMHdv1ToF//NWUzeBg="
  approval_reference = "SECUR4ALL-244 owner-authorized Dev profile-writer safeguards; reviewed staged rollout"
  promotion_approved = false
}

# SECUR4ALL-207: permission/scheduling preparation only; all recovery gates stay false.
campaign_recovery_preparation = {
  review_reference = "docs/CAMPAIGN-RECOVERY-PERMISSION-READINESS.md"
}

# Exact reviewed closed-runtime compatibility after the initial migration.
research_campaign_release_compatibility = {
  api_release_sha      = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
  consumer_release_sha = "f92285b50561397355a5fe2e466d297041336755"
  review_reference     = "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md#closed-api-consumer-compatibility"
}

# Reviewed cleanup-only Dev qualification; all unrelated admission stays closed.
account_data_finalization_candidate = {
  "manifest_sha256" : "73ecea2a6f9c8c392fadba7eacd65d367cc6ab7553715f4b40cc2ce627d1885c",
  "inventory_revision" : 1,
  "approval_reference" : "docs/evidence/live-account-deletion-2026-09-26/external-approval.json"
}

# Reviewed cleanup-only Dev qualification; all unrelated admission stays closed.
account_deletion_activation = {
  "phase" : "api",
  "source_sha" : "eba5d938c1da5cf36540cf654e674f46bba3fa71",
  "policy_reference" : "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md",
  "inventory_reference" : "docs/evidence/live-account-deletion-2026-09-26/external-approval.json",
  "identity_reference" : "docs/evidence/live-account-deletion-2026-09-26/cognito-normal-runtime.json; docs/evidence/live-account-deletion-2026-09-26/cognito-lost-ack-runtime.json",
  "component_reference" : "docs/evidence/live-account-deletion-2026-09-26/all-component-runtime.json",
  "worker_acceptance_reference" : "docs/evidence/live-account-deletion-2026-09-26/cleanup-worker-corrected-runtime.json",
  "http_subjects" : ["f42804a8-60b1-706e-eac4-113371eab1ee"]
}
