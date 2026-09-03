variable "aws_region" {
  description = "AWS region for all resources"
  type        = string

  validation {
    condition     = length(trim(var.aws_region, " ")) > 0
    error_message = "aws_region must not be empty."
  }
}

variable "project_name" {
  description = "Project/application prefix for naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.project_name))
    error_message = "project_name must be 3-30 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment identifier (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Common tags applied to resources"
  type        = map(string)
  default     = {}
}

variable "artifact_bucket_name" {
  description = "Optional override for the shared artifact S3 bucket name"
  type        = string
  default     = null
}

variable "artifact_bucket_force_destroy" {
  description = "Allow Terraform to delete non-empty artifact bucket on destroy"
  type        = bool
  default     = false
}

variable "analysis_abuse_control_table_name" {
  description = "Optional override for the conversation analysis abuse-control DynamoDB table name"
  type        = string
  default     = null
}

variable "device_bindings_table_name" {
  description = "Optional override for the device bindings DynamoDB table name"
  type        = string
  default     = null
}

variable "device_bindings_inactive_retention_days" {
  description = "Number of days inactive device bindings should be retained before TTL cleanup"
  type        = number
  default     = 180
}

variable "purchase_entitlements_table_name" {
  description = "Optional override for the purchase entitlements DynamoDB table name"
  type        = string
  default     = null
}

variable "web_risk_cache_table_name" {
  description = "Optional override for the web-risk cache DynamoDB table name"
  type        = string
  default     = null
}

variable "purchase_usage_counter_retention_days" {
  description = "Number of days monthly purchase usage-counter items should be retained before TTL cleanup"
  type        = number
  default     = 548
}

variable "cognito_password_min_length" {
  description = "Minimum password length for Cognito users"
  type        = number
  default     = 12
}

variable "cognito_temporary_password_validity_days" {
  description = "Temporary password validity for admin-created users"
  type        = number
  default     = 7
}

variable "cognito_refresh_token_validity_days" {
  description = "Refresh token validity in days"
  type        = number
  default     = 30
}

variable "cognito_access_token_validity_minutes" {
  description = "Access token validity in minutes"
  type        = number
  default     = 60
}

variable "cognito_id_token_validity_minutes" {
  description = "ID token validity in minutes"
  type        = number
  default     = 60
}

variable "hosted_ui_enabled" {
  description = "Create Cognito hosted UI domain and configure callback/signout URLs"
  type        = bool
  default     = false
}

variable "hosted_ui_domain_prefix" {
  description = "Unique domain prefix for Cognito hosted UI domain"
  type        = string
  default     = null

  validation {
    condition = (
      var.hosted_ui_enabled == false || (
        var.hosted_ui_domain_prefix != null &&
        length(trim(var.hosted_ui_domain_prefix, " ")) >= 3
      )
    )
    error_message = "hosted_ui_domain_prefix must be set to at least 3 characters when hosted_ui_enabled is true."
  }
}

variable "app_client_callback_urls" {
  description = "Allowed callback URLs for Cognito app client"
  type        = list(string)
  default     = []

  validation {
    condition = (
      var.hosted_ui_enabled == false || length(var.app_client_callback_urls) > 0
    )
    error_message = "At least one callback URL is required when hosted_ui_enabled is true."
  }
}

variable "app_client_logout_urls" {
  description = "Allowed logout URLs for Cognito app client"
  type        = list(string)
  default     = []
}

variable "users_status_gsi_enabled" {
  description = "Enable status-oriented GSI on Users table"
  type        = bool
  default     = false
}

variable "backend_assume_role_principals" {
  description = "AWS principals allowed to assume backend service role"
  type        = list(string)

  validation {
    condition     = length(var.backend_assume_role_principals) > 0
    error_message = "backend_assume_role_principals must include at least one principal."
  }
}

variable "deletion_assume_role_principals" {
  description = "AWS principals allowed to assume deletion workflow role"
  type        = list(string)

  validation {
    condition     = length(var.deletion_assume_role_principals) > 0
    error_message = "deletion_assume_role_principals must include at least one principal."
  }
}

variable "deletion_s3_bucket_arns" {
  description = "S3 bucket ARNs where deletion workflow may remove user prefixes"
  type        = list(string)
  default     = []
}
