variable "campaign_review_expiry_deployment" {
  description = "Independently pinned aggregate-expiry-compatible Dev review worker; does not change public campaign API artifact or access."
  type = object({
    source_sha       = string
    object_version   = string
    source_hash      = string
    review_reference = string
  })
  default = null
  validation {
    condition = var.campaign_review_expiry_deployment == null ? true : (
      var.environment == "dev" && var.campaign_review_api_enabled &&
      can(regex("^[0-9a-f]{40}$", var.campaign_review_expiry_deployment.source_sha)) &&
      length(trimspace(var.campaign_review_expiry_deployment.object_version)) > 0 &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.campaign_review_expiry_deployment.source_hash)) &&
      length(trimspace(var.campaign_review_expiry_deployment.review_reference)) > 0
    )
    error_message = "Aggregate review selection requires an exact Dev source, immutable object version/hash and review reference."
  }
}
variable "campaign_review_reserved_concurrency" {
  description = "Bounded review capacity; zero is reserved for the reviewed closed migration window."
  type        = number
  default     = 1
  validation {
    condition     = contains([0, 1], var.campaign_review_reserved_concurrency)
    error_message = "Review concurrency must be zero for migration or one for normal operation."
  }
}
