variable "profile_fence_deployment" {
  description = "Pinned age-attestation profile-fence release, coordinated with identity-workflows. Null preserves the existing package and permissions."
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
      (var.environment == "dev" || var.profile_fence_deployment.promotion_approved), false
    )
    error_message = "Profile fencing needs a version/hash-pinned approved release and separate UAT/Prod promotion approval."
  }
}

output "profile_fence_contract" {
  value = {
    environment                          = var.environment
    age_attestation_fenced               = var.profile_fence_deployment != null
    release_id                           = try(var.profile_fence_deployment.release_id, null)
    account_deletion_activation_approved = false
  }
}
