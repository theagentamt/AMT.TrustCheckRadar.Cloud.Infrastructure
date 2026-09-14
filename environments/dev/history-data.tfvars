aws_region           = "us-east-1"
project_name         = "trustcheckradar"
environment          = "dev"
history_data_enabled = true
promotion_approved   = false

# Owner-approved Dev policy, 2026-09-14. This does not activate user ingestion.
storage_policy = {
  approved                    = true
  approval_reference          = "SECUR4ALL-185 Dev owner approval 2026-09-14"
  content_pitr_days           = 7
  control_pitr_days           = 7
  dedup_retention_seconds     = 10368000
  tombstone_retention_seconds = 10368000
}
monitoring = null
