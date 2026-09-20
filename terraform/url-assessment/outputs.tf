output "operator_contract" {
  value = {
    enabled             = var.enabled
    environment         = var.environment
    consumer_endpoint   = null
    consumer_activation = false
    invocation          = "RequestResponse"
    function_name       = var.enabled ? aws_lambda_function.assessment[0].function_name : null
    alias_arn           = var.enabled ? aws_lambda_alias.assessment[0].arn : null
    log_group_name      = var.enabled ? aws_cloudwatch_log_group.assessment[0].name : null
    dev_test_role_arn   = var.enabled && var.dev_test_principal_arn != null ? aws_iam_role.dev_test[0].arn : null
  }
}
