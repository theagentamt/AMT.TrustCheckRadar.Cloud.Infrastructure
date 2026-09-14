variable "aws_region" {
  type        = string
  description = "Environment AWS region"
}

variable "project_name" {
  type        = string
  description = "Project prefix"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.project_name))
    error_message = "Use a 3-30 character lowercase project prefix."
  }
}

variable "environment" {
  type        = string
  description = "Environment name"
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be dev, uat or prod."
  }
}

variable "state_bucket_name" {
  type        = string
  description = "Remote state bucket"
}

variable "state_bucket_region" {
  type        = string
  description = "Remote state bucket region"
}

variable "state_key_prefix" {
  type        = string
  description = "Remote state prefix"
  default     = "trustcheckradar"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "lifecycle_deployment_enabled" {
  type        = bool
  description = "Provision lifecycle compute and IAM; not the scheduled activation switch"
  default     = false
  nullable    = false
  validation {
    condition     = !var.lifecycle_deployment_enabled || var.artifact != null
    error_message = "Lifecycle deployment requires an uploaded immutable artifact with object version and source hash."
  }
  validation {
    condition     = !var.lifecycle_deployment_enabled || var.environment == "dev" || var.promotion_approved
    error_message = "UAT/Prod lifecycle provisioning requires separate promotion approval."
  }
}

variable "promotion_approved" {
  type     = bool
  default  = false
  nullable = false
}

variable "artifact" {
  description = "Verified uploaded release only, never local ZIP checksums presented as deployment readiness"
  type = object({
    release_id     = string
    object_version = string
    source_hash    = string
  })
  default = null
  validation {
    condition = var.artifact == null ? true : try(
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.artifact.release_id)) &&
      length(trimspace(var.artifact.object_version)) > 0 && var.artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.artifact.source_hash)),
      false,
    )
    error_message = "Supply an immutable release id, non-null S3 version and base64 SHA-256 source hash."
  }
}

variable "lifecycle_active" {
  type        = bool
  description = "Activate the five-minute sweep only after runtime/erasure acceptance; must remain active while retained data needs cleanup"
  default     = false
  nullable    = false
  validation {
    condition = !var.lifecycle_active || try(
      var.lifecycle_deployment_enabled && var.runtime_policy.acceptance_approved &&
      length(trimspace(var.runtime_policy.approval_reference)) > 0 && var.alarm_topic_arn != null,
      false,
    )
    error_message = "Schedule activation requires deployment, reviewed runtime/erasure acceptance and an explicit alarm destination."
  }
}

variable "runtime_policy" {
  description = "No numeric policy defaults. Receipt retention and checkpoint bootstrap require explicit approval."
  type = object({
    acceptance_approved             = bool
    approval_reference              = string
    mutation_retention_days         = number
    start_epoch_hour                = number
    max_items_per_sweep             = number
    max_bucket_queries_per_sweep    = number
    expiration_reconciliation_hours = number
    erasure_batch_size              = number
    completion_stuck_seconds        = number
    completion_recheck_seconds      = number
  })
  default = null
  validation {
    condition = var.runtime_policy == null ? true : try(
      alltrue([for value in [
        var.runtime_policy.mutation_retention_days,
        var.runtime_policy.max_items_per_sweep,
        var.runtime_policy.max_bucket_queries_per_sweep,
        var.runtime_policy.erasure_batch_size,
        var.runtime_policy.completion_stuck_seconds,
        var.runtime_policy.completion_recheck_seconds,
        var.runtime_policy.expiration_reconciliation_hours,
      ] : value > 0 && floor(value) == value]) &&
      var.runtime_policy.start_epoch_hour >= 0 && var.runtime_policy.start_epoch_hour % 3600 == 0 &&
      var.runtime_policy.max_items_per_sweep >= 3 && var.runtime_policy.max_items_per_sweep <= 1000 &&
      var.runtime_policy.max_bucket_queries_per_sweep >= 40 && var.runtime_policy.max_bucket_queries_per_sweep <= 1000 &&
      var.runtime_policy.expiration_reconciliation_hours <= 168 &&
      var.runtime_policy.erasure_batch_size <= 25,
      false,
    )
    error_message = "Runtime values must be positive integers within Lambda bounds; checkpoint bootstrap is hour-aligned Unix seconds."
  }
}

variable "alarm_topic_arn" {
  type        = string
  description = "Existing same-region SNS topic with verified delivery; required for active sweeps"
  default     = null
  validation {
    condition     = var.alarm_topic_arn == null ? true : can(regex("^arn:aws:sns:${var.aws_region}:[0-9]{12}:[A-Za-z0-9_-]+$", var.alarm_topic_arn))
    error_message = "Use a same-region standard SNS topic ARN."
  }
}
