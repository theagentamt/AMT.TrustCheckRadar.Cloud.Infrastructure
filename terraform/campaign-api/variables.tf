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

variable "campaign_api_enabled" {
  description = "Create the authenticated app-facing campaign trends route"
  type        = bool
  default     = false
}

variable "campaign_review_api_enabled" {
  description = "Create the separately authorized campaign review route"
  type        = bool
  default     = false
}

variable "promotion_approved" {
  description = "Explicit approval gate required before enabling UAT or Production"
  type        = bool
  default     = false
}

variable "artifact_release" {
  description = "Immutable release identifier containing campaign API Lambda artifacts"
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

variable "trends_artifact_name" {
  description = "Campaign trends Lambda zip filename"
  type        = string
  default     = "campaign_trends.zip"
}

variable "review_artifact_name" {
  description = "Campaign review Lambda zip filename"
  type        = string
  default     = "campaign_review.zip"
}

variable "campaign_reviewer_username" {
  description = "The sole Cognito username assigned to the V1 campaign reviewer group"
  type        = string
  default     = null
  sensitive   = true
}

variable "trends_path" {
  description = "Authenticated app-facing trends route"
  type        = string
  default     = "/v1/scam-trends"
}

variable "review_path" {
  description = "Separately authorized campaign review transition route"
  type        = string
  default     = "/v1/internal/campaigns/{campaignId}/transitions"
}

variable "log_retention_days" {
  description = "CloudWatch retention for content-free campaign API logs"
  type        = number
  default     = 14
}

variable "trends_memory_mb" {
  description = "Campaign trends Lambda memory"
  type        = number
  default     = 512
}

variable "review_memory_mb" {
  description = "Campaign review Lambda memory"
  type        = number
  default     = 512
}

variable "lambda_timeout_seconds" {
  description = "Campaign API Lambda timeout"
  type        = number
  default     = 10
}

variable "reserved_concurrency" {
  description = "Reserved concurrency cap per campaign API Lambda"
  type        = number
  default     = 2
}

variable "maximum_page_size" {
  description = "Maximum number of campaigns returned by one API request"
  type        = number
  default     = 50
}

variable "pagination_token_ttl_seconds" {
  description = "Maximum lifetime of an opaque pagination token"
  type        = number
  default     = 900
}
