variable "activate_authority_maintenance" {
  description = "Independently activate existing shared due-row recovery/expiry only. Never enables URL, access, trial or account admission. Requires separate rollout approval."
  type        = bool
  default     = false
  validation {
    condition = !var.activate_authority_maintenance || (
      var.enabled && var.environment == "dev" && var.alert_topic_arn != null &&
      var.authority_configuration != null && length(trimspace(var.maintenance_qualification_reference)) > 0
    )
    error_message = "Maintenance requires the pinned Dev authority, explicit horizons, existing alerts and reviewed recovery/expiry evidence."
  }
}

variable "maintenance_qualification_reference" {
  description = "Reviewed shared recovery/expiry evidence reference. Not a substitute for runtime/IAM/schedule readback and not a subject allowlist."
  type        = string
  default     = ""
  validation {
    condition     = length(var.maintenance_qualification_reference) <= 512
    error_message = "Use a bounded evidence reference, never credentials or account data."
  }
}

locals {
  authority_maintenance_active = local.authority_engineering_active || var.activate_authority_maintenance
}

output "authority_maintenance" {
  description = "Same-root configuration contract. A later consumer rollout must pair this with actual version/IAM/worker/schedule readback."
  value = var.enabled ? {
    schema_version        = 1
    environment           = var.environment
    authority_table_arn   = local.authority_arn
    recovery_alias_arn    = aws_lambda_alias.runtime["recovery"].arn
    recovery_version      = aws_lambda_alias.runtime["recovery"].function_version
    recovery_code_sha256  = local.runtime_artifacts["recovery"].source_hash
    worker_enabled        = local.authority_maintenance_active
    schedule_enabled      = try(aws_cloudwatch_event_rule.maintenance["recovery"].state == "ENABLED", false)
    heartbeat_enforced    = local.authority_maintenance_active && var.alert_topic_arn != null
    provider_access_added = false
  } : null
}
