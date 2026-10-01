variable "campaign_recovery_index_enabled" {
  description = "Prepare a sparse, keys-only due-work index on the existing deletion ledger. Does not enable recovery producers, workers or deletion."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition     = !var.campaign_recovery_index_enabled || var.campaign_intelligence_enabled
    error_message = "Campaign recovery indexing requires the campaign ledger contract."
  }
}

locals {
  campaign_recovery_index_name = "CampaignRecoveryDueIndex"
  campaign_recovery_contract = {
    schema_version     = 1
    enabled            = var.campaign_recovery_index_enabled
    environment        = var.environment
    table_name         = aws_dynamodb_table.deletion_ledger.name
    table_arn          = aws_dynamodb_table.deletion_ledger.arn
    index_name         = var.campaign_recovery_index_enabled ? local.campaign_recovery_index_name : null
    index_arn          = var.campaign_recovery_index_enabled ? "${aws_dynamodb_table.deletion_ledger.arn}/index/${local.campaign_recovery_index_name}" : null
    partition_key      = "campaignRecoveryPartition"
    sort_key           = "nextAttemptAtEpoch"
    projection         = "KEYS_ONLY"
    shard_count        = 16
    writes_enabled     = false
    coverage_qualified = false
  }
}

output "campaign_recovery_contract" {
  value       = local.campaign_recovery_contract
  description = "Prepared sparse index only; producer coverage, backfill and activation remain separate."
}
