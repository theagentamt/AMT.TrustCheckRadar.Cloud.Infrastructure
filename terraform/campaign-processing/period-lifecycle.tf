# A distinct schedule is required: legacy lifecycle events do not implement the
# authoritative work-index protocol. Preparation never activates either path.
data "aws_iam_policy_document" "period_lifecycle_scheduler_assume" {
  count = local.period_work_prepared ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_scheduler_schedule_group.campaign[0].arn]
    }
  }
}
resource "aws_iam_role" "period_lifecycle_scheduler" {
  count              = local.period_work_prepared ? 1 : 0
  name               = "${local.name_prefix}-period-scheduler"
  assume_role_policy = data.aws_iam_policy_document.period_lifecycle_scheduler_assume[0].json
  tags               = local.common_tags
}
data "aws_iam_policy_document" "period_lifecycle_scheduler_invoke" {
  count = local.period_work_prepared ? 1 : 0
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.worker["lifecycle"].arn]
  }
}
resource "aws_iam_role_policy" "period_lifecycle_scheduler_invoke" {
  count  = local.period_work_prepared ? 1 : 0
  name   = "invoke-period-lifecycle"
  role   = aws_iam_role.period_lifecycle_scheduler[0].id
  policy = data.aws_iam_policy_document.period_lifecycle_scheduler_invoke[0].json
}
resource "aws_scheduler_schedule" "period_lifecycle" {
  count                        = local.period_work_prepared ? 1 : 0
  name                         = "${local.name_prefix}-reconcile-periods"
  group_name                   = aws_scheduler_schedule_group.campaign[0].name
  schedule_expression          = "rate(5 minutes)"
  schedule_expression_timezone = "Etc/UTC"
  state                        = local.period_lifecycle_active ? "ENABLED" : "DISABLED"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_function.worker["lifecycle"].arn
    role_arn = aws_iam_role.period_lifecycle_scheduler[0].arn
    input    = jsonencode({ schemaVersion = 1, environment = var.environment, operation = "reconcile_periods" })
    retry_policy {
      maximum_event_age_in_seconds = 300
      maximum_retry_attempts       = 0
    }
  }
  depends_on = [aws_iam_role_policy.period_lifecycle_scheduler_invoke, aws_iam_role_policy_attachment.period_work, aws_iam_role_policy.period_admission, aws_iam_role_policy.lifecycle_runtime, aws_iam_role_policy_attachment.aggregate_expiry]
}
resource "aws_lambda_function_event_invoke_config" "period_lifecycle" {
  count                        = local.period_work_prepared ? 1 : 0
  function_name                = aws_lambda_function.worker["lifecycle"].function_name
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 0
}
resource "aws_cloudwatch_metric_alarm" "period_lifecycle" {
  for_each = local.period_work_prepared ? {
    heartbeat  = { metric = "LifecycleHeartbeat", statistic = "Sum", threshold = 1, comparison = "LessThanThreshold", periods = 3, missing = "breaching" }
    failures   = { metric = "LifecycleFailures", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    unverified = { metric = "LifecycleWorkUnverified", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    stalled    = { metric = "LifecycleProgressAgeSeconds", statistic = "Maximum", threshold = 3600, comparison = "GreaterThanOrEqualToThreshold", periods = 1, missing = "notBreaching" }
    full_pass  = { metric = "LifecycleFullPassAgeSeconds", statistic = "Maximum", threshold = 7200, comparison = "GreaterThanOrEqualToThreshold", periods = 1, missing = "notBreaching" }
  } : {}
  alarm_name          = "${local.name_prefix}-period-${replace(each.key, "_", "-")}"
  alarm_description   = each.key == "stalled" ? "Observed overdue work with aged backlog; environment-wide signals do not prove the same record stalled. Future-only backlog does not alarm." : "Period lifecycle ${each.key}; bounded observed progress is not erasure proof. Disabled until reviewed lifecycle activation."
  namespace           = each.key == "stalled" ? null : "TrustCheckRadar/Campaign"
  metric_name         = each.key == "stalled" ? null : each.value.metric
  statistic           = each.key == "stalled" ? null : each.value.statistic
  period              = each.key == "stalled" ? null : 300
  evaluation_periods  = each.value.periods
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison
  treat_missing_data  = each.value.missing
  actions_enabled     = local.period_lifecycle_active
  alarm_actions       = [local.campaign.budget_alert_topic_arn]
  dimensions          = each.key == "stalled" ? null : { Environment = var.environment }
  dynamic "metric_query" {
    for_each = each.key == "stalled" ? [1] : []
    content {
      id          = "observed_overdue_age"
      expression  = "IF(overdue>0,age,0)"
      label       = "Observed overdue work with aged backlog"
      return_data = true
    }
  }
  dynamic "metric_query" {
    for_each = each.key == "stalled" ? {
      age     = { name = "LifecycleProgressAgeSeconds", stat = "Maximum" }
      overdue = { name = "PrivacyDeadlineMissed", stat = "Sum" }
    } : {}
    content {
      id          = metric_query.key
      return_data = false
      metric {
        namespace   = "TrustCheckRadar/Campaign"
        metric_name = metric_query.value.name
        period      = 300
        stat        = metric_query.value.stat
        dimensions  = { Environment = var.environment }
      }
    }
  }
  tags = local.common_tags
}
