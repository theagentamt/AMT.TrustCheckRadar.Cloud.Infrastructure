aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"

# Dev is activated only after the contract, model, and security handoffs are accepted.
campaign_processing_enabled = true
promotion_approved          = false
kill_switch_enabled         = true
activation_approved         = true
log_retention_days          = 14

# Deploy this locator-aware publisher before the new analysis producer.
publisher_fence_artifact = null

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  CostCenter  = "TrustCheckRadar"
}

# Owner-authorized Dev migration; new contribution/cleanup activation remains closed.
research_consent_migration = true
account_privacy_artifacts = {
  release_id         = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
  approval_reference = "docs/DEV-RESEARCH-RUNTIME-MIGRATION.md"
  promotion_approved = false
  workers = {
    publisher = {
      object_version = "Qdy6.zZRjmqTNEpeCR.TKn4RCVjzcUz8"
      source_hash    = "n/08qq/fpGZx/fob8iTvxitMVRpACwfTvt7ScUJuSbE="
    }
    cluster = {
      object_version = "KRIssk3ZBbu.Shm2HFhKZ1HkyviAUrNB"
      source_hash    = "ppaduE5zmMxeKYX1w8JBuRrVgTtFMp39+RyzMF+C4ho="
    }
    deletion = {
      object_version = "lqMTcToIkcZ.uaznyAVY5ffZPZEARnV9"
      source_hash    = "FItTXNai302HOO+oHnMNj70y6t0r/5YeWjScTX7QQMQ="
    }
    lifecycle = {
      object_version = "Ll8L1RLM2Uxn8LPnAmzES5hZFXO6QG8H"
      source_hash    = "PehVB8VPv4/tkcNrigxD6Ce64mUwsET9qX10P+UAkJo="
    }
  }
}

# Keep invocations fenced during code/IAM installation; restore in a verified second step.
reserved_concurrency = 0
