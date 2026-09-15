variable "device_recovery_control_enabled" {
  description = "Provision recovery security state only after its independent retention policy is approved."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition = !var.device_recovery_control_enabled || try(
      var.device_recovery_policy.approved && length(trimspace(var.device_recovery_policy.approval_reference)) > 0 &&
      (var.environment == "dev" || var.device_recovery_promotion_approved), false
    )
    error_message = "Recovery storage needs approved retention; UAT/Prod also require separate promotion approval."
  }
}

variable "device_recovery_promotion_approved" {
  type     = bool
  default  = false
  nullable = false
}

variable "device_recovery_policy" {
  description = "Recovery-only audit/receipt/rate lifetimes and PITR window. No policy is inferred from History. Expiry is application-enforced; TTL cleanup is eventual."
  type = object({
    approved               = bool
    approval_reference     = string
    audit_retention_days   = number
    receipt_retention_days = number
    rate_retention_hours   = number
    pitr_days              = number
  })
  default = null
  validation {
    condition = var.device_recovery_policy == null ? true : try(
      alltrue([for value in [var.device_recovery_policy.audit_retention_days, var.device_recovery_policy.receipt_retention_days, var.device_recovery_policy.rate_retention_hours] : value > 0 && floor(value) == value]) &&
      var.device_recovery_policy.pitr_days >= 0 && var.device_recovery_policy.pitr_days <= 35 && floor(var.device_recovery_policy.pitr_days) == var.device_recovery_policy.pitr_days &&
      var.device_recovery_policy.audit_retention_days >= var.device_recovery_policy.receipt_retention_days,
      false
    )
    error_message = "Recovery retention must be positive whole units, audit must cover receipts, and PITR must be 0-35 whole days (zero explicitly disables backups)."
  }
}

resource "aws_dynamodb_table" "device_recovery_control" {
  count                       = var.device_recovery_control_enabled ? 1 : 0
  name                        = "${local.name_prefix}-device-recovery-control"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "PK"
  range_key                   = "SK"
  deletion_protection_enabled = var.environment == "prod"
  stream_enabled              = false
  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
  server_side_encryption {
    enabled = false
  }
  point_in_time_recovery {
    enabled                 = var.device_recovery_policy.pitr_days > 0
    recovery_period_in_days = var.device_recovery_policy.pitr_days > 0 ? var.device_recovery_policy.pitr_days : null
  }
  on_demand_throughput {
    max_read_request_units  = 25
    max_write_request_units = 10
  }
  tags = merge(local.common_tags, { DataClass = "recovery-security-metadata" })
}

locals {
  device_recovery_control_contract = {
    schema_version = 1
    environment    = var.environment
    enabled        = var.device_recovery_control_enabled
    table_name     = try(aws_dynamodb_table.device_recovery_control[0].name, null)
    table_arn      = try(aws_dynamodb_table.device_recovery_control[0].arn, null)
    ttl_attribute  = "expiresAt"
    policy         = var.device_recovery_control_enabled ? var.device_recovery_policy : null
  }
}

output "device_recovery_control_contract" {
  value = local.device_recovery_control_contract
}
