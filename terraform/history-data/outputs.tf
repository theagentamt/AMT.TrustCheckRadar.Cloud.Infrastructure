output "downstream_contract" {
  description = "Data-resource contract only; enabled never implies API, erasure, or mobile readiness"
  value = {
    schema_version              = 1
    environment                 = var.environment
    enabled                     = var.history_data_enabled
    content_table_name          = try(aws_dynamodb_table.history["content"].name, null)
    content_table_arn           = try(aws_dynamodb_table.history["content"].arn, null)
    control_table_name          = try(aws_dynamodb_table.history["control"].name, null)
    control_table_arn           = try(aws_dynamodb_table.history["control"].arn, null)
    expiration_index_name       = "ExpirationIndex"
    expiration_partition_key    = "expiryBucket"
    expiration_sort_key         = "expiresAt"
    lifecycle_index_name        = "PendingLifecycleIndex"
    lifecycle_partition_key     = "lifecycleBucket"
    lifecycle_sort_key          = "lifecycleAt"
    encryption_key_owner        = "AWS_OWNED"
    ttl_attribute               = "expiresAt"
    history_retention_seconds   = 90 * 24 * 60 * 60
    active_deletion_sla_seconds = 24 * 60 * 60
    snippets_enabled            = false
    points_enabled              = false
    badge_milestones            = [1, 5, 20]
    storage_policy              = var.history_data_enabled ? var.storage_policy : null
    storage_monitoring_enabled  = local.monitoring_enabled
    storage_dashboard_name      = try(aws_cloudwatch_dashboard.history_storage[0].dashboard_name, null)
    storage_throttle_alarm_arns = {
      for direction, alarm in aws_cloudwatch_metric_alarm.storage_throttles : direction => alarm.arn
    }
  }
}
