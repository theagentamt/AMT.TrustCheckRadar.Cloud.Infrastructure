output "campaign_processing_enabled" {
  description = "Whether campaign processing resources are enabled"
  value       = local.enabled
}

output "kill_switch_enabled" {
  description = "Whether all campaign event sources and schedules are disabled"
  value       = var.kill_switch_enabled
}

output "downstream_contract" {
  description = "Versioned campaign processing identifiers"
  value = {
    schema_version         = 1
    environment            = var.environment
    enabled                = local.enabled
    active                 = local.active
    publisher_function_arn = local.enabled ? aws_lambda_function.worker["publisher"].arn : null
    feature_function_arn   = local.enabled ? aws_lambda_function.feature[0].arn : null
    cluster_function_arn   = local.enabled ? aws_lambda_function.worker["cluster"].arn : null
    lifecycle_function_arn = local.enabled ? aws_lambda_function.worker["lifecycle"].arn : null
    deletion_function_arn  = local.enabled ? aws_lambda_function.worker["deletion"].arn : null
    dashboard_name         = local.enabled ? aws_cloudwatch_dashboard.campaign[0].dashboard_name : null
    model_version          = var.model_version
    feature_image_digest   = var.feature_image_digest
  }
}
