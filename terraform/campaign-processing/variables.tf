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

variable "state_bucket_name" {
  description = "S3 bucket containing upstream Terraform states"
  type        = string
}

variable "state_bucket_region" {
  description = "AWS region containing the Terraform state bucket"
  type        = string
}

variable "state_key_prefix" {
  description = "Root key prefix used for Terraform state objects"
  type        = string
  default     = "trustcheckradar"
}

variable "campaign_processing_enabled" {
  description = "Create campaign processing functions and event sources"
  type        = bool
  default     = false
}

variable "promotion_approved" {
  description = "Explicit approval gate required before enabling UAT or Production"
  type        = bool
  default     = false
}

variable "kill_switch_enabled" {
  description = "Disable event-source mappings and lifecycle schedules without deleting state"
  type        = bool
  default     = true
}

variable "artifact_release" {
  description = "Immutable release identifier containing campaign worker zip artifacts"
  type        = string
  default     = null

  validation {
    condition = (
      var.artifact_release == null ||
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.artifact_release))
    )
    error_message = "artifact_release must contain only letters, digits, dots, underscores, and hyphens."
  }
}

variable "publisher_artifact_name" {
  description = "Observation publisher zip filename in the immutable release"
  type        = string
  default     = "campaign_observation_publisher.zip"
}

variable "cluster_artifact_name" {
  description = "Cluster aggregator zip filename in the immutable release"
  type        = string
  default     = "campaign_cluster_aggregator.zip"
}

variable "lifecycle_artifact_name" {
  description = "Lifecycle processor zip filename in the immutable release"
  type        = string
  default     = "campaign_lifecycle.zip"
}

variable "deletion_artifact_name" {
  description = "Deletion bridge zip filename in the immutable release"
  type        = string
  default     = "campaign_deletion_bridge.zip"
}

variable "contract_schema_version" {
  description = "Canonical campaign contract version"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch retention for content-free campaign worker logs"
  type        = number
  default     = 14
}

variable "publisher_memory_mb" {
  description = "Observation publisher Lambda memory"
  type        = number
  default     = 256
}

variable "cluster_memory_mb" {
  description = "Cluster aggregator Lambda memory"
  type        = number
  default     = 1024
}

variable "lifecycle_memory_mb" {
  description = "Lifecycle Lambda memory"
  type        = number
  default     = 512
}

variable "deletion_memory_mb" {
  description = "Deletion bridge Lambda memory"
  type        = number
  default     = 512
}

variable "publisher_timeout_seconds" {
  description = "Observation publisher timeout"
  type        = number
  default     = 30
}

variable "cluster_timeout_seconds" {
  description = "Cluster aggregator timeout"
  type        = number
  default     = 30
}

variable "lifecycle_timeout_seconds" {
  description = "Lifecycle processor timeout"
  type        = number
  default     = 60
}

variable "deletion_timeout_seconds" {
  description = "Deletion bridge timeout"
  type        = number
  default     = 30
}

variable "reserved_concurrency" {
  description = "Default reserved concurrency cap for each campaign worker"
  type        = number
  default     = 2
}

variable "queue_batch_size" {
  description = "Maximum records delivered to SQS workers per batch"
  type        = number
  default     = 10
}
