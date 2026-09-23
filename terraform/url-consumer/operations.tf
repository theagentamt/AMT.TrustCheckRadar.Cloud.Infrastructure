locals {
  monitored_functions = var.enabled && var.alert_topic_arn != null ? local.functions : {}
  worker_events       = { recovery = "url_lease_recovery", deletion = "v1_authority_deletion" }
  worker_monitors     = { for name, definition in local.monitored_functions : name => definition if contains(keys(local.worker_events), name) }
  runtime_alarms = merge(
    { for name, definition in local.monitored_functions : "${definition.suffix}-errors" => { function = name, metric = "Errors" } },
    { for name, definition in local.monitored_functions : "${definition.suffix}-throttles" => { function = name, metric = "Throttles" } }
  )
}
resource "aws_cloudwatch_metric_alarm" "runtime" {
  for_each            = local.runtime_alarms
  alarm_name          = "${local.prefix}-${each.key}"
  alarm_description   = "V1 Dev ${each.value.metric}; inspect fixed diagnostic counts, preserve deletion fences and reconcile uncertain checks."
  namespace           = "AWS/Lambda"
  metric_name         = each.value.metric
  dimensions          = { FunctionName = aws_lambda_function.runtime[each.value.function].function_name }
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
resource "aws_cloudwatch_log_metric_filter" "worker_failure" {
  for_each       = local.worker_monitors
  name           = "${local.prefix}-${each.value.suffix}-failure"
  log_group_name = aws_cloudwatch_log_group.runtime[each.key].name
  pattern        = "{ $.event = \"${local.worker_events[each.key]}\" && $.failed > 0 }"
  metric_transformation {
    name      = "${each.value.suffix}-failed"
    namespace = "AMT/TrustCheckRadar/V1/dev"
    value     = "$.failed"
    unit      = "Count"
  }
}
resource "aws_cloudwatch_log_metric_filter" "worker_heartbeat" {
  for_each       = local.worker_monitors
  name           = "${local.prefix}-${each.value.suffix}-heartbeat"
  log_group_name = aws_cloudwatch_log_group.runtime[each.key].name
  pattern        = "{ $.event = \"${local.worker_events[each.key]}\" && $.pages >= 0 }"
  metric_transformation {
    name      = "${each.value.suffix}-heartbeat"
    namespace = "AMT/TrustCheckRadar/V1/dev"
    value     = "1"
    unit      = "Count"
  }
}
resource "aws_cloudwatch_metric_alarm" "worker_failure" {
  for_each            = local.worker_monitors
  alarm_name          = "${local.prefix}-${each.value.suffix}-failed-items"
  namespace           = "AMT/TrustCheckRadar/V1/dev"
  metric_name         = aws_cloudwatch_log_metric_filter.worker_failure[each.key].metric_transformation[0].name
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
resource "aws_cloudwatch_metric_alarm" "worker_heartbeat" {
  for_each            = local.worker_monitors
  alarm_name          = "${local.prefix}-${each.value.suffix}-heartbeat"
  namespace           = "AMT/TrustCheckRadar/V1/dev"
  metric_name         = aws_cloudwatch_log_metric_filter.worker_heartbeat[each.key].metric_transformation[0].name
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  actions_enabled     = local.authority_engineering_active
  treat_missing_data  = local.authority_engineering_active ? "breaching" : "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]
  tags                = var.tags
}
resource "aws_cloudwatch_log_metric_filter" "deletion_overdue" {
  count          = contains(keys(local.worker_monitors), "deletion") ? 1 : 0
  name           = "${local.prefix}-v1-authority-deletion-overdue"
  log_group_name = aws_cloudwatch_log_group.runtime["deletion"].name
  pattern        = "{ $.event = \"v1_authority_deletion\" && $.overdue > 0 }"
  metric_transformation {
    name      = "v1-authority-deletion-overdue"
    namespace = "AMT/TrustCheckRadar/V1/dev"
    value     = "$.overdue"
    unit      = "Count"
  }
}
resource "aws_cloudwatch_metric_alarm" "deletion_overdue" {
  count               = length(aws_cloudwatch_log_metric_filter.deletion_overdue)
  alarm_name          = "${local.prefix}-v1-authority-deletion-overdue"
  namespace           = "AMT/TrustCheckRadar/V1/dev"
  metric_name         = "v1-authority-deletion-overdue"
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
resource "aws_cloudwatch_log_metric_filter" "deletion_full_pass_age" {
  count          = contains(keys(local.worker_monitors), "deletion") ? 1 : 0
  name           = "${local.prefix}-v1-authority-deletion-full-pass-age"
  log_group_name = aws_cloudwatch_log_group.runtime["deletion"].name
  pattern        = "{ $.event = \"v1_authority_deletion\" && $.fullPassAgeSeconds >= 0 }"
  metric_transformation {
    name      = "v1-authority-deletion-full-pass-age"
    namespace = "AMT/TrustCheckRadar/V1/dev"
    value     = "$.fullPassAgeSeconds"
    unit      = "Seconds"
  }
}
resource "aws_cloudwatch_metric_alarm" "deletion_full_pass_age" {
  count               = length(aws_cloudwatch_log_metric_filter.deletion_full_pass_age)
  alarm_name          = "${local.prefix}-v1-authority-deletion-full-pass-age"
  namespace           = "AMT/TrustCheckRadar/V1/dev"
  metric_name         = "v1-authority-deletion-full-pass-age"
  period              = 300
  statistic           = "Maximum"
  threshold           = 21600
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  actions_enabled     = local.authority_engineering_active
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]
  tags                = var.tags
}
resource "aws_cloudwatch_log_metric_filter" "expiry_overdue" {
  count          = contains(keys(local.worker_monitors), "recovery") ? 1 : 0
  name           = "${local.prefix}-url-lease-recovery-expiry-overdue"
  log_group_name = aws_cloudwatch_log_group.runtime["recovery"].name
  pattern        = "{ $.event = \"url_lease_recovery\" && $.oldestOverdueSeconds >= 0 }"
  metric_transformation {
    name      = "url-lease-recovery-expiry-overdue"
    namespace = "AMT/TrustCheckRadar/V1/dev"
    value     = "$.oldestOverdueSeconds"
    unit      = "Seconds"
  }
}
resource "aws_cloudwatch_metric_alarm" "expiry_overdue" {
  count               = length(aws_cloudwatch_log_metric_filter.expiry_overdue)
  alarm_name          = "${local.prefix}-url-lease-recovery-expiry-overdue"
  namespace           = "AMT/TrustCheckRadar/V1/dev"
  metric_name         = "url-lease-recovery-expiry-overdue"
  period              = 60
  statistic           = "Maximum"
  threshold           = 300
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  actions_enabled     = local.authority_engineering_active
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]
  tags                = var.tags
}
