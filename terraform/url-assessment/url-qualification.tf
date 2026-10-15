variable "url_qualification" {
  description = "Independent trusted synthetic-only profile. Null leaves the existing private assessment unchanged; no public actor data is passed here."
  type = object({
    mode_enabled       = optional(bool, false)
    provider_enabled   = optional(bool, false)
    retention_approved = optional(bool, false)
    approval_reference = optional(string, "")
    table_arn          = string
    manifest_json      = string
  })
  default   = null
  sensitive = true
  validation {
    condition = var.url_qualification == null ? true : (
      var.enabled && var.environment == "dev" && var.aws_region == "us-east-1" && var.project_name == "trustcheckradar" && data.aws_caller_identity.current.account_id == "107827791950" &&
      var.url_qualification.table_arn == "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification" &&
      can(regex("^[0-9]{10}_[A-Za-z0-9_-]{1,32}$", jsondecode(var.url_qualification.manifest_json).runId)) &&
      (!var.url_qualification.provider_enabled || (var.url_qualification.mode_enabled && var.url_qualification.retention_approved)) &&
      (!var.url_qualification.retention_approved || length(trimspace(var.url_qualification.approval_reference)) > 0)
    )
    error_message = "Private qualification needs an exact Dev store/manifest and recorded retention before provider execution."
  }
}
locals {
  url_qualification_configured = nonsensitive(var.url_qualification != null)
  url_qualification_environment = local.url_qualification_configured ? {
    URL_QUALIFICATION_ENABLED       = tostring(var.url_qualification.mode_enabled)
    URL_PROVIDER_ENABLED            = tostring(var.url_qualification.provider_enabled)
    URL_RETENTION_APPROVED          = tostring(var.url_qualification.retention_approved)
    URL_QUALIFICATION_TABLE_NAME    = split("/", var.url_qualification.table_arn)[1]
    URL_QUALIFICATION_MANIFEST_JSON = var.url_qualification.manifest_json
  } : {}
}
