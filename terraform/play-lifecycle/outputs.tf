output "candidate_contract" {
  value = {
    provisioned                   = var.enabled
    token_table_name              = try(aws_dynamodb_table.tokens[0].name, null)
    token_table_arn               = try(aws_dynamodb_table.tokens[0].arn, null)
    token_kms_key_arn             = try(aws_kms_key.tokens[0].arn, null)
    application_context_keys      = local.context_keys
    token_retention_seconds       = 604800
    pitr_enabled                  = false
    ttl_is_only_cleanup_backstop  = true
    token_stream_enabled          = false
    runtime_aliases               = { for name, alias in aws_lambda_alias.runtime : name => alias.arn }
    notification_endpoint         = try("${aws_apigatewayv2_api.notification[0].api_endpoint}/v1/notifications/google-play", null)
    lifecycle_active              = false
    google_transport_provisioned  = false
    account_backup_audit_required = true
  }
}
