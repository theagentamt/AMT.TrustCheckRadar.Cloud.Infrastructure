variable "campaign_deletion_activation" {
  description = "Reviewed Dev deletion-only worker activation. Does not enable research production, aggregation or whole-period lifecycle. Manifest references attest review; runtime independently verifies stored inventory."
  type = object({
    source_sha                    = string
    generation                    = string
    locator_manifest_sha256       = string
    locator_inventory_revision    = number
    recovery_manifest_sha256      = string
    recovery_inventory_revision   = number
    completion_manifest_sha256    = string
    completion_inventory_revision = number
    inventory_reference           = string
    runtime_reference             = string
    encryption_reference          = string
  })
  default = null
  validation {
    condition = var.campaign_deletion_activation == null ? true : try(
      var.environment == "dev" && var.kill_switch_enabled && local.enabled &&
      local.period_fence_prepared && local.recovery_prepared && local.completion_prepared &&
      var.campaign_account_cleanup_preparation != null &&
      can(regex("^[0-9a-f]{40}$", var.campaign_deletion_activation.source_sha)) &&
      var.campaign_deletion_activation.source_sha == var.account_privacy_artifacts.release_id &&
      var.campaign_deletion_activation.source_sha == var.campaign_completion_artifact.release_id &&
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.campaign_deletion_activation.generation)) &&
      alltrue([for digest in [var.campaign_deletion_activation.locator_manifest_sha256, var.campaign_deletion_activation.recovery_manifest_sha256, var.campaign_deletion_activation.completion_manifest_sha256] : can(regex("^[0-9a-f]{64}$", digest))]) &&
      alltrue([for revision in [var.campaign_deletion_activation.locator_inventory_revision, var.campaign_deletion_activation.recovery_inventory_revision, var.campaign_deletion_activation.completion_inventory_revision] : revision >= 1 && revision <= 9007199254740991 && floor(revision) == revision]) &&
      alltrue([for ref in [var.campaign_deletion_activation.inventory_reference, var.campaign_deletion_activation.runtime_reference, var.campaign_deletion_activation.encryption_reference] : length(trimspace(ref)) > 0]),
      false
    )
    error_message = "Deletion-only activation requires exact reviewed Dev artifacts, all cleanup preparations, closed research, a UUIDv4 generation, three valid inventory pins and inventory/runtime/encryption evidence."
  }
}
locals {
  campaign_deletion_active = var.campaign_deletion_activation != null
  campaign_deletion_activation_env = local.campaign_deletion_active ? {
    CAMPAIGN_DELETION_STREAM_ENABLED       = "true"
    CAMPAIGN_COMPLETION_ENABLED            = "true"
    CAMPAIGN_RECOVERY_ENABLED              = "true"
    CAMPAIGN_PERIOD_ADMISSION_ENABLED      = "true"
    CAMPAIGN_PERIOD_ADMISSION_GENERATION   = var.campaign_deletion_activation.generation
    CAMPAIGN_LOCATOR_MANIFEST_SHA256       = var.campaign_deletion_activation.locator_manifest_sha256
    CAMPAIGN_LOCATOR_INVENTORY_REVISION    = tostring(var.campaign_deletion_activation.locator_inventory_revision)
    CAMPAIGN_RECOVERY_MANIFEST_SHA256      = var.campaign_deletion_activation.recovery_manifest_sha256
    CAMPAIGN_RECOVERY_INVENTORY_REVISION   = tostring(var.campaign_deletion_activation.recovery_inventory_revision)
    CAMPAIGN_COMPLETION_MANIFEST_SHA256    = var.campaign_deletion_activation.completion_manifest_sha256
    CAMPAIGN_COMPLETION_INVENTORY_REVISION = tostring(var.campaign_deletion_activation.completion_inventory_revision)
  } : {}
}
output "campaign_deletion_activation_contract" {
  value = {
    configured                    = local.campaign_deletion_active
    research_producers_paused     = !local.active
    lifecycle_paused              = !local.active
    runtime_attested_by_terraform = false
    generation                    = try(var.campaign_deletion_activation.generation, null)
    source_sha                    = try(var.campaign_deletion_activation.source_sha, null)
  }
}
