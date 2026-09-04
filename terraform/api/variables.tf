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

variable "device_bindings_inactive_retention_days" {
  description = "Number of days inactive device bindings should be retained before TTL cleanup"
  type        = number
  default     = 180
}

variable "google_play_secret_arn" {
  description = "Optional existing Secrets Manager ARN containing Google Play service account credentials. When null, this stack creates the secret container."
  type        = string
  default     = null
}

variable "google_play_secret_name" {
  description = "Secrets Manager secret name to create when google_play_secret_arn is not provided"
  type        = string
  default     = null
}

variable "google_play_secret_recovery_window_in_days" {
  description = "Recovery window for the Terraform-managed Google Play secret container"
  type        = number
  default     = 7
}

variable "google_play_package_name" {
  description = "Google Play package name used for subscription validation"
  type        = string
  default     = "com.andmorethings.trustcheckradar"
}

variable "google_play_subscription_product_id" {
  description = "Google Play subscription product id used for MVP validation"
  type        = string
  default     = "trustcheck_radar_pro_monthly"
}

variable "openai_secret_arn" {
  description = "Optional existing Secrets Manager ARN containing the OpenAI credentials/config used by the analysis Lambda. When null, this stack creates the secret container."
  type        = string
  default     = null
}

variable "openai_secret_name" {
  description = "Secrets Manager secret name to create when openai_secret_arn is not provided"
  type        = string
  default     = null
}

variable "openai_secret_recovery_window_in_days" {
  description = "Recovery window for the Terraform-managed OpenAI secret container"
  type        = number
  default     = 7
}

variable "web_risk_secret_arn" {
  description = "Optional existing Secrets Manager ARN containing the Google Web Risk API key. When null, this stack creates the secret container."
  type        = string
  default     = null
}

variable "web_risk_secret_name" {
  description = "Secrets Manager secret name to create when web_risk_secret_arn is not provided"
  type        = string
  default     = null
}

variable "web_risk_secret_recovery_window_in_days" {
  description = "Recovery window for the Terraform-managed Web Risk secret container"
  type        = number
  default     = 7
}

variable "age_attestation_lambda_name" {
  description = "Age attestation Lambda function name"
  type        = string
  default     = null
}

variable "age_attestation_lambda_s3_bucket" {
  description = "S3 bucket containing age attestation Lambda zip. Defaults to <project>-<environment>-artifacts when null."
  type        = string
  default     = null
}

variable "age_attestation_lambda_s3_key" {
  description = "Optional S3 key override for the age attestation Lambda zip"
  type        = string
  default     = null
}

variable "age_attestation_lambda_s3_object_version" {
  description = "Optional S3 object version for immutable Lambda deployments"
  type        = string
  default     = null
}

variable "age_attestation_lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.13"
}

variable "age_attestation_lambda_handler" {
  description = "Lambda handler"
  type        = string
  default     = "app.lambda_handler"
}

variable "age_attestation_lambda_timeout_seconds" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "age_attestation_lambda_memory_mb" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "age_attestation_lambda_architectures" {
  description = "Lambda architectures"
  type        = list(string)
  default     = ["arm64"]
}

variable "age_attestation_lambda_reserved_concurrency" {
  description = "Reserved concurrency cap to limit abuse and protect downstream resources"
  type        = number
  default     = 5
}

variable "age_attestation_log_retention_days" {
  description = "CloudWatch log retention for Lambda and API logs"
  type        = number
  default     = 14
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "$default"
}

variable "disable_execute_api_endpoint" {
  description = "Disable the default execute-api endpoint so the API is reachable only through the custom domain"
  type        = bool
  default     = false
}

variable "api_throttle_burst_limit" {
  description = "API Gateway burst throttle limit"
  type        = number
  default     = 10
}

variable "api_throttle_rate_limit" {
  description = "API Gateway steady-state throttle limit per second"
  type        = number
  default     = 5
}

variable "age_attestation_lambda_env" {
  description = "Additional environment variables for the age attestation Lambda"
  type        = map(string)
  default     = {}
}

variable "analysis_lambda_name" {
  description = "Conversation analysis Lambda function name"
  type        = string
  default     = null
}

variable "analysis_lambda_s3_bucket" {
  description = "S3 bucket containing the conversation analysis Lambda zip. Defaults to <project>-<environment>-artifacts when null."
  type        = string
  default     = null
}

variable "analysis_lambda_s3_key" {
  description = "Optional S3 key override for the conversation analysis Lambda zip"
  type        = string
  default     = null
}

variable "analysis_lambda_s3_object_version" {
  description = "Optional S3 object version for immutable conversation analysis Lambda deployments"
  type        = string
  default     = null
}

variable "analysis_lambda_runtime" {
  description = "Conversation analysis Lambda runtime"
  type        = string
  default     = "python3.13"
}

variable "analysis_lambda_handler" {
  description = "Conversation analysis Lambda handler"
  type        = string
  default     = "app.lambda_handler"
}

variable "analysis_lambda_timeout_seconds" {
  description = "Conversation analysis Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "analysis_lambda_memory_mb" {
  description = "Conversation analysis Lambda memory size in MB"
  type        = number
  default     = 512
}

variable "analysis_lambda_architectures" {
  description = "Conversation analysis Lambda architectures"
  type        = list(string)
  default     = ["arm64"]
}

variable "analysis_lambda_reserved_concurrency" {
  description = "Reserved concurrency cap for the conversation analysis Lambda"
  type        = number
  default     = 5
}

variable "analysis_lambda_env" {
  description = "Additional environment variables for the conversation analysis Lambda"
  type        = map(string)
  default     = {}
}

variable "analysis_scan_rate_limit_window_seconds" {
  description = "Backend scan abuse-cap window in seconds for the conversation analysis Lambda"
  type        = number
  default     = 60
}

variable "analysis_scan_rate_limit_max_requests" {
  description = "Maximum scan requests allowed per window for the conversation analysis Lambda"
  type        = number
  default     = 10
}

variable "analysis_free_monthly_scan_limit" {
  description = "Monthly included scan quota for free-tier users"
  type        = number
  default     = 10
}

variable "analysis_pro_monthly_scan_limit" {
  description = "Monthly included scan quota for pro-tier users"
  type        = number
  default     = 1000
}

variable "device_registration_lambda_name" {
  description = "Device registration Lambda function name"
  type        = string
  default     = null
}

variable "device_registration_lambda_s3_bucket" {
  description = "S3 bucket containing the device registration Lambda zip. Defaults to <project>-<environment>-artifacts when null."
  type        = string
  default     = null
}

variable "device_registration_lambda_s3_key" {
  description = "Optional S3 key override for the device registration Lambda zip"
  type        = string
  default     = null
}

variable "device_registration_lambda_s3_object_version" {
  description = "Optional S3 object version for immutable device registration Lambda deployments"
  type        = string
  default     = null
}

variable "device_registration_lambda_runtime" {
  description = "Device registration Lambda runtime"
  type        = string
  default     = "python3.13"
}

variable "device_registration_lambda_handler" {
  description = "Device registration Lambda handler"
  type        = string
  default     = "app.lambda_handler"
}

variable "device_registration_lambda_timeout_seconds" {
  description = "Device registration Lambda timeout in seconds"
  type        = number
  default     = 15
}

variable "device_registration_lambda_memory_mb" {
  description = "Device registration Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "device_registration_lambda_architectures" {
  description = "Device registration Lambda architectures"
  type        = list(string)
  default     = ["arm64"]
}

variable "device_registration_lambda_reserved_concurrency" {
  description = "Reserved concurrency cap for the device registration Lambda"
  type        = number
  default     = 5
}

variable "device_registration_lambda_env" {
  description = "Additional environment variables for the device registration Lambda"
  type        = map(string)
  default     = {}
}

variable "device_registration_path" {
  description = "Primary public path for the device registration endpoint"
  type        = string
  default     = "/device-registration"
}

variable "enable_device_recovery" {
  description = "Whether to provision the device recovery Lambda, route, and permissions"
  type        = bool
  default     = false
}

variable "device_recovery_lambda_name" {
  description = "Device recovery Lambda function name"
  type        = string
  default     = null
}

variable "device_recovery_lambda_s3_bucket" {
  description = "S3 bucket containing the device recovery Lambda zip. Defaults to <project>-<environment>-artifacts when null."
  type        = string
  default     = null
}

variable "device_recovery_lambda_s3_key" {
  description = "Optional S3 key override for the device recovery Lambda zip"
  type        = string
  default     = null
}

variable "device_recovery_lambda_s3_object_version" {
  description = "Optional S3 object version for immutable device recovery Lambda deployments"
  type        = string
  default     = null
}

variable "device_recovery_lambda_runtime" {
  description = "Device recovery Lambda runtime"
  type        = string
  default     = "python3.13"
}

variable "device_recovery_lambda_handler" {
  description = "Device recovery Lambda handler"
  type        = string
  default     = "app.lambda_handler"
}

variable "device_recovery_lambda_timeout_seconds" {
  description = "Device recovery Lambda timeout in seconds"
  type        = number
  default     = 15
}

variable "device_recovery_lambda_memory_mb" {
  description = "Device recovery Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "device_recovery_lambda_architectures" {
  description = "Device recovery Lambda architectures"
  type        = list(string)
  default     = ["arm64"]
}

variable "device_recovery_lambda_reserved_concurrency" {
  description = "Reserved concurrency cap for the device recovery Lambda"
  type        = number
  default     = 5
}

variable "device_recovery_lambda_env" {
  description = "Additional environment variables for the device recovery Lambda"
  type        = map(string)
  default     = {}
}

variable "device_recovery_path" {
  description = "Primary public path for the device recovery endpoint"
  type        = string
  default     = "/device-recovery"
}

variable "purchase_handoff_lambda_name" {
  description = "Purchase handoff Lambda function name"
  type        = string
  default     = null
}

variable "entitlement_snapshot_lambda_name" {
  description = "Entitlement snapshot Lambda function name"
  type        = string
  default     = null
}

variable "purchase_handoff_lambda_s3_bucket" {
  description = "S3 bucket containing the purchase handoff Lambda zip. Defaults to <project>-<environment>-artifacts when null."
  type        = string
  default     = null
}

variable "entitlement_snapshot_lambda_s3_bucket" {
  description = "S3 bucket containing the entitlement snapshot Lambda zip. Defaults to <project>-<environment>-artifacts when null."
  type        = string
  default     = null
}

variable "purchase_handoff_lambda_s3_key" {
  description = "Optional S3 key override for the purchase handoff Lambda zip"
  type        = string
  default     = null
}

variable "entitlement_snapshot_lambda_s3_key" {
  description = "Optional S3 key override for the entitlement snapshot Lambda zip"
  type        = string
  default     = null
}

variable "purchase_handoff_lambda_s3_object_version" {
  description = "Optional S3 object version for immutable purchase handoff Lambda deployments"
  type        = string
  default     = null
}

variable "entitlement_snapshot_lambda_s3_object_version" {
  description = "Optional S3 object version for immutable entitlement snapshot Lambda deployments"
  type        = string
  default     = null
}

variable "purchase_handoff_lambda_runtime" {
  description = "Purchase handoff Lambda runtime"
  type        = string
  default     = "python3.13"
}

variable "entitlement_snapshot_lambda_runtime" {
  description = "Entitlement snapshot Lambda runtime"
  type        = string
  default     = "python3.13"
}

variable "purchase_handoff_lambda_handler" {
  description = "Purchase handoff Lambda handler"
  type        = string
  default     = "app.lambda_handler"
}

variable "entitlement_snapshot_lambda_handler" {
  description = "Entitlement snapshot Lambda handler"
  type        = string
  default     = "app.lambda_handler"
}

variable "purchase_handoff_lambda_timeout_seconds" {
  description = "Purchase handoff Lambda timeout in seconds"
  type        = number
  default     = 15
}

variable "entitlement_snapshot_lambda_timeout_seconds" {
  description = "Entitlement snapshot Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "purchase_handoff_lambda_memory_mb" {
  description = "Purchase handoff Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "entitlement_snapshot_lambda_memory_mb" {
  description = "Entitlement snapshot Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "purchase_handoff_lambda_architectures" {
  description = "Purchase handoff Lambda architectures"
  type        = list(string)
  default     = ["arm64"]
}

variable "entitlement_snapshot_lambda_architectures" {
  description = "Entitlement snapshot Lambda architectures"
  type        = list(string)
  default     = ["arm64"]
}

variable "purchase_handoff_lambda_reserved_concurrency" {
  description = "Reserved concurrency cap for the purchase handoff Lambda"
  type        = number
  default     = 5
}

variable "entitlement_snapshot_lambda_reserved_concurrency" {
  description = "Reserved concurrency cap for the entitlement snapshot Lambda"
  type        = number
  default     = 5
}

variable "purchase_handoff_lambda_env" {
  description = "Additional environment variables for the purchase handoff Lambda"
  type        = map(string)
  default     = {}
}

variable "entitlement_snapshot_lambda_env" {
  description = "Additional environment variables for the entitlement snapshot Lambda"
  type        = map(string)
  default     = {}
}

variable "purchase_handoff_path" {
  description = "Primary public path for the purchase handoff endpoint"
  type        = string
  default     = "/purchase-handoff"
}

variable "entitlement_snapshot_path" {
  description = "Primary public path for the entitlement snapshot endpoint"
  type        = string
  default     = "/entitlements/snapshot"
}

variable "enable_web_risk_communication" {
  description = "Whether to provision the Web Risk communication Lambda, route, secret container, and permissions"
  type        = bool
  default     = false
}

variable "web_risk_communication_lambda_name" {
  description = "Web Risk communication Lambda function name"
  type        = string
  default     = null
}

variable "web_risk_communication_lambda_s3_bucket" {
  description = "S3 bucket containing the Web Risk communication Lambda zip. Defaults to <project>-<environment>-artifacts when null."
  type        = string
  default     = null
}

variable "web_risk_communication_lambda_s3_key" {
  description = "Optional S3 key override for the Web Risk communication Lambda zip"
  type        = string
  default     = null
}

variable "web_risk_communication_lambda_s3_object_version" {
  description = "Optional S3 object version for immutable Web Risk communication Lambda deployments"
  type        = string
  default     = null
}

variable "web_risk_communication_lambda_runtime" {
  description = "Web Risk communication Lambda runtime"
  type        = string
  default     = "python3.13"
}

variable "web_risk_communication_lambda_handler" {
  description = "Web Risk communication Lambda handler"
  type        = string
  default     = "app.lambda_handler"
}

variable "web_risk_communication_lambda_timeout_seconds" {
  description = "Web Risk communication Lambda timeout in seconds"
  type        = number
  default     = 15
}

variable "web_risk_communication_lambda_memory_mb" {
  description = "Web Risk communication Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "web_risk_communication_lambda_architectures" {
  description = "Web Risk communication Lambda architectures"
  type        = list(string)
  default     = ["arm64"]
}

variable "web_risk_communication_lambda_reserved_concurrency" {
  description = "Reserved concurrency cap for the Web Risk communication Lambda"
  type        = number
  default     = 5
}

variable "web_risk_communication_lambda_env" {
  description = "Additional environment variables for the Web Risk communication Lambda"
  type        = map(string)
  default     = {}
}

variable "web_risk_communication_path" {
  description = "Primary public path for the Web Risk communication endpoint"
  type        = string
  default     = "/web-risk-communication"
}

variable "purchase_usage_counter_retention_days" {
  description = "Number of days monthly purchase usage-counter items should be retained before TTL cleanup"
  type        = number
  default     = 548
}

variable "entitlement_default_tier" {
  description = "Normalized tier value returned when no paid entitlement is currently active"
  type        = string
  default     = "free"
}

variable "entitlement_premium_tier" {
  description = "Normalized tier value returned when the Google Play subscription is active"
  type        = string
  default     = "pro"
}

variable "entitlement_usage_period_mode" {
  description = "Usage-period model used by the shared entitlement service"
  type        = string
  default     = "billing_cycle"

  validation {
    condition     = contains(["billing_cycle"], var.entitlement_usage_period_mode)
    error_message = "entitlement_usage_period_mode must be billing_cycle."
  }
}

variable "entitlement_access_granting_statuses" {
  description = "Normalized subscription statuses that should continue to grant premium access"
  type        = list(string)
  default     = ["active", "grace"]
}

variable "entitlement_nonterminal_statuses" {
  description = "Normalized subscription statuses that are still operationally relevant for restore, retry, or support flows"
  type        = list(string)
  default     = ["active", "grace", "hold", "paused", "pending", "canceled"]
}

variable "purchase_verification_mode" {
  description = "Verification adapter mode for the purchase handoff backend"
  type        = string
  default     = "stub"

  validation {
    condition     = contains(["stub", "live"], var.purchase_verification_mode)
    error_message = "purchase_verification_mode must be either 'stub' or 'live'."
  }
}

variable "analysis_primary_path" {
  description = "Primary public path for the conversation analysis endpoint"
  type        = string
  default     = "/analysis"
}

variable "analysis_legacy_path_enabled" {
  description = "Whether to keep the legacy /v1/conversation-analysis route mapped to the same Lambda"
  type        = bool
  default     = true
}

variable "cors_allow_origins" {
  description = "Allowed CORS origins for the HTTP API"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_headers" {
  description = "Allowed CORS headers for the HTTP API"
  type        = list(string)
  default     = ["authorization", "content-type", "x-requested-with"]
}

variable "cors_allow_methods" {
  description = "Allowed CORS methods for the HTTP API"
  type        = list(string)
  default     = ["OPTIONS", "GET", "POST"]
}
