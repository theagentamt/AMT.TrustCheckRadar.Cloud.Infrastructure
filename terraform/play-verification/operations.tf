variable "alert_topic_arn" {
  description = "Existing confirmed support topic; its owning stack must separately authorize these exact alarm ARNs."
  type        = string
  default     = null
  validation {
    condition     = var.alert_topic_arn == null || var.alert_topic_arn == "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
    error_message = "Use the reviewed existing Dev support topic."
  }
}
resource "aws_cloudwatch_metric_alarm" "runtime" {
  for_each            = var.enabled && var.alert_topic_arn != null ? toset(["Errors", "Throttles"]) : toset([])
  alarm_name          = "${local.name}-${lower(each.value)}"
  alarm_description   = "Inactive Play candidate runtime ${each.value}; does not measure business denials, provider outcomes or subscription reconciliation."
  namespace           = "AWS/Lambda"
  metric_name         = each.value
  dimensions          = { FunctionName = aws_lambda_function.runtime[0].function_name }
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]
  tags                = var.tags
}
