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
  release_id         = "cab9a2a3976e52b64b75057a8432b1506a365b02"
  approval_reference = "docs/CAMPAIGN-PERIOD-ADMISSION.md"
  promotion_approved = false
  workers = {
    publisher = {
      object_version = "Wun74uNFT5jALtlplbXYXAM.gPxNmRH0"
      source_hash    = "RAIFC3HCgwfCIOZK/+rVWC0LyHTp7xpz42lLAuOc56w="
    }
    cluster = {
      object_version = "HnHIU59qeJdL9enK_BD_.0VlT1uPzuIZ"
      source_hash    = "ATkFbdQyn5uDD4nEYb6A7s0ceOQIYWzJiIucTPSCPwk="
    }
    deletion = {
      object_version = "Obz.qyXSypzZXcH3oA55V5BdjCxPtfCB"
      source_hash    = "Fy8gTcYd/ZYILh/7hu1Vnd01Ma7MK0YbUNKk8Y7q9GM="
    }
    lifecycle = {
      object_version = "9GrjFGD4qPFc5eZ3XZjTOUYvqGiegKy8"
      source_hash    = "/skIiDDzLddciU3V55Je4NlVNDYT3OCrnCmT6knaBRs="
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
  release_id       = "cab9a2a3976e52b64b75057a8432b1506a365b02"
  object_version   = "Obz.qyXSypzZXcH3oA55V5BdjCxPtfCB"
  source_hash      = "Fy8gTcYd/ZYILh/7hu1Vnd01Ma7MK0YbUNKk8Y7q9GM="
  review_reference = "docs/CAMPAIGN-PERIOD-ADMISSION.md"
}

# SECUR4ALL-207: coordinated period admission candidate; all gates remain closed.
campaign_period_fence_preparation = {
  review_reference = "docs/CAMPAIGN-PERIOD-ADMISSION.md"
}
