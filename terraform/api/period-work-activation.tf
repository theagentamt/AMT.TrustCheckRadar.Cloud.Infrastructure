variable "campaign_period_work_activation" {
  description = "Reviewed Dev resource-bound work-index compatibility. References record external qualification; Terraform never approves inventory or proves erasure. General research remains paused."
  type = object({
    source_sha                 = string
    generation                 = string
    manifest_sha256            = string
    inventory_revision         = number
    locator_manifest_sha256    = string
    locator_inventory_revision = number
    pipeline_table_id          = string
    outbox_table_id            = string
    inventory_reference        = string
    runtime_reference          = string
    iam_reference              = string
  })
  default = null
  validation {
    condition = var.campaign_period_work_activation == null ? true : try(
      var.environment == "dev" && local.period_work_prepared &&
      var.campaign_period_work_activation.source_sha == var.account_data_deployment.release_id &&
      var.campaign_period_work_activation.source_sha == var.account_export_deployment.release_id &&
      !var.research_consent_migration_deployment.consent_enabled &&
      can(regex("^[0-9a-f]{40}$", var.campaign_period_work_activation.source_sha)) &&
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.campaign_period_work_activation.generation)) &&
      alltrue([for digest in [var.campaign_period_work_activation.manifest_sha256, var.campaign_period_work_activation.locator_manifest_sha256] : can(regex("^[0-9a-f]{64}$", digest))]) &&
      alltrue([for revision in [var.campaign_period_work_activation.inventory_revision, var.campaign_period_work_activation.locator_inventory_revision] : revision >= 1 && revision <= 9007199254740991 && floor(revision) == revision]) &&
      alltrue([for id in [var.campaign_period_work_activation.pipeline_table_id, var.campaign_period_work_activation.outbox_table_id] : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))]) &&
      var.campaign_period_work_activation.pipeline_table_id != var.campaign_period_work_activation.outbox_table_id &&
      alltrue([for ref in [var.campaign_period_work_activation.inventory_reference, var.campaign_period_work_activation.runtime_reference, var.campaign_period_work_activation.iam_reference] : length(trimspace(ref)) > 0]),
      false
    )
    error_message = "Period-work activation requires exact reviewed Dev source, generation, locator/work inventories, distinct table identities and inventory/runtime/IAM evidence; research remains paused."
  }
}
locals {
  period_work_active = var.campaign_period_work_activation != null && !var.campaign_period_work_quiescence
  period_work_activation_env = local.period_work_active ? {
    CAMPAIGN_PERIOD_WORK_ENABLED            = "true"
    CAMPAIGN_PERIOD_WORK_MANIFEST_SHA256    = var.campaign_period_work_activation.manifest_sha256
    CAMPAIGN_PERIOD_WORK_INVENTORY_REVISION = tostring(var.campaign_period_work_activation.inventory_revision)
    CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_ID  = var.campaign_period_work_activation.pipeline_table_id
    CAMPAIGN_PERIOD_WORK_OUTBOX_TABLE_ID    = var.campaign_period_work_activation.outbox_table_id
    CAMPAIGN_PERIOD_ADMISSION_ENABLED       = "true"
    CAMPAIGN_PERIOD_ADMISSION_GENERATION    = var.campaign_period_work_activation.generation
    CAMPAIGN_LOCATOR_MANIFEST_SHA256        = var.campaign_period_work_activation.locator_manifest_sha256
    CAMPAIGN_LOCATOR_INVENTORY_REVISION     = tostring(var.campaign_period_work_activation.locator_inventory_revision)
  } : {}
}
output "campaign_period_work_activation_contract" {
  value = {
    configured                    = local.period_work_active
    runtime_attested_by_terraform = false
    research_admission_enabled    = false
    source_sha                    = try(var.campaign_period_work_activation.source_sha, null)
    generation                    = try(var.campaign_period_work_activation.generation, null)
  }
}
