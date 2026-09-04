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
  description = "S3 bucket containing the foundation remote state"
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

variable "artifact_release" {
  description = "Immutable application release identifier used in Lambda artifact S3 keys"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.artifact_release))
    error_message = "artifact_release must contain only letters, digits, dots, underscores, and hyphens."
  }
}

variable "post_confirmation_lambda_name" {
  description = "Lambda function name for Cognito PostConfirmation trigger"
  type        = string
  default     = null
}

variable "post_confirmation_lambda_s3_bucket" {
  description = "S3 bucket containing Lambda deployment package zip. Defaults to <project>-<environment>-artifacts when null."
  type        = string
  default     = null
}

variable "post_confirmation_lambda_s3_key" {
  description = "Optional S3 key override for the PostConfirmation Lambda zip"
  type        = string
  default     = null
}

variable "post_confirmation_lambda_s3_object_version" {
  description = "Optional S3 object version for immutable deployments"
  type        = string
  default     = null
}

variable "post_confirmation_lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.13"
}

variable "post_confirmation_lambda_handler" {
  description = "Lambda handler"
  type        = string
  default     = "app.lambda_handler"
}

variable "post_confirmation_lambda_timeout_seconds" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "post_confirmation_lambda_memory_mb" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "post_confirmation_lambda_architectures" {
  description = "Lambda architectures"
  type        = list(string)
  default     = ["arm64"]
}

variable "post_confirmation_lambda_env" {
  description = "Additional environment variables for PostConfirmation Lambda"
  type        = map(string)
  default     = {}
}

variable "user_pool_lambda_config_overrides" {
  description = "Optional additional Cognito Lambda config keys to preserve when setting PostConfirmation (for example PreSignUp, PreTokenGeneration). Use Cognito API key casing."
  type        = map(string)
  default     = {}
}

variable "aws_cli_profile" {
  description = "Optional AWS CLI profile for the local-exec user pool update step."
  type        = string
  default     = null
}
