locals {
  failure_reasons = [
    "PROVIDER_AUTHORIZATION_FAILED", "PROVIDER_RATE_LIMITED", "PROVIDER_UNAVAILABLE", "PROVIDER_RESPONSE_INVALID",
    "SECRET_UNAVAILABLE", "CONFIGURATION_UNAVAILABLE", "RESOLVER_UNAVAILABLE", "RESOLVER_RESPONSE_INVALID",
    "TIME_BUDGET_EXCEEDED", "INTERNAL_ERROR"
  ]
}
resource "aws_cloudwatch_log_metric_filter" "dependency_failures" {
  count          = var.enabled ? 1 : 0
  name           = "${local.name}-dependency-failures"
  log_group_name = aws_cloudwatch_log_group.assessment[0].name
  pattern        = "{ $.event = \"private_url_assessment\" && (${join(" || ", [for reason in local.failure_reasons : "$.reason = ${jsonencode(reason)}"])}) }"
  metric_transformation {
    name          = "DependencyFailures"
    namespace     = "AMT/URLAssessment/${var.environment}"
    value         = "1"
    default_value = 0
  }
}
resource "aws_cloudwatch_metric_alarm" "dependency_failures" {
  count               = var.enabled ? 1 : 0
  alarm_name          = "${local.name}-dependency-failures"
  namespace           = "AMT/URLAssessment/${var.environment}"
  metric_name         = "DependencyFailures"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]
  lifecycle {
    precondition {
      condition     = var.alert_topic_arn == "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-url-resolver-alerts"
      error_message = "Use only this environment's confirmed resolver alert topic."
    }
  }
  tags = var.tags
}
resource "aws_cloudwatch_metric_alarm" "runtime" {
  for_each            = var.enabled ? toset(["Errors", "Throttles"]) : toset([])
  alarm_name          = "${local.name}-${lower(each.key)}"
  namespace           = "AWS/Lambda"
  metric_name         = each.key
  dimensions          = { FunctionName = local.name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]
  tags                = var.tags
}
