variable "deletion_activation" {
  description = "Reviewed cleanup-only Dev token deletion for exact subjects, independent of provider/lifecycle/checkpoint activation."
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
      var.environment == "dev" && var.enabled && var.deployment != null && var.alert_topic_arn != null &&
      can(regex("^[0-9a-f]{40}$", var.deletion_activation.source_sha)) &&
      var.deployment.artifacts.deletion.key == "releases/${var.deletion_activation.source_sha}/play_token_deletion.zip" &&
      length(var.deletion_activation.subjects) > 0 && length(var.deletion_activation.subjects) <= 10 &&
      alltrue([for sub in var.deletion_activation.subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", sub))]) &&
      alltrue([for ref in [var.deletion_activation.inventory_reference, var.deletion_activation.runtime_reference, var.deletion_activation.permissions_reference] : length(trimspace(ref)) > 0]), false
    )
    error_message = "Token cleanup activation requires exact deployed Dev source, explicit subjects, alerting and inventory/runtime/IAM evidence."
  }
}
locals {
  token_deletion_active = var.deletion_activation != null
}
