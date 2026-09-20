variable "aws_region" { type = string }
variable "project_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.project_name))
    error_message = "Use a lowercase project prefix."
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
  type     = bool
  default  = false
  nullable = false
  validation {
    condition     = !var.enabled || (var.environment == "dev" && var.artifact != null && var.secret_arn != null && var.resolver_alias_arn != null)
    error_message = "This operator-only integration may be enabled only in Dev with pinned code and exact dependency ARNs."
  }
}
variable "artifact" {
  type    = object({ bucket = string, key = string, object_version = string, source_hash = string })
  default = null
  validation {
    condition = var.artifact == null ? true : try(
      can(regex("^releases/[^/]+/url_assessment.zip$", var.artifact.key)) &&
      length(trimspace(var.artifact.bucket)) > 0 &&
      length(trimspace(var.artifact.object_version)) > 0 && var.artifact.object_version != "null" &&
    can(regex("^[A-Za-z0-9+/]{43}=$", var.artifact.source_hash)), false)
    error_message = "Supply the immutable url_assessment.zip release key, S3 version and SHA256."
  }
}
variable "secret_arn" {
  type        = string
  default     = null
  description = "Existing Web Risk secret ARN. Values are never read by Terraform."
  validation {
    condition     = var.secret_arn == null ? true : can(regex("^arn:aws:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$", var.secret_arn))
    error_message = "Supply one exact Secrets Manager ARN, without wildcard."
  }
}
variable "resolver_alias_arn" {
  type    = string
  default = null
  validation {
    condition     = var.resolver_alias_arn == null ? true : can(regex("^arn:aws:lambda:[a-z0-9-]+:[0-9]{12}:function:[A-Za-z0-9_-]+:live$", var.resolver_alias_arn))
    error_message = "Supply one exact resolver live alias ARN."
  }
}
variable "reserved_concurrency" {
  type     = number
  default  = 2
  nullable = false
  validation {
    condition     = var.reserved_concurrency >= 0 && var.reserved_concurrency <= 2 && floor(var.reserved_concurrency) == var.reserved_concurrency
    error_message = "Use zero (paused), one or two concurrent operator checks."
  }
}
variable "dev_test_principal_arn" {
  type        = string
  default     = null
  description = "Exact existing same-account role trusted by the alias-only Dev test role."
  validation {
    condition     = var.dev_test_principal_arn == null ? true : can(regex("^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", var.dev_test_principal_arn))
    error_message = "Supply an exact existing role ARN, not account root or session ARN."
  }
}

variable "alert_topic_arn" {
  description = "Existing confirmed resolver alert topic. No new subscription or recipient is created."
  type        = string
  default     = null
  validation {
    condition     = !var.enabled || var.alert_topic_arn != null
    error_message = "Enabled operator service requires the confirmed alert destination."
  }
}
