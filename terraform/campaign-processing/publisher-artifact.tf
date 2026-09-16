variable "publisher_fence_artifact" {
  description = "Optional pinned publisher that ignores deletion locators and checks the fixed account-deletion fence. Null preserves the existing publisher."
  type = object({
    release_id         = string
    object_version     = string
    source_hash        = string
    approval_reference = string
    promotion_approved = bool
  })
  default = null
  validation {
    condition = var.publisher_fence_artifact == null ? true : try(
      var.campaign_processing_enabled &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.publisher_fence_artifact.release_id)) &&
      length(trimspace(var.publisher_fence_artifact.object_version)) > 0 && var.publisher_fence_artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.publisher_fence_artifact.source_hash)) &&
      length(trimspace(var.publisher_fence_artifact.approval_reference)) > 0 &&
      (var.environment == "dev" || var.publisher_fence_artifact.promotion_approved), false
    )
    error_message = "Publisher fencing requires provisioned workers, version/hash pinning, an approval reference and separate UAT/Prod promotion approval."
  }
}
