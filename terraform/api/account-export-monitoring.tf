variable "account_export_monitoring" {
  description = "Optional same-account/Region SNS destination for the disabled export candidate; verify support@andmorethings.com delivery before activation."
  type        = object({ alarm_topic_arn = string })
  default     = null
  validation {
    condition = var.account_export_monitoring == null ? true : try(
      var.account_export_deployment != null &&
      split(":", local.users_table_arn)[4] == data.aws_caller_identity.account_fence[0].account_id &&
      can(regex("^arn:aws:sns:${var.aws_region}:${split(":", local.users_table_arn)[4]}:[A-Za-z0-9_-]+$", var.account_export_monitoring.alarm_topic_arn)), false
    )
    error_message = "Export monitoring requires its pinned candidate and an exact same-account/Region standard SNS topic."
  }
}

resource "aws_cloudwatch_metric_alarm" "account_export_runtime" {
  for_each            = var.account_export_monitoring == null || var.account_export_deployment == null ? toset([]) : toset(["Errors", "Throttles"])
  alarm_name          = "${local.account_export_name}-${lower(each.key)}"
  alarm_description   = "Account export runtime failure; investigate without logging or replaying user export payloads."
  namespace           = "AWS/Lambda"
  metric_name         = each.key
  dimensions          = { FunctionName = aws_lambda_function.account_export[0].function_name }
  period              = 300
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.account_export_monitoring.alarm_topic_arn]
  ok_actions          = [var.account_export_monitoring.alarm_topic_arn]
  tags                = local.common_tags
}

# Handled storage/key/configuration failures return 503 without incrementing
# Lambda Errors. The handler emits exactly these bounded Operation dimensions.
resource "aws_cloudwatch_metric_alarm" "account_export_unavailable" {
  for_each            = var.account_export_monitoring == null || var.account_export_deployment == null ? toset([]) : toset(["start", "continue", "unknown"])
  alarm_name          = "${local.account_export_name}-${each.key}-unavailable"
  alarm_description   = "Account export ${each.key} returned unavailable. Reauthentication, expiry and ordinary size rejections are separate metrics."
  namespace           = "AMT/TrustCheckRadar/AccountExport"
  metric_name         = "AccountExportUnavailable"
  dimensions          = { Environment = var.environment, Operation = each.key }
  period              = 300
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.account_export_monitoring.alarm_topic_arn]
  ok_actions          = [var.account_export_monitoring.alarm_topic_arn]
  tags                = local.common_tags
}
