locals {
  operational_fields = {
    ingress  = ["heartbeat", "failed", "unresolved"]
    worker   = ["heartbeat", "failed", "unresolved", "exhausted", "oldestDueSeconds"]
    deletion = ["heartbeat", "failed", "overdue", "fullPassAgeSeconds"]
  }
  operational_metrics = merge({}, [for component in keys(local.functions) : {
    for field in local.operational_fields[component] : "${component}-${field}" => {
      component = component
      field     = field
      event     = replace(local.functions[component].suffix, "-", "_")
    }
  }]...)
}
resource "aws_cloudwatch_log_metric_filter" "operational" {
  for_each       = local.operational_metrics
  name           = "${local.prefix}-play-${each.key}"
  log_group_name = aws_cloudwatch_log_group.runtime[each.value.component].name
  pattern        = "{ $.event = \"${each.value.event}\" && $.${each.value.field} = * }"
  metric_transformation {
    name      = each.key
    namespace = "TrustCheckRadar/dev/PlayLifecycle"
    value     = "$.${each.value.field}"
    unit      = endswith(each.value.field, "Seconds") ? "Seconds" : "Count"
  }
}
resource "aws_cloudwatch_metric_alarm" "operational" {
  for_each            = { for key, metric in local.operational_metrics : key => metric if key != "ingress-heartbeat" }
  alarm_name          = "${local.prefix}-play-${each.key}"
  namespace           = "TrustCheckRadar/dev/PlayLifecycle"
  metric_name         = aws_cloudwatch_log_metric_filter.operational[each.key].metric_transformation[0].name
  statistic           = each.value.field == "heartbeat" ? "Sum" : "Maximum"
  period              = 60
  evaluation_periods  = each.value.field == "heartbeat" ? 5 : 1
  threshold           = endswith(each.value.field, "Seconds") ? 600 : 1
  comparison_operator = each.value.field == "heartbeat" ? "LessThanThreshold" : "GreaterThanOrEqualToThreshold"
  treat_missing_data  = each.value.field == "heartbeat" ? "breaching" : "notBreaching"
  # Missing-heartbeat alerts are armed only alongside separately reviewed worker
  # activation; this candidate never schedules runtime execution.
  actions_enabled = each.value.field != "heartbeat"
  alarm_actions   = [var.alert_topic_arn]
  ok_actions      = [var.alert_topic_arn]
  tags            = var.tags
}
