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
  description = "Provision only an inactive isolated Dev candidate; this does not publish routes or activate feedback writes."
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
      toset(keys(var.deployment.artifacts)) == toset(["feedback"]) &&
      length(toset([for a in values(var.deployment.artifacts) : split("/", a.key)[1]])) == 1 &&
      alltrue([for name, a in var.deployment.artifacts :
        a.bucket == "${var.project_name}-${var.environment}-${split(":", var.deployment.authority_table_arn)[4]}-artifacts" &&
        can(regex("^releases/[a-f0-9]{40}/${ { feedback = "result_feedback" }[name]}\\.zip$", a.key)) &&
        length(trimspace(a.object_version)) > 0 && a.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", a.source_hash))
      ]) &&
      alltrue([for suffix, arn in { users = var.deployment.users_table_arn, device-bindings = var.deployment.devices_table_arn, deletion-ledger = var.deployment.deletion_table_arn, purchase-entitlements = var.deployment.authority_table_arn } :
        can(regex("^arn:aws:dynamodb:${var.aws_region}:[0-9]{12}:table/${var.project_name}-${var.environment}-${suffix}$", arn))
      ]) &&
      can(regex("^arn:aws:secretsmanager:${var.aws_region}:[0-9]{12}:secret:${var.project_name}/${var.environment}/v1-authority-hmac-[A-Za-z0-9]{6}$", var.deployment.authority_hmac_secret_arn)) &&
      can(regex("^https://cognito-idp\\.${var.aws_region}\\.amazonaws\\.com/${var.aws_region}_[A-Za-z0-9]+$", var.deployment.cognito_issuer)) &&
    can(regex("^[a-z0-9]+$", var.deployment.cognito_app_client_id)), false)
    error_message = "Use exact environment-scoped dependencies and result feedback package from one immutable release."
  }
}
