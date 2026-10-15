variable "billing_activation" {
  description = "Separately reviewed one-account Dev preparation or test-purchase verification. Null keeps billing closed."
  type = object({
    mode                  = string
    source_sha            = string
    subjects              = set(string)
    inventory_reference   = string
    runtime_reference     = string
    permissions_reference = string
  })
  default = null
  validation {
    condition = var.billing_activation == null ? true : try(
      var.enabled && var.environment == "dev" && var.project_name == "trustcheckradar" && var.aws_region == "us-east-1" &&
      var.deployment != null && var.lifecycle_storage != null && var.api_gateway != null && var.alert_topic_arn != null &&
      contains(["preparation", "verification"], var.billing_activation.mode) &&
      (var.billing_activation.mode != "verification" || var.catalog_p1m_verified) &&
      can(regex("^[a-f0-9]{40}$", var.billing_activation.source_sha)) &&
      local.runtime_artifact.key == "releases/${var.billing_activation.source_sha}/v1_play_handoff.zip" &&
      length(var.billing_activation.subjects) == 1 &&
      alltrue([for sub in var.billing_activation.subjects : can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", sub))]) &&
      alltrue([for ref in [var.billing_activation.inventory_reference, var.billing_activation.runtime_reference, var.billing_activation.permissions_reference] : length(trimspace(ref)) > 0]), false
    )
    error_message = "Billing activation requires one exact Dev subject, matching immutable source, existing authenticated routes/storage/alerts and inventory/runtime/IAM evidence; verification also requires a verified monthly catalog."
  }
}
locals {
  billing_preparation_active  = var.billing_activation != null
  billing_verification_active = var.billing_activation == null ? false : var.billing_activation.mode == "verification"
}
variable "billing_artifact_override" {
  description = "Immutable reviewed billing runtime independent of its retained deployment baseline. Does not activate billing."
  type = object({
    source_sha           = string
    provenance_reference = string
    artifact             = object({ bucket = string, key = string, object_version = string, source_hash = string })
  })
  default = null
  validation {
    condition = var.billing_artifact_override == null ? true : try(
      var.enabled && var.environment == "dev" && var.deployment != null &&
      can(regex("^[a-f0-9]{40}$", var.billing_artifact_override.source_sha)) &&
      var.billing_artifact_override.artifact.bucket == "trustcheckradar-dev-107827791950-artifacts" &&
      var.billing_artifact_override.artifact.key == "releases/${var.billing_artifact_override.source_sha}/v1_play_handoff.zip" &&
      length(trimspace(var.billing_artifact_override.artifact.object_version)) > 0 && var.billing_artifact_override.artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.billing_artifact_override.artifact.source_hash)) &&
      length(trimspace(var.billing_artifact_override.provenance_reference)) > 0, false
    )
    error_message = "Only an immutable reviewed Dev handoff package with exact source/provenance may override the retained baseline."
  }
}
locals {
  runtime_artifact = var.billing_artifact_override == null ? try(var.deployment.artifact, null) : var.billing_artifact_override.artifact
}
