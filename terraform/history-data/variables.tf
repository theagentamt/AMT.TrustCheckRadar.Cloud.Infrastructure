variable "aws_region" {
  description = "AWS region for this environment"
  type        = string
}

variable "project_name" {
  description = "Project/application prefix"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.project_name))
    error_message = "project_name must be 3-30 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Isolated deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be dev, uat, or prod."
  }
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "history_data_enabled" {
  description = "Provision History data only after explicit storage-policy approval; this does not activate APIs"
  type        = bool
  default     = false
  nullable    = false

  # Unlike a check block, invalid variable validation blocks plan/apply.
  validation {
    condition     = !var.history_data_enabled || try(var.storage_policy.approved && length(trimspace(var.storage_policy.approval_reference)) > 0, false)
    error_message = "History storage requires an explicitly approved storage_policy with an approval_reference."
  }

  validation {
    condition     = !var.history_data_enabled || var.environment == "dev" || var.promotion_approved
    error_message = "Enabling UAT or Production History storage requires separate promotion_approved=true."
  }
}

variable "promotion_approved" {
  description = "Separate reviewed authorization for UAT or Production provisioning"
  type        = bool
  default     = false
  nullable    = false
}

variable "storage_policy" {
  description = "Unresolved policy has no defaults. PITR days: 0 explicitly disables, 1-35 enables. Metadata lifetimes apply only to their record classes, not badge progress."
  type = object({
    approved                    = bool
    approval_reference          = string
    content_pitr_days           = number
    control_pitr_days           = number
    dedup_retention_seconds     = number
    tombstone_retention_seconds = number
  })
  default = null

  validation {
    condition = var.storage_policy == null ? true : try(alltrue([
      for days in [var.storage_policy.content_pitr_days, var.storage_policy.control_pitr_days] :
      days >= 0 && days <= 35 && floor(days) == days
    ]), false)
    error_message = "Explicit content/control PITR windows must be integer days between 0 and 35; zero means no PITR."
  }

  validation {
    condition = var.storage_policy == null ? true : try(alltrue([
      for seconds in [var.storage_policy.dedup_retention_seconds, var.storage_policy.tombstone_retention_seconds] :
      seconds > 0 && floor(seconds) == seconds
    ]), false)
    error_message = "Deduplication and tombstone retention must be explicitly approved positive integer seconds."
  }
}

variable "max_read_request_units" {
  description = "Per-table and per-index on-demand read cap; conservative implementation ceiling, not an account entitlement"
  type        = number
  default     = 25
  nullable    = false

  validation {
    condition     = var.max_read_request_units >= 1 && var.max_read_request_units <= 100 && floor(var.max_read_request_units) == var.max_read_request_units
    error_message = "Read caps must be whole numbers from 1 to 100."
  }
}

variable "max_write_request_units" {
  description = "Per-table and per-index on-demand write cap"
  type        = number
  default     = 10
  nullable    = false

  validation {
    condition     = var.max_write_request_units >= 1 && var.max_write_request_units <= 50 && floor(var.max_write_request_units) == var.max_write_request_units
    error_message = "Write caps must be whole numbers from 1 to 50."
  }
}

variable "monitoring" {
  description = "Opt-in storage alarms/dashboard using an existing same-region SNS topic. Null creates no monitoring resources; this is not the lifecycle readiness gate."
  type = object({
    alarm_topic_arn = string
  })
  default = null

  validation {
    condition     = var.monitoring == null || var.history_data_enabled
    error_message = "History monitoring requires History data to be enabled."
  }

  validation {
    condition = var.monitoring == null ? true : can(regex(
      "^arn:aws:sns:${var.aws_region}:[0-9]{12}:[A-Za-z0-9_-]+$",
      var.monitoring.alarm_topic_arn,
    ))
    error_message = "Monitoring requires an explicit existing standard SNS topic ARN in this environment's AWS region."
  }
}
