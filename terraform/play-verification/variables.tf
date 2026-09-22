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
  description = "Provision only the inactive Dev verifier. This root has no activation switch."
  type        = bool
  default     = false
  validation {
    condition     = !var.enabled || (var.environment == "dev" && var.project_name == "trustcheckradar" && var.aws_region == "us-east-1" && var.deployment != null)
    error_message = "Only the reviewed, immutable Dev candidate can be provisioned."
  }
}
variable "deployment" {
  description = "Exact immutable artifact, existing tables/secrets and verified mobile identity. Never credential values."
  type = object({
    artifact                  = object({ bucket = string, key = string, object_version = string, source_hash = string })
    users_table_arn           = string
    devices_table_arn         = string
    deletion_table_arn        = string
    authority_table_arn       = string
    authority_hmac_secret_arn = string
    google_play_secret_arn    = string
    cognito_issuer            = string
    cognito_app_client_id     = string
    package_name              = string
    product_id                = string
    base_plan_id              = string
  })
  default = null
  validation {
    condition = var.deployment == null ? true : try(
      var.deployment.artifact.bucket == "trustcheckradar-dev-107827791950-artifacts" &&
      can(regex("^releases/[a-f0-9]{40}/v1_play_handoff\\.zip$", var.deployment.artifact.key)) &&
      length(trimspace(var.deployment.artifact.object_version)) > 0 && var.deployment.artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.deployment.artifact.source_hash)) &&
      alltrue([for suffix, arn in {
        users           = var.deployment.users_table_arn, device-bindings = var.deployment.devices_table_arn,
        deletion-ledger = var.deployment.deletion_table_arn, purchase-entitlements = var.deployment.authority_table_arn
      } : arn == "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-${suffix}"]) &&
      can(regex("^arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]{6}$", var.deployment.authority_hmac_secret_arn)) &&
      can(regex("^arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/google-play-service-account-[A-Za-z0-9]{6}$", var.deployment.google_play_secret_arn)) &&
      can(regex("^https://cognito-idp\\.us-east-1\\.amazonaws\\.com/us-east-1_[A-Za-z0-9]+$", var.deployment.cognito_issuer)) &&
      can(regex("^[a-z0-9]+$", var.deployment.cognito_app_client_id)) &&
      var.deployment.package_name == "com.andmorethings.trustcheckradar" &&
    var.deployment.product_id == "trustcheck_radar_pro_monthly" && var.deployment.base_plan_id == "pro-monthly", false)
    error_message = "Use exact Dev dependencies, a source-pinned v1_play_handoff package and the owner-selected Play identity."
  }
}
