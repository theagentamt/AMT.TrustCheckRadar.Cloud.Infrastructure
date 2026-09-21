variable "account_privacy_artifacts" {
  description = "Coordinated immutable campaign privacy candidates. Every consumer remains disabled; selecting artifacts is not approval of cleanup coverage or activation."
  type = object({
    release_id         = string
    approval_reference = string
    promotion_approved = bool
    workers = map(object({
      object_version = string
      source_hash    = string
    }))
  })
  default = null
  validation {
    condition = var.account_privacy_artifacts == null ? true : try(
      var.campaign_processing_enabled && var.kill_switch_enabled &&
      var.publisher_fence_artifact == null && var.deletion_bridge_artifact == null &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.account_privacy_artifacts.release_id)) &&
      length(trimspace(var.account_privacy_artifacts.approval_reference)) > 0 &&
      (var.environment == "dev" || var.account_privacy_artifacts.promotion_approved) &&
      toset(keys(var.account_privacy_artifacts.workers)) == toset(["publisher", "cluster", "deletion", "lifecycle"]) &&
      alltrue([for artifact in values(var.account_privacy_artifacts.workers) :
        length(trimspace(artifact.object_version)) > 0 && artifact.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", artifact.source_hash))
      ]), false
    )
    error_message = "Campaign privacy candidates require all four version/hash pins, a review reference, disabled consumers, no conflicting artifact overrides and separate non-Dev promotion approval."
  }
}

locals {
  account_privacy_candidate = var.account_privacy_artifacts != null
  publisher_fenced          = var.publisher_fence_artifact != null || local.account_privacy_candidate
}
