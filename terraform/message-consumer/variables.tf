variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Unknown environment."
  }
}
variable "project_name" {
  type    = string
  default = "trustcheckradar"
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "enabled" {
  description = "Provision the isolated Dev runtimes and authenticated routes. Execution remains separately gated."
  type        = bool
  default     = false
  validation {
    condition     = !var.enabled || (var.environment == "dev" && var.project_name == "trustcheckradar" && var.aws_region == "us-east-1" && var.deployment != null)
    error_message = "Only a version-pinned TrustCheckRadar Dev candidate in us-east-1 can be provisioned."
  }
}

variable "engineering_subjects" {
  description = "Exact synthetic Dev Cognito subjects allowed during bounded rules-only qualification. Empty never means public access."
  type        = set(string)
  default     = []
  validation {
    condition     = length(var.engineering_subjects) <= 3 && alltrue([for subject in var.engineering_subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", subject))])
    error_message = "Supply at most three exact synthetic Cognito UUID subjects."
  }
}

variable "authority_configuration" {
  description = "Explicit V1 authority horizons; receipts and counters retain the approved seven-day boundary."
  type = object({
    operation_validity_seconds = number
    worker_settlement_seconds  = number
    reconciliation_seconds     = number
    counter_retention_seconds  = number
  })
  default = null
  validation {
    condition = var.authority_configuration == null ? true : (
      alltrue([for value in values(var.authority_configuration) : value > 0 && value == floor(value)]) &&
      var.authority_configuration.operation_validity_seconds + var.authority_configuration.worker_settlement_seconds + var.authority_configuration.reconciliation_seconds <= 604800 &&
      var.authority_configuration.counter_retention_seconds == 604800
    )
    error_message = "Authority horizons must be integral and bounded by the seven-day receipt policy."
  }
}

variable "provider_budget" {
  description = "Aggregate Dev provider circuit limits. These cap service attempts and do not change customer allowances."
  type = object({
    window_seconds          = number
    max_attempts_per_window = number
    max_failures_per_window = number
  })
  default = null
  validation {
    condition = var.provider_budget == null ? true : (
      var.provider_budget.window_seconds == floor(var.provider_budget.window_seconds) &&
      var.provider_budget.window_seconds >= 60 && var.provider_budget.window_seconds <= 86400 &&
      var.provider_budget.max_attempts_per_window == floor(var.provider_budget.max_attempts_per_window) &&
      var.provider_budget.max_attempts_per_window >= 1 && var.provider_budget.max_attempts_per_window <= 100000 &&
      var.provider_budget.max_failures_per_window == floor(var.provider_budget.max_failures_per_window) &&
      var.provider_budget.max_failures_per_window >= 1 &&
      var.provider_budget.max_failures_per_window <= var.provider_budget.max_attempts_per_window
    )
    error_message = "Provider limits must be positive bounded integers and failures cannot exceed attempts."
  }
}

variable "api_gateway" {
  description = "Existing Dev HTTP API and shared reviewed JWT authorizer; this root owns only the message routes."
  type = object({
    api_id        = string
    execution_arn = string
    authorizer_id = string
  })
  default = null
  validation {
    condition = var.api_gateway == null ? true : (
      can(regex("^[a-z0-9]{10}$", var.api_gateway.api_id)) &&
      var.api_gateway.execution_arn == "arn:aws:execute-api:us-east-1:107827791950:${var.api_gateway.api_id}" &&
      can(regex("^[a-z0-9]+$", var.api_gateway.authorizer_id))
    )
    error_message = "Use the exact same-account Dev API and existing JWT authorizer."
  }
}

variable "activate_rules_engineering" {
  description = "Allowlisted Dev candidate.1 qualification only. It never enables candidate.2/3 AI or general customer traffic."
  type        = bool
  default     = false
  validation {
    condition = !var.activate_rules_engineering || (
      var.enabled && var.environment == "dev" && length(var.engineering_subjects) > 0 &&
      var.authority_configuration != null && var.provider_budget != null && var.api_gateway != null
    )
    error_message = "Rules-only engineering activation requires provisioned Dev routes, exact subjects, authority horizons and provider caps."
  }
}
variable "deployment" {
  description = "Immutable reviewed packages and existing authority dependencies; never secret values."
  type = object({
    artifacts = map(object({
      bucket         = string
      key            = string
      object_version = string
      source_hash    = string
    }))
    users_table_arn           = string
    devices_table_arn         = string
    deletion_table_arn        = string
    authority_table_arn       = string
    authority_hmac_secret_arn = string
    assessment_alias_arn      = string
    cognito_issuer            = string
    cognito_app_client_id     = string
  })
  default = null
  validation {
    condition = var.deployment == null ? true : try(
      toset(keys(var.deployment.artifacts)) == toset(["consumer", "evaluator"]) &&
      length(toset([for a in values(var.deployment.artifacts) : split("/", a.key)[1]])) == 1 &&
      alltrue([for name, a in var.deployment.artifacts :
        a.bucket == "${var.project_name}-${var.environment}-${split(":", var.deployment.authority_table_arn)[4]}-artifacts" &&
        can(regex("^releases/[a-f0-9]{40}/${ { consumer = "message_consumer", evaluator = "message_evaluator" }[name]}\\.zip$", a.key)) &&
        length(trimspace(a.object_version)) > 0 && a.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", a.source_hash))
      ]) &&
      alltrue([for suffix, arn in { users = var.deployment.users_table_arn, device-bindings = var.deployment.devices_table_arn, deletion-ledger = var.deployment.deletion_table_arn, purchase-entitlements = var.deployment.authority_table_arn } :
        can(regex("^arn:aws:dynamodb:${var.aws_region}:[0-9]{12}:table/${var.project_name}-${var.environment}-${suffix}$", arn))
      ]) &&
      can(regex("^arn:aws:secretsmanager:${var.aws_region}:[0-9]{12}:secret:${var.project_name}/${var.environment}/v1-authority-hmac-[A-Za-z0-9]{6}$", var.deployment.authority_hmac_secret_arn)) &&
      can(regex("^arn:aws:lambda:${var.aws_region}:[0-9]{12}:function:${var.project_name}-${var.environment}-url-assessment:live$", var.deployment.assessment_alias_arn)) &&
      can(regex("^https://cognito-idp\\.${var.aws_region}\\.amazonaws\\.com/${var.aws_region}_[A-Za-z0-9]+$", var.deployment.cognito_issuer)) &&
    can(regex("^[a-z0-9]+$", var.deployment.cognito_app_client_id)), false)
    error_message = "Use exact environment-scoped dependencies and message consumer/evaluator packages from one immutable release."
  }
}
