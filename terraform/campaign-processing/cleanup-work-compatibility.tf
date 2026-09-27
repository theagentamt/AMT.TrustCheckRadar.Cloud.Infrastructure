variable "campaign_cleanup_work_compatibility" {
  description = "Reviewed Dev bridge-only patch against unchanged period-work producers and inventory. This does not approve new inventory or relax runtime resource binding."
  type = object({
    work_source_sha    = string
    cleanup_source_sha = string
    review_reference   = string
  })
  default = null
  validation {
    condition = var.campaign_cleanup_work_compatibility == null ? true : try(
      var.environment == "dev" && local.completion_prepared &&
      var.campaign_cleanup_work_compatibility.work_source_sha != var.campaign_cleanup_work_compatibility.cleanup_source_sha &&
      var.campaign_cleanup_work_compatibility.work_source_sha == var.account_privacy_artifacts.release_id &&
      var.campaign_cleanup_work_compatibility.cleanup_source_sha == var.campaign_completion_artifact.release_id &&
      alltrue([for sha in [var.campaign_cleanup_work_compatibility.work_source_sha, var.campaign_cleanup_work_compatibility.cleanup_source_sha] : can(regex("^[0-9a-f]{40}$", sha))]) &&
      length(trimspace(var.campaign_cleanup_work_compatibility.review_reference)) > 0, false
    )
    error_message = "Cleanup compatibility requires prepared Dev completion and exact reviewed producer/bridge source pairs; stale overrides are rejected."
  }
}
