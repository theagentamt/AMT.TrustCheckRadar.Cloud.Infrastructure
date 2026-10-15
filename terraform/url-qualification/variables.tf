variable "aws_region" {
  type    = string
  default = "us-east-1"
  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Scoped URL qualification is restricted to the existing Dev region."
  }
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = var.environment == "dev"
    error_message = "This qualification store is Dev-only."
  }
}
variable "project_name" {
  type    = string
  default = "trustcheckradar"
  validation {
    condition     = var.project_name == "trustcheckradar"
    error_message = "Reuse the existing reviewed project namespace."
  }
}
variable "enabled" {
  description = "Provisioning selection only. Default false creates no resources; this is not runtime activation."
  type        = bool
  default     = false
  nullable    = false
}
variable "retention_approved" {
  description = "Requires a separately recorded owner decision; false until then. Never inferred from source approval."
  type        = bool
  default     = false
  nullable    = false
}
variable "retention_approval_reference" {
  type     = string
  default  = ""
  nullable = false
  validation {
    condition     = !var.retention_approved || length(trimspace(var.retention_approval_reference)) > 0
    error_message = "A recorded owner retention approval is required."
  }
}
variable "cleanup_enabled" {
  description = "Independent execution gate; stays false during local implementation. Requires future deployment/activation approval."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition     = !var.cleanup_enabled || (var.enabled && var.retention_approved && var.cleanup_artifact != null && var.alert_topic_arn != null)
    error_message = "Cleanup execution needs reviewed retention, immutable code and the existing alert destination."
  }
}
variable "cleanup_artifact" {
  type = object({
    bucket         = string
    key            = string
    object_version = string
    source_hash    = string
  })
  default = null
  validation {
    condition = var.cleanup_artifact == null ? true : (
      var.cleanup_artifact.bucket == "trustcheckradar-dev-107827791950-artifacts" &&
      can(regex("^releases/[0-9a-f]{40}/url_qualification_cleanup.zip$", var.cleanup_artifact.key)) &&
      length(trimspace(var.cleanup_artifact.object_version)) > 0 && var.cleanup_artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.cleanup_artifact.source_hash))
    )
    error_message = "Select only an immutable Dev cleanup package with an exact source/version/hash."
  }
}
variable "alert_topic_arn" {
  type    = string
  default = null
  validation {
    condition     = var.alert_topic_arn == null ? true : var.alert_topic_arn == "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
    error_message = "Reuse the confirmed existing support alert destination."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
