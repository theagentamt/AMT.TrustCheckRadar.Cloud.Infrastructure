variable "history_deployment" {
  description = "Version-pinned History release. Null leaves existing analysis untouched and creates no History API resources."
  type = object({
    release_id         = string
    approval_reference = string
    promotion_approved = bool
    artifacts = map(object({
      object_version = string
      source_hash    = string
    }))
  })
  default = null

  validation {
    condition = var.history_deployment == null ? true : try(
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.history_deployment.release_id)) &&
      length(trimspace(var.history_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.history_deployment.promotion_approved) &&
      toset(keys(var.history_deployment.artifacts)) == toset(["read", "mutation", "analysis"]) &&
      alltrue([for artifact in var.history_deployment.artifacts :
        length(trimspace(artifact.object_version)) > 0 && artifact.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", artifact.source_hash))
      ]), false
    )
    error_message = "History needs an approved immutable release with exact read/mutation/analysis S3 versions and hashes; UAT/Prod require promotion approval."
  }
}

variable "history_features" {
  description = "Independent activation controls. Never disable durable replay or lifecycle after accepting data without a reviewed retention-aware retirement."
  type = object({
    reads          = bool
    writes         = bool
    mutations      = bool
    recognition    = bool
    durable_replay = bool
  })
  default = {
    reads = false, writes = false, mutations = false, recognition = false, durable_replay = false
  }
  nullable = false

  validation {
    condition = (
      !anytrue(values(var.history_features)) || var.history_deployment != null
      ) && (!var.history_features.writes || var.history_features.durable_replay) && (
      !var.history_features.recognition || var.history_features.reads
    )
    error_message = "History activation needs deployed artifacts; writes require durable replay and recognition requires reads."
  }
}
