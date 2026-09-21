variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.project_name))
    error_message = "Use a 3-30 character lowercase project prefix."
  }
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Use dev, uat or prod."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enabled" {
  description = "Create the standalone resolver and its isolated network. Does not integrate the analyzer."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition     = !var.enabled || var.artifact != null
    error_message = "Enabling the resolver requires a version-pinned artifact."
  }
}

variable "artifact" {
  description = "Immutable published ZIP; populated after packaging, not by this stack."
  type = object({
    bucket         = string
    key            = string
    object_version = string
    source_hash    = string
  })
  default = null
  validation {
    condition = var.artifact == null ? true : try(
      length(trimspace(var.artifact.bucket)) > 0 &&
      can(regex("^releases/[^/]+/url_redirect_resolver.zip$", var.artifact.key)) &&
      length(trimspace(var.artifact.object_version)) > 0 && var.artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.artifact.source_hash)), false
    )
    error_message = "Supply the resolver release key, non-null S3 version and base64 SHA256."
  }
}

variable "caller_role_names" {
  description = "Existing same-account IAM roles allowed to invoke the resolver alias. Empty creates no caller grants."
  type        = set(string)
  default     = []
  nullable    = false
  validation {
    condition     = alltrue([for role in var.caller_role_names : can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", role))])
    error_message = "Supply exact IAM role names without wildcards or ARNs."
  }
}

variable "reserved_concurrency" {
  type     = number
  default  = 5
  nullable = false
  validation {
    condition     = var.reserved_concurrency >= 0 && var.reserved_concurrency <= 10 && floor(var.reserved_concurrency) == var.reserved_concurrency
    error_message = "Use an integer from zero (paused) to ten."
  }
}

variable "alarm_action_arns" {
  description = "Additional notification destinations beyond the dedicated resolver SNS topic."
  type        = list(string)
  default     = []
}

variable "notification_email" {
  description = "Optional owner-selected email for resolver alerts. SNS confirmation is required before delivery."
  type        = string
  default     = null
  validation {
    condition     = var.notification_email == null ? true : can(regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", var.notification_email))
    error_message = "Supply a valid notification email address, or null."
  }
}

variable "dev_test_principal_arn" {
  description = "Exact existing IAM role allowed to assume a resolver-only Dev smoke role. Never an account root, user, wildcard or STS session ARN."
  type        = string
  default     = null
  validation {
    condition = var.dev_test_principal_arn == null ? true : (
      var.environment == "dev" && can(regex("^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", var.dev_test_principal_arn))
    )
    error_message = "The optional smoke principal must be an exact IAM role ARN and is allowed only in Dev."
  }
}

variable "assessment_alarm_notifications_enabled" {
  description = "Allow only the three named private Dev URL-assessment alarms to use the confirmed resolver topic."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition     = !var.assessment_alarm_notifications_enabled || var.environment == "dev"
    error_message = "Private assessment alarm integration is Dev-only."
  }
}

variable "consumer_alarm_notifications_enabled" {
  description = "Permit only named Dev V1 consumer, entitlement and cleanup alarms on the existing support topic."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition     = !var.consumer_alarm_notifications_enabled || var.environment == "dev"
    error_message = "Consumer alarm integration is Dev-only."
  }
}
