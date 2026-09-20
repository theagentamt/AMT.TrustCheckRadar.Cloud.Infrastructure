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
  description = "Provision the isolated candidate only. This does not enable consumer access or the sweep schedule."
  type        = bool
  default     = false
  validation {
    condition     = !var.enabled || (var.environment == "dev" && var.project_name == "trustcheckradar" && var.aws_region == "us-east-1" && var.deployment != null)
    error_message = "Only a version-pinned TrustCheckRadar Dev candidate in us-east-1 can be provisioned."
  }
}
variable "deployment" {
  description = "Reviewed immutable packages and exact same-account dependencies. No secret values."
  type = object({
    artifacts = map(object({
      bucket         = string
      key            = string
      object_version = string
      source_hash    = string
    }))
    users_table_arn       = string
    devices_table_arn     = string
    deletion_table_arn    = string
    authority_table_arn   = string
    assessment_alias_arn  = string
    cognito_issuer        = string
    cognito_app_client_id = string
  })
  default = null
  validation {
    condition = var.deployment == null ? true : try(
      toset(keys(var.deployment.artifacts)) == toset(["consumer", "recovery", "entitlements"]) &&
      length(toset([for artifact in values(var.deployment.artifacts) : split("/", artifact.key)[1]])) == 1 &&
      alltrue([for name, artifact in var.deployment.artifacts :
        artifact.bucket == "${var.project_name}-${var.environment}-${split(":", var.deployment.authority_table_arn)[4]}-artifacts" &&
        can(regex("^releases/[a-f0-9]{40}/${ { consumer = "url_consumer", recovery = "url_lease_recovery", entitlements = "v1_entitlements" }[name]}\\.zip$", artifact.key)) &&
        length(trimspace(artifact.object_version)) > 0 && artifact.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", artifact.source_hash))
      ]) &&
      alltrue([for suffix, arn in { users = var.deployment.users_table_arn, device-bindings = var.deployment.devices_table_arn, deletion-ledger = var.deployment.deletion_table_arn, purchase-entitlements = var.deployment.authority_table_arn } :
        can(regex("^arn:aws:dynamodb:${var.aws_region}:[0-9]{12}:table/${var.project_name}-${var.environment}-${suffix}$", arn))
      ]) &&
      can(regex("^arn:aws:lambda:${var.aws_region}:[0-9]{12}:function:${var.project_name}-${var.environment}-url-assessment:live$", var.deployment.assessment_alias_arn)) &&
      can(regex("^https://cognito-idp\\.${var.aws_region}\\.amazonaws\\.com/${var.aws_region}_[A-Za-z0-9]+$", var.deployment.cognito_issuer)) &&
    can(regex("^[a-z0-9]+$", var.deployment.cognito_app_client_id)), false)
    error_message = "Dependencies must be exact environment-scoped ARNs and immutable consumer, recovery and entitlement artifacts, with a real Cognito issuer/client."
  }
}
