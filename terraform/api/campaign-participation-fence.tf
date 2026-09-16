variable "campaign_participation_fence_deployment" {
  description = "Optional immutable participation writer with authoritative profile/deletion checks. Select only in a coordinated account-data rollout."
  type = object({
    release_id         = string
    object_version     = string
    source_hash        = string
    approval_reference = string
    promotion_approved = bool
  })
  default = null
  validation {
    condition = var.campaign_participation_fence_deployment == null ? true : try(
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.campaign_participation_fence_deployment.release_id)) &&
      length(trimspace(var.campaign_participation_fence_deployment.object_version)) > 0 && var.campaign_participation_fence_deployment.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.campaign_participation_fence_deployment.source_hash)) &&
      length(trimspace(var.campaign_participation_fence_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.campaign_participation_fence_deployment.promotion_approved), false
    )
    error_message = "Participation fencing requires an approved version/hash-pinned release and separate UAT/Prod promotion approval."
  }
}
