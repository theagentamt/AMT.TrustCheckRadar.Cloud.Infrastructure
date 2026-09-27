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

# Owner-authorized Dev cleanup; new research contribution remains closed.
research_consent_migration = true
account_privacy_artifacts = {
  "approval_reference" : "docs/SECUR4ALL-207-DEV-ACCEPTANCE.md",
  "promotion_approved" : false,
  "release_id" : "9147d545b719e54c1f967e35042bc502d79bc0f1",
  "workers" : {
    "publisher" : {
      "object_version" : "bEsE2kOpzYGC5hzgQ9cabbye5tflC_XX",
      "source_hash" : "VsfS81kkmG8J5fL7ENve5Ep9+woeL28lkXsMNlXe0JI="
    },
    "cluster" : {
      "object_version" : "CmQmZZ8PkzzwShgqzc.SFFLhQnPigIuV",
      "source_hash" : "4tfrCzvCKOqxXmhLAflwhU6ZGylAgWqBLX65WuuE4Lk="
    },
    "deletion" : {
      "object_version" : "dNXWt8e6k3dbv8hbqDE_hgrWLHqH.G2U",
      "source_hash" : "xpT6GPKfYVvC2Ha9f/6LGPjp+ETQQo+qBHxIkJjVZ4w="
    },
    "lifecycle" : {
      "object_version" : "XDBa3iCOCrEkndCM3PFe7w1HLLptQXuP",
      "source_hash" : "vGWg97T/vr5NpkwZVn+o2iXugAd1tJIhaVmnTUExO2I="
    }
  }
}

# Installed code and closed gates verified before restoring normal worker capacity.
reserved_concurrency = 2

# SECUR4ALL-207: recovery permissions retained; activation is explicitly pinned below.
campaign_recovery_preparation = {
  review_reference = "docs/CAMPAIGN-RECOVERY-PERMISSION-READINESS.md"
}

# SECUR4ALL-207: qualified completion integration; source and inventory pinned below.
campaign_completion_artifact = {
  "object_version" : "dNXWt8e6k3dbv8hbqDE_hgrWLHqH.G2U",
  "release_id" : "9147d545b719e54c1f967e35042bc502d79bc0f1",
  "review_reference" : "docs/SECUR4ALL-207-DEV-ACCEPTANCE.md",
  "source_hash" : "xpT6GPKfYVvC2Ha9f/6LGPjp+ETQQo+qBHxIkJjVZ4w="
}

# SECUR4ALL-207: scoped period admission compatibility; general research remains closed.
campaign_period_fence_preparation = {
  review_reference = "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md"
}

campaign_account_cleanup_preparation = {
  review_reference = "docs/LIVE-ACCOUNT-DELETION-ROLLOUT.md"
}

# Reviewed cleanup-only Dev qualification; all unrelated admission stays closed.
campaign_deletion_activation = {
  "completion_inventory_revision" : 1,
  "completion_manifest_sha256" : "ecb1ec4516f874c74711ad06b66f0d855cbf6a6990da0c8994f597f0ef9333e4",
  "encryption_reference" : "docs/evidence/live-account-deletion-2026-09-26/encrypted-table-read-probe.json",
  "generation" : "9f7311a2-34c9-4fe8-8fbf-56974ab32897",
  "inventory_reference" : "docs/evidence/live-account-deletion-2026-09-26/external-approval.json",
  "locator_inventory_revision" : 1,
  "locator_manifest_sha256" : "bde6307ac73e1a6f60533216270566b2db0c822aa1b777cbf1e1013a168eb73f",
  "recovery_inventory_revision" : 1,
  "recovery_manifest_sha256" : "ee96ccc2f89904ef6fb29058b8d76109618ec1b5823ff9ff390b27fa7b7b6936",
  "runtime_reference" : "docs/evidence/live-account-deletion-2026-09-26/all-component-runtime.json",
  "source_sha" : "9147d545b719e54c1f967e35042bc502d79bc0f1"
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
  "iam_reference" : "docs/evidence/sec207-period-iam-2026-09-27/qualification.json",
  "intelligence_table_id" : "4fe35db2-8130-4050-8547-3a1d2717fbde",
  "lifecycle_enabled" : true,
  "retirement_enabled" : true
}
