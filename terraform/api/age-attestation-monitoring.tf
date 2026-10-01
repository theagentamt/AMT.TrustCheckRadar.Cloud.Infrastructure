locals {
  age_attestation_monitoring_enabled = local.age_attestation_authority_enabled && var.age_attestation_monitoring != null
}

resource "aws_cloudwatch_metric_alarm" "age_attestation_lambda" {
  for_each            = local.age_attestation_monitoring_enabled ? toset(["Errors", "Throttles"]) : toset([])
  alarm_name          = "${local.lambda_name}-${lower(each.key)}"
  alarm_description   = "Age-attestation ${lower(each.key)} detected. Investigate with bounded operational metadata; never include tokens, phone numbers or attestation payloads in notifications."
  namespace           = "AWS/Lambda"
  metric_name         = each.key
  dimensions          = { FunctionName = aws_lambda_function.age_attestation.function_name }
  period              = 300
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.age_attestation_monitoring.alarm_topic_arn]
  ok_actions          = [var.age_attestation_monitoring.alarm_topic_arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "age_attestation_api_5xx" {
  count             = local.age_attestation_monitoring_enabled ? 1 : 0
  alarm_name        = "${local.name_prefix}-age-attestation-api-5xx"
  alarm_description = "The age-attestation route returned a 5xx response. Investigate without logging or replaying user payloads."
  namespace         = "AWS/ApiGateway"
  metric_name       = "5xx"
  dimensions = {
    ApiId = aws_apigatewayv2_api.age_attestation.id
    Route = aws_apigatewayv2_route.age_attestation.route_key
    Stage = aws_apigatewayv2_stage.age_attestation.name
  }
  period              = 300
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.age_attestation_monitoring.alarm_topic_arn]
  ok_actions          = [var.age_attestation_monitoring.alarm_topic_arn]
  tags                = local.common_tags
}
