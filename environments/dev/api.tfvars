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

# Canonical client route. The execute-api surface remains enabled during the
# coordinated Android/Lambda migration and retains the same JWT protection.
age_attestation_canonical_base_url = "https://api-dev.andmorethings.net"

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

# Reviewed account deletion keeps its existing scope; account export stays disabled.
account_export_deployment = {
  "approval_reference" : "docs/SECUR4ALL-233-URL-FRESHNESS-ROLLOUT.md",
  "authority_hmac_secret_arn" : "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-C7v1hG",
  "object_version" : "kNsH.VDnrYwv13dik0kM32ZosrM1AJ80",
  "promotion_approved" : false,
  "release_id" : "27ba230f6a96fe5bf1c96719903c3c7016765bbb",
  "source_hash" : "l/+b7HSw0SBY+k4qFdMW8iPiwdawaYqRhN+uaxvXejE="
}
account_export_play_token_table_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens"
account_data_deployment = {
  "approval_reference" : "docs/SECUR4ALL-207-DEV-ACCEPTANCE.md",
  "object_version" : "EmM1M09.oOG6E2Omk4WewgQ8polMTMFW",
  "promotion_approved" : false,
  "release_id" : "9147d545b719e54c1f967e35042bc502d79bc0f1",
  "source_hash" : "wUFODgRz1RaJPvbcCHq1WdFDFr/VGHFeMlly0xVKLtg="
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

age_attestation_monitoring = {
  alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
}

# SECUR4ALL-207: recovery permissions retained; activation is explicitly pinned below.
campaign_recovery_preparation = {
  review_reference = "docs/CAMPAIGN-RECOVERY-PERMISSION-READINESS.md"
}

# Exact reviewed closed-runtime compatibility after the initial migration.
research_campaign_release_compatibility = {
  "api_release_sha" : "d98ffd65b42d54953ad83e980e58846b6fc02c5d",
  "consumer_release_sha" : "9147d545b719e54c1f967e35042bc502d79bc0f1",
  "review_reference" : "docs/SECUR4ALL-207-DEV-ACCEPTANCE.md"
}

# Reviewed cleanup-only Dev qualification; all unrelated admission stays closed.
account_data_finalization_candidate = {
  "manifest_sha256" : "73ecea2a6f9c8c392fadba7eacd65d367cc6ab7553715f4b40cc2ce627d1885c",
  "inventory_revision" : 1,
  "approval_reference" : "docs/evidence/live-account-deletion-2026-09-26/external-approval.json"
}

# Reviewed cleanup-only Dev qualification; all unrelated admission stays closed.
account_deletion_activation = {
  "component_reference" : "docs/evidence/live-account-deletion-2026-09-26/all-component-runtime.json",
  "http_subjects" : [
    "c4685448-1021-7014-8ef4-b326afee90ae"
  ],
  "identity_reference" : "docs/evidence/live-account-deletion-2026-09-26/cognito-normal-runtime.json; docs/evidence/live-account-deletion-2026-09-26/cognito-lost-ack-runtime.json",
  "inventory_reference" : "docs/evidence/live-account-deletion-2026-09-26/external-approval.json",
  "phase" : "api",
  "policy_reference" : "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md",
  "source_sha" : "9147d545b719e54c1f967e35042bc502d79bc0f1",
  "worker_acceptance_reference" : "docs/evidence/live-account-deletion-2026-09-26/cleanup-worker-corrected-runtime.json"
}

# SECUR4ALL-207: reviewed Dev indexed lifecycle configuration.
campaign_period_work_preparation = {
  "review_reference" : "docs/SECUR4ALL-207-DEV-ACCEPTANCE.md"
}

# SECUR4ALL-207: reviewed Dev indexed lifecycle configuration.
campaign_period_work_quiescence = false

# SECUR4ALL-207: reviewed Dev indexed lifecycle configuration.
campaign_period_work_activation = {
  "source_sha" : "9147d545b719e54c1f967e35042bc502d79bc0f1",
  "generation" : "9f7311a2-34c9-4fe8-8fbf-56974ab32897",
  "manifest_sha256" : "31695c1ad9ac9d0b9382cbfd9a50dc535dcb1b03f2dbe7ad64fc612484790ef0",
  "inventory_revision" : 1,
  "locator_manifest_sha256" : "bde6307ac73e1a6f60533216270566b2db0c822aa1b777cbf1e1013a168eb73f",
  "locator_inventory_revision" : 1,
  "pipeline_table_id" : "6a8d5278-235e-45ac-9ccc-87d0ef6c368d",
  "outbox_table_id" : "37dda667-d982-4568-8bcf-ce5297362eda",
  "inventory_reference" : "docs/evidence/sec207-period-dev-deployment-2026-09-27/external-operator-review.json",
  "runtime_reference" : "docs/evidence/sec207-period-lifecycle-2026-09-27/retire-then-complete-result.json",
  "iam_reference" : "docs/evidence/sec207-period-iam-2026-09-27/qualification.json"
}

# Read-only exporter upgrade preserves the qualified period-work writer source.
account_export_work_compatibility = {
  "work_source_sha" : "9147d545b719e54c1f967e35042bc502d79bc0f1",
  "export_source_sha" : "27ba230f6a96fe5bf1c96719903c3c7016765bbb",
  "review_reference" : "docs/SECUR4ALL-233-URL-FRESHNESS-ROLLOUT.md"
}

# Preserve the deployed SEC333 disabled support route when planning this stack.
support_account_deletion_deployment = {
  "approval_reference" : "SECUR4ALL-333 source reviewed and integrated; disabled Dev candidate only",
  "object_version" : "p.wEH4bDlnLR4Zuircd39RisgRlWVfgn",
  "release_id" : "476d9ecb54f8ddd9b7299d214df37c025f4c3e0b",
  "source_hash" : "8C0SHgsUI3IT+KOZEUEZNQvIl20HQCkcw5O13O1fTko="
}
support_account_deletion_gateway = {
  "api_id" : "icuak34th9",
  "approval_reference" : "SEC333 owner go-ahead protected endpoint and automated Dev validation; disabled only",
  "stage" : "$default"
}
support_account_deletion_activation = null
