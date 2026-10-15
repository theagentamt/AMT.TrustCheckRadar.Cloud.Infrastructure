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
  description = "Provision an isolated Dev read-only candidate; list and detail access remain separately gated."
  type        = bool
  default     = false
  validation {
    condition     = !var.enabled || (var.environment == "dev" && var.project_name == "trustcheckradar" && var.aws_region == "us-east-1" && var.deployment != null)
    error_message = "Only a version-pinned TrustCheckRadar Dev candidate in us-east-1 can be provisioned."
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
    cognito_issuer            = string
    cognito_app_client_id     = string
  })
  default = null
  validation {
    condition = var.deployment == null ? true : try(
      toset(keys(var.deployment.artifacts)) == toset(["reader"]) &&
      length(toset([for a in values(var.deployment.artifacts) : split("/", a.key)[1]])) == 1 &&
      alltrue([for name, a in var.deployment.artifacts :
        a.bucket == "${var.project_name}-${var.environment}-${split(":", var.deployment.authority_table_arn)[4]}-artifacts" &&
        can(regex("^releases/[a-f0-9]{40}/${ { reader = "governed_history" }[name]}\\.zip$", a.key)) &&
        length(trimspace(a.object_version)) > 0 && a.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", a.source_hash))
      ]) &&
      alltrue([for suffix, arn in { users = var.deployment.users_table_arn, device-bindings = var.deployment.devices_table_arn, deletion-ledger = var.deployment.deletion_table_arn, purchase-entitlements = var.deployment.authority_table_arn } :
        can(regex("^arn:aws:dynamodb:${var.aws_region}:[0-9]{12}:table/${var.project_name}-${var.environment}-${suffix}$", arn))
      ]) &&
      can(regex("^arn:aws:secretsmanager:${var.aws_region}:[0-9]{12}:secret:${var.project_name}/${var.environment}/v1-authority-hmac-[A-Za-z0-9]{6}$", var.deployment.authority_hmac_secret_arn)) &&
      can(regex("^https://cognito-idp\\.${var.aws_region}\\.amazonaws\\.com/${var.aws_region}_[A-Za-z0-9]+$", var.deployment.cognito_issuer)) &&
    can(regex("^[a-z0-9]+$", var.deployment.cognito_app_client_id)), false)
    error_message = "Use exact environment-scoped dependencies and governed History package from one immutable release."
  }
}

variable "list_enabled" {
  type    = bool
  default = false
  validation {
    condition     = !var.list_enabled || (var.enabled && var.api_gateway != null && length(var.engineering_subjects) == 1 && var.index_ready && length(var.authority_partitions) >= 1)
    error_message = "List requires a pinned Dev runtime, JWT routes, one subject and a verified active GSI2."
  }
}
variable "detail_enabled" {
  type    = bool
  default = false
  validation {
    condition     = !var.detail_enabled || (var.enabled && var.api_gateway != null && length(var.engineering_subjects) == 1 && var.index_ready && length(var.authority_partitions) >= 1)
    error_message = "Detail requires a pinned Dev runtime, JWT routes, one subject and a verified active GSI2."
  }
}
variable "index_ready" {
  description = "Set only after checking the foundation-owned GSI2 is ACTIVE with the exact content-free projection."
  type        = bool
  default     = false
}
variable "engineering_subjects" {
  type    = set(string)
  default = []
  validation {
    condition     = length(var.engineering_subjects) <= 1 && alltrue([for subject in var.engineering_subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", subject))])
    error_message = "Use at most one exact synthetic Dev subject; an empty set never grants access."
  }
}
variable "api_gateway" {
  type    = object({ api_id = string, execution_arn = string, authorizer_id = string })
  default = null
  validation {
    condition     = var.api_gateway == null ? true : (var.api_gateway.api_id == "icuak34th9" && var.api_gateway.execution_arn == "arn:aws:execute-api:us-east-1:107827791950:icuak34th9" && var.api_gateway.authorizer_id == "itms4b")
    error_message = "Reuse only the reviewed Dev HTTP API and JWT authorizer."
  }
}

variable "authority_partitions" {
  description = "Private derived HMAC partitions for the exact scoped Dev subject across every retained key; no secret key material."
  type        = set(string)
  default     = []
  validation {
    condition     = length(var.authority_partitions) <= 4 && alltrue([for partition in var.authority_partitions : can(regex("^V1#[A-Za-z0-9]{1,8}#[a-f0-9]{64}$", partition))]) && (length(var.authority_partitions) == 0 || length(var.engineering_subjects) == 1)
    error_message = "Supply at most four private account HMAC partitions, bound to the one authorized Dev subject."
  }
}
