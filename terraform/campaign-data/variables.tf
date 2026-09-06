variable "aws_region" {
  description = "AWS region"
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
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, uat, prod."
  }
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "campaign_intelligence_enabled" {
  description = "Create campaign intelligence data-plane resources in this environment"
  type        = bool
  default     = false
}

variable "promotion_approved" {
  description = "Explicit approval gate required before enabling UAT or Production"
  type        = bool
  default     = false
}

variable "pipeline_max_read_request_units" {
  description = "Maximum on-demand reads per second for the transient pipeline table"
  type        = number
  default     = 100
}

variable "pipeline_max_write_request_units" {
  description = "Maximum on-demand writes per second for the transient pipeline table"
  type        = number
  default     = 50
}

variable "intelligence_max_read_request_units" {
  description = "Maximum on-demand reads per second for the persistent campaign table"
  type        = number
  default     = 100
}

variable "intelligence_max_write_request_units" {
  description = "Maximum on-demand writes per second for the persistent campaign table"
  type        = number
  default     = 25
}

variable "source_queue_retention_seconds" {
  description = "Retention for feature and clustering source queues"
  type        = number
  default     = 345600
}

variable "dead_letter_queue_retention_seconds" {
  description = "Retention for feature and clustering dead-letter queues"
  type        = number
  default     = 1209600
}

variable "feature_queue_visibility_timeout_seconds" {
  description = "Feature queue visibility timeout"
  type        = number
  default     = 180
}

variable "cluster_queue_visibility_timeout_seconds" {
  description = "Clustering queue visibility timeout"
  type        = number
  default     = 180
}

variable "queue_max_receive_count" {
  description = "Receive attempts before a message moves to its DLQ"
  type        = number
  default     = 5
}

variable "campaign_budget_limit_usd" {
  description = "Monthly campaign intelligence budget ceiling in USD"
  type        = number
}

variable "budget_notification_emails" {
  description = "Email recipients for 50, 80, and 100 percent campaign budget alerts"
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for address in var.budget_notification_emails : can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", address))
    ])
    error_message = "Every budget notification recipient must be a valid email address."
  }
}

variable "persistent_deletion_protection_enabled" {
  description = "Protect the persistent campaign table from deletion"
  type        = bool
  default     = false
}
