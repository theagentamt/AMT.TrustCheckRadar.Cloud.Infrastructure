locals {
  # This is the existing confirmed Dev support@andmorethings.com alert path.
  # No new subscription or recipient is introduced by this candidate.
  alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
  runtime_alarms = merge(
    { for name, definition in local.functions : "${name}-errors" => { function = name, metric = "Errors", statistic = "Sum", threshold = 1 } },
    { for name, definition in local.functions : "${name}-throttles" => { function = name, metric = "Throttles", statistic = "Sum", threshold = 1 } },
    { for name, definition in local.functions : "${name}-duration" => { function = name, metric = "Duration", statistic = "Maximum", threshold = (definition.timeout - 3) * 1000 } }
  )
}

resource "aws_cloudwatch_metric_alarm" "runtime" {
  for_each            = local.runtime_alarms
  alarm_name          = "${local.prefix}-recovery-${each.key}"
  alarm_description   = "Inactive Dev candidate runtime ${each.value.metric}; reconcile the same check after uncertain completion. Native runtime metrics do not count assessment outcomes or deductions."
  namespace           = "AWS/Lambda"
  metric_name         = each.value.metric
  dimensions          = { FunctionName = aws_lambda_function.runtime[each.value.function].function_name }
  statistic           = each.value.statistic
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.alert_topic_arn]
  ok_actions          = [local.alert_topic_arn]
  tags                = var.tags
}
