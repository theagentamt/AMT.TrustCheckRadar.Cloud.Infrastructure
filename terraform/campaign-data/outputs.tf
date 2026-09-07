output "campaign_intelligence_enabled" {
  description = "Whether campaign data-plane resources are enabled"
  value       = local.enabled
}

output "downstream_contract" {
  description = "Versioned values consumed by campaign processing and API stacks"
  value = {
    schema_version          = 1
    environment             = var.environment
    enabled                 = local.enabled
    outbox_table_name       = local.enabled ? aws_dynamodb_table.outbox[0].name : null
    outbox_table_arn        = local.enabled ? aws_dynamodb_table.outbox[0].arn : null
    outbox_stream_arn       = local.enabled ? aws_dynamodb_table.outbox[0].stream_arn : null
    pipeline_table_name     = local.enabled ? aws_dynamodb_table.pipeline[0].name : null
    pipeline_table_arn      = local.enabled ? aws_dynamodb_table.pipeline[0].arn : null
    expiration_index_name   = "ExpirationIndex"
    intelligence_table_name = local.enabled ? aws_dynamodb_table.intelligence[0].name : null
    intelligence_table_arn  = local.enabled ? aws_dynamodb_table.intelligence[0].arn : null
    publication_index_name  = "PublicationIndex"
    cluster_queue_url       = local.enabled ? aws_sqs_queue.cluster[0].id : null
    cluster_queue_arn       = local.enabled ? aws_sqs_queue.cluster[0].arn : null
    cluster_dlq_arn         = local.enabled ? aws_sqs_queue.cluster_dlq[0].arn : null
    transient_kms_key_arn   = local.enabled ? aws_kms_key.transient[0].arn : null
    persistent_kms_key_arn  = local.enabled ? aws_kms_key.persistent[0].arn : null
    budget_alert_topic_arn  = local.enabled ? aws_sns_topic.budget[0].arn : null
    budget_limit_usd        = var.campaign_budget_limit_usd
  }
}
