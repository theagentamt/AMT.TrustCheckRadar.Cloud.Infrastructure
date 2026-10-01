variable "profile_fence_transition_enabled" {
  description = "Temporary Dev-only rollout: prepare ledger configuration and condition-check permission while preserving legacy user permissions; disable after the pinned writer is verified."
  type        = bool
  default     = false
  validation {
    condition     = !var.profile_fence_transition_enabled || var.environment == "dev"
    error_message = "The temporary profile-fence rollout is allowed only in Dev."
  }
}

locals {
  profile_fence_configured           = var.profile_fence_deployment != null || var.profile_fence_transition_enabled
  profile_fence_permissions_enforced = var.profile_fence_deployment != null && !var.profile_fence_transition_enabled
}

variable "profile_fence_deployment" {
  description = "Pinned post-confirmation profile-fence release, coordinated with the API stack. Null preserves the existing package; permissions stay unchanged unless the explicit Dev transition is selected."
  type = object({
    release_id         = string
    object_version     = string
    source_hash        = string
    approval_reference = string
    promotion_approved = bool
  })
  default = null
  validation {
    condition = var.profile_fence_deployment == null ? true : try(
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.profile_fence_deployment.release_id)) &&
      length(trimspace(var.profile_fence_deployment.object_version)) > 0 && var.profile_fence_deployment.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.profile_fence_deployment.source_hash)) &&
      length(trimspace(var.profile_fence_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.profile_fence_deployment.promotion_approved) &&
      var.post_confirmation_log_policy != null, false
    )
    error_message = "Profile fencing requires version/hash pinning, explicit log policy, approval reference and separate UAT/Prod promotion approval."
  }
}

variable "post_confirmation_log_policy" {
  description = "Explicit operational-log retention approval. Import an existing log group before applying; null leaves existing retention untouched."
  type        = object({ retention_days = number, approval_reference = string })
  default     = null
  validation {
    condition = var.post_confirmation_log_policy == null ? true : (
      contains([7, 14, 30, 60, 90, 120, 180, 365, 400], var.post_confirmation_log_policy.retention_days) &&
      length(trimspace(var.post_confirmation_log_policy.approval_reference)) > 0
    )
    error_message = "Log retention needs an explicit supported finite period and approval reference."
  }
}

resource "aws_cloudwatch_log_group" "post_confirmation" {
  count             = var.post_confirmation_log_policy != null ? 1 : 0
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = var.post_confirmation_log_policy.retention_days
  tags              = local.common_tags
}

output "profile_fence_contract" {
  value = {
    environment                          = var.environment
    transition_enabled                   = var.profile_fence_transition_enabled
    transactional_user_permissions       = local.profile_fence_permissions_enforced
    post_confirmation_fenced             = var.profile_fence_deployment != null
    release_id                           = try(var.profile_fence_deployment.release_id, null)
    log_retention_days                   = try(var.post_confirmation_log_policy.retention_days, null)
    account_deletion_activation_approved = false
  }
}
