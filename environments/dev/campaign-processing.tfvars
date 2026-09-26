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
  release_id         = "f92285b50561397355a5fe2e466d297041336755"
  approval_reference = "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md"
  promotion_approved = false
  workers = {
    publisher = {
      object_version = "GcUQQJ.bJHeSpTYMmrxi0PGHUjOWeVsI"
      source_hash    = "L6UM2rin+UF/RT03Zp9lmETYAdZeH1zVyqC95eAe2K4="
    }
    cluster = {
      object_version = "0lE7FKR3KAjsBo5mJ9x8KamqYF5WqaCL"
      source_hash    = "HbuW0wNMYig46812A5KX43fiAYtv+jaF3TN9WuDp+xU="
    }
    deletion = {
      object_version = "G1uslDwsopxaCLifNnmZ3FhM1ziv2wTR"
      source_hash    = "w3wa+YT63hwH5qahfdB0q/JdppbzK6Uw7KAI43ImkMk="
    }
    lifecycle = {
      object_version = "wr6e6uiYfWq1AU9TG0RrpZyURkH9Bd3I"
      source_hash    = "OquA9UqCumRUeC2rkksCnUtQm/anyBBgHudO9jlTsx8="
    }
  }
}

# Installed code and closed gates verified before restoring normal worker capacity.
reserved_concurrency = 2

# SECUR4ALL-207: permission/scheduling preparation only; all recovery gates stay false.
campaign_recovery_preparation = {
  review_reference = "docs/CAMPAIGN-RECOVERY-PERMISSION-READINESS.md"
}

# SECUR4ALL-207: install actual completion integration with every gate closed.
campaign_completion_artifact = {
  release_id       = "f92285b50561397355a5fe2e466d297041336755"
  object_version   = "G1uslDwsopxaCLifNnmZ3FhM1ziv2wTR"
  source_hash      = "w3wa+YT63hwH5qahfdB0q/JdppbzK6Uw7KAI43ImkMk="
  review_reference = "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md"
}

# SECUR4ALL-207: coordinated period admission candidate; all gates remain closed.
campaign_period_fence_preparation = {
  review_reference = "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md"
}

campaign_account_cleanup_preparation = {
  review_reference = "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md"
}
