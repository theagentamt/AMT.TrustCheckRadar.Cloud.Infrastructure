output "lifecycle_contract" {
  value = {
    schema_version   = 1
    environment      = var.environment
    deployed         = var.lifecycle_deployment_enabled
    active           = var.lifecycle_active
    function_arn     = try(aws_lambda_function.lifecycle[0].arn, null)
    schedule_arn     = try(aws_cloudwatch_event_rule.sweep[0].arn, null)
    metric_namespace = "AMT/TrustCheckRadar/History"
  }
}
