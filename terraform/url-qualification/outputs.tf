output "qualification_store" {
  value = {
    provisioned             = var.enabled
    table_name              = var.enabled ? aws_dynamodb_table.qualification[0].name : null
    table_arn               = var.enabled ? aws_dynamodb_table.qualification[0].arn : null
    cleanup_enabled         = var.cleanup_enabled
    retention_approved      = var.retention_approved
    new_admission_enabled   = false
    provider_enabled        = false
    history_expansion       = false
    backups_configured      = false
    backup_inventory_needed = true
  }
}
