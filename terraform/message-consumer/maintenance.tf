variable "authority_maintenance" {
  description = "Exact shared-authority maintenance output plus reviewed live readback; never a client assertion or permission to activate maintenance."
  type = object({
    schema_version        = number
    environment           = string
    authority_table_arn   = string
    recovery_alias_arn    = string
    recovery_version      = string
    recovery_code_sha256  = string
    worker_enabled        = bool
    schedule_enabled      = bool
    heartbeat_enforced    = bool
    provider_access_added = bool
  })
  default = null
}

locals {
  authority_maintenance_ready = try(
    var.authority_maintenance.schema_version == 1 &&
    var.authority_maintenance.environment == var.environment &&
    var.authority_maintenance.authority_table_arn == var.deployment.authority_table_arn &&
    var.authority_maintenance.recovery_alias_arn == "arn:aws:lambda:${var.aws_region}:107827791950:function:${var.project_name}-${var.environment}-url-lease-recovery:live" &&
    can(regex("^[1-9][0-9]*$", var.authority_maintenance.recovery_version)) &&
    can(regex("^[A-Za-z0-9+/]{43}=$", var.authority_maintenance.recovery_code_sha256)) &&
    var.authority_maintenance.worker_enabled && var.authority_maintenance.schedule_enabled &&
    var.authority_maintenance.heartbeat_enforced && !var.authority_maintenance.provider_access_added,
    false
  )
}
