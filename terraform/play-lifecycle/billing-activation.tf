variable "billing_activation" {
  description = "One-account owned-head Dev notifications, optionally with direct-head scheduled reconciliation. No global scan/checkpoint or token-deletion change."
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
      var.deployment != null && var.pubsub_identity != null && var.alert_topic_arn != null &&
      contains(["ingress", "background"], var.billing_activation.mode) &&
      can(regex("^[a-f0-9]{40}$", var.billing_activation.source_sha)) &&
      local.runtime_artifacts.ingress.key == "releases/${var.billing_activation.source_sha}/play_lifecycle_ingress.zip" &&
      (var.billing_activation.mode != "background" || local.runtime_artifacts.worker.key == "releases/${var.billing_activation.source_sha}/play_lifecycle_worker.zip") &&
      length(var.billing_activation.subjects) == 1 &&
      alltrue([for sub in var.billing_activation.subjects : can(regex("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", sub))]) &&
      alltrue([for ref in [var.billing_activation.inventory_reference, var.billing_activation.runtime_reference, var.billing_activation.permissions_reference] : length(trimspace(ref)) > 0]), false
    )
    error_message = "Ingress activation requires one exact Dev subject, immutable matching source, verified push identity, alerts and inventory/runtime/IAM evidence. Background mode also requires the exact matching scoped-worker source; global traversal remains closed."
  }
}
variable "billing_artifact_overrides" {
  description = "Reviewed ingress/worker packages independent of the existing deletion-only correction and cleanup activation."
  type = map(object({
    source_sha           = string
    provenance_reference = string
    artifact             = object({ bucket = string, key = string, object_version = string, source_hash = string })
  }))
  default = {}
  validation {
    condition = length(var.billing_artifact_overrides) == 0 ? true : try(
      var.enabled && var.environment == "dev" && var.deployment != null &&
      alltrue([for name, pin in var.billing_artifact_overrides :
        contains(["ingress", "worker"], name) &&
        can(regex("^[a-f0-9]{40}$", pin.source_sha)) &&
        pin.artifact.bucket == "trustcheckradar-dev-107827791950-artifacts" &&
        pin.artifact.key == "releases/${pin.source_sha}/${lookup({ ingress = "play_lifecycle_ingress", worker = "play_lifecycle_worker" }, name, "invalid")}.zip" &&
        length(trimspace(pin.artifact.object_version)) > 0 && pin.artifact.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", pin.artifact.source_hash)) &&
        length(trimspace(pin.provenance_reference)) > 0
      ]), false
    )
    error_message = "Only immutable reviewed Dev ingress/worker packages may be overridden; deletion baseline and correction are independent."
  }
}
locals {
  billing_ingress_active = var.billing_activation != null
  billing_worker_active  = var.billing_activation == null ? false : var.billing_activation.mode == "background"
  billing_worker_scoped  = local.billing_worker_active || contains(keys(var.billing_artifact_overrides), "worker")
}
