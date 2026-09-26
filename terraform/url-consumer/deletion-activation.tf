variable "deletion_activation" {
  description = "Independent reviewed Dev authority deletion for explicit subjects; does not activate access, leases or providers."
  type = object({
    source_sha            = string
    subjects              = set(string)
    inventory_reference   = string
    runtime_reference     = string
    permissions_reference = string
  })
  default = null
  validation {
    condition = var.deletion_activation == null ? true : try(
      var.environment == "dev" && local.deletion_provisioned &&
      !local.authority_engineering_active && var.alert_topic_arn != null &&
      can(regex("^[0-9a-f]{40}$", var.deletion_activation.source_sha)) &&
      var.deployment.artifacts.deletion.key == "releases/${var.deletion_activation.source_sha}/v1_authority_deletion.zip" &&
      length(var.deletion_activation.subjects) > 0 && length(var.deletion_activation.subjects) <= 10 &&
      alltrue([for sub in var.deletion_activation.subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", sub))]) &&
      alltrue([for ref in [var.deletion_activation.inventory_reference, var.deletion_activation.runtime_reference, var.deletion_activation.permissions_reference] : length(trimspace(ref)) > 0]), false
    )
    error_message = "Deletion-only activation requires the exact deployed Dev source, explicit subjects, alerting and inventory/runtime/IAM evidence while access engineering remains disabled."
  }
}
locals {
  authority_deletion_active   = local.authority_engineering_active || var.deletion_activation != null
  authority_deletion_subjects = var.deletion_activation == null ? var.engineering_subjects : var.deletion_activation.subjects
}
