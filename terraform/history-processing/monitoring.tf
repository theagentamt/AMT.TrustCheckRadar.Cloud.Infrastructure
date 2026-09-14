locals {
  lifecycle_alarm_specs = var.lifecycle_active ? {
    heartbeat  = { metric = "LifecycleSweepSuccess", operator = "LessThanThreshold", threshold = 1, periods = 2, missing = "breaching", stat = "Sum", unit = "Count" }
    failure    = { metric = "LifecycleSweepFailure", operator = "GreaterThanThreshold", threshold = 0, periods = 1, missing = "notBreaching", stat = "Sum", unit = "Count" }
    truncated  = { metric = "LifecycleWorksetTruncated", operator = "GreaterThanThreshold", threshold = 0, periods = 1, missing = "notBreaching", stat = "Sum", unit = "Count" }
    stuck      = { metric = "StuckPendingCompletions", operator = "GreaterThanThreshold", threshold = 0, periods = 1, missing = "notBreaching", stat = "Sum", unit = "Count" }
    overdue    = { metric = "OverdueErasureJobs", operator = "GreaterThanThreshold", threshold = 0, periods = 1, missing = "notBreaching", stat = "Sum", unit = "Count" }
    expiry_sla = { metric = "ExpirationCheckpointLagSeconds", operator = "GreaterThanOrEqualToThreshold", threshold = 86400, periods = 1, missing = "missing", stat = "Maximum", unit = "Seconds" }
  } : {}
}

resource "aws_cloudwatch_metric_alarm" "lifecycle" {
  for_each            = local.lifecycle_alarm_specs
  alarm_name          = "${local.name}-${each.key}"
  alarm_description   = "History lifecycle ${each.key}; follow the privacy-safe History operations runbook."
  namespace           = "AMT/TrustCheckRadar/History"
  metric_name         = each.value.metric
  dimensions          = { Environment = var.environment }
  period              = 300
  statistic           = each.value.stat
  unit                = each.value.unit
  threshold           = each.value.threshold
  comparison_operator = each.value.operator
  evaluation_periods  = each.value.periods
  datapoints_to_alarm = each.value.periods
  treat_missing_data  = each.value.missing
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "function" {
  for_each            = var.lifecycle_active ? toset(["Errors", "Throttles"]) : toset([])
  alarm_name          = "${local.name}-${lower(each.key)}"
  namespace           = "AWS/Lambda"
  metric_name         = each.key
  dimensions          = { FunctionName = aws_lambda_function.lifecycle[0].function_name }
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  tags                = local.common_tags
}
