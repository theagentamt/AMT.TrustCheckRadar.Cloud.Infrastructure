variable "campaign_recovery_preparation" {
  description = "Reviewed Dev-only producer IAM preparation against the applied recovery index contract. Does not publish code, enable recovery writes, or activate deletion. Null preserves the existing producer configuration."
  type = object({
    review_reference = string
  })
  default = null
  validation {
    condition = var.campaign_recovery_preparation == null ? true : (
      var.environment == "dev" && length(trimspace(var.campaign_recovery_preparation.review_reference)) > 0
    )
    error_message = "Campaign recovery preparation requires a nonempty review reference and is limited to Dev."
  }
}

locals {
  campaign_recovery_preparation_selected = var.campaign_recovery_preparation != null
  campaign_recovery_storage              = try(local.foundation.campaign_recovery, null)
  # Last merge wins over caller-provided environment maps. This preparation has
  # no activation switch and does not select a producer artifact.
  campaign_recovery_producer_env = local.campaign_recovery_preparation_selected ? {
    CAMPAIGN_RECOVERY_WRITES_ENABLED = "false"
  } : {}

  campaign_recovery_preparation_valid = try(
    var.campaign_intelligence_enabled && var.account_data_deployment != null &&
    (var.campaign_participation_fence_deployment != null || local.research_migration_selected) &&
    local.foundation.schema_version == 1 &&
    local.campaign_recovery_storage.schema_version == 1 &&
    local.campaign_recovery_storage.enabled &&
    local.campaign_recovery_storage.environment == var.environment &&
    local.campaign_recovery_storage.table_name == "${local.name_prefix}-deletion-ledger" &&
    local.campaign_recovery_storage.table_name == local.deletion_ledger_table_name &&
    local.campaign_recovery_storage.table_arn == local.deletion_ledger_table_arn &&
    local.campaign_recovery_storage.table_arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.account_fence[0].account_id}:table/${local.name_prefix}-deletion-ledger" &&
    local.campaign_recovery_storage.index_name == "CampaignRecoveryDueIndex" &&
    local.campaign_recovery_storage.index_arn == "${local.campaign_recovery_storage.table_arn}/index/CampaignRecoveryDueIndex" &&
    local.campaign_recovery_storage.partition_key == "campaignRecoveryPartition" &&
    local.campaign_recovery_storage.sort_key == "nextAttemptAtEpoch" &&
    local.campaign_recovery_storage.projection == "KEYS_ONLY" &&
    local.campaign_recovery_storage.shard_count == 16 &&
    !local.campaign_recovery_storage.writes_enabled &&
    !local.campaign_recovery_storage.coverage_qualified,
    false
  )
}

resource "terraform_data" "campaign_recovery_preparation" {
  count = local.campaign_recovery_preparation_selected ? 1 : 0
  input = var.campaign_recovery_preparation.review_reference
  lifecycle {
    precondition {
      condition     = local.campaign_recovery_preparation_valid
      error_message = "Campaign recovery preparation requires both immutable producer selections and the enabled same-account/Region/environment foundation ledger index contract, with writes and coverage still disabled."
    }
  }
}

output "campaign_recovery_preparation_contract" {
  description = "Producer IAM preparation only. Existing account-data Put/Delete permits all ACCOUNT# sort keys and standalone operations; IAM cannot distinguish CAMPAIGN_RECOVERY from other account-owned rows or prove the authenticated account. Runtime predicates remain required."
  value = {
    schema_version                 = 1
    selected                       = local.campaign_recovery_preparation_selected
    environment                    = var.environment
    writes_enabled                 = false
    coverage_qualified             = false
    deletion_enabled               = false
    source_selected_by_preparation = false
  }
}
