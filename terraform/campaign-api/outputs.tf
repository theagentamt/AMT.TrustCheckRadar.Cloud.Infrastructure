output "campaign_api_enabled" {
  description = "Whether the app-facing campaign trends route is enabled"
  value       = local.enabled
}

output "campaign_review_api_enabled" {
  description = "Whether the internal campaign review route is enabled"
  value       = var.campaign_review_api_enabled
}

output "downstream_contract" {
  description = "Versioned campaign route and function identifiers"
  value = {
    schema_version      = 1
    environment         = var.environment
    trends_enabled      = local.enabled
    trends_route_key    = local.enabled ? aws_apigatewayv2_route.trends[0].route_key : null
    trends_function_arn = local.enabled ? aws_lambda_function.trends[0].arn : null
    trends_path         = var.trends_path
    review_enabled      = var.campaign_review_api_enabled
    review_route_key    = var.campaign_review_api_enabled ? aws_apigatewayv2_route.review[0].route_key : null
    review_function_arn = var.campaign_review_api_enabled ? aws_lambda_function.review[0].arn : null
    review_path         = var.review_path
    dashboard_name      = local.any_enabled ? aws_cloudwatch_dashboard.api[0].dashboard_name : null
  }
}
