output "downstream_contract" {
  description = "Private invocation contract; contains no public URL or provider secret."
  value = {
    schema_version                = 1
    enabled                       = var.enabled
    environment                   = var.environment
    function_name                 = var.enabled ? aws_lambda_function.resolver[0].function_name : null
    invoke_arn                    = var.enabled ? aws_lambda_alias.resolver[0].arn : null
    log_group_name                = var.enabled ? aws_cloudwatch_log_group.resolver[0].name : null
    outbound_ip                   = var.enabled ? aws_eip.nat[0].public_ip : null
    caller_roles                  = var.enabled ? var.caller_role_names : toset([])
    dev_test_role_arn             = var.enabled && var.dev_test_principal_arn != null ? aws_iam_role.dev_test[0].arn : null
    alert_topic_arn               = var.enabled ? aws_sns_topic.operations[0].arn : null
    email_subscription_configured = var.enabled && var.notification_email != null
    invocation                    = "RequestResponse"
    scope                         = "HTTP_REDIRECTS_ONLY"
  }
}
