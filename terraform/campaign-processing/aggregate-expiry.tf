# Anonymous aggregates retain their original 400-day deadline. A sparse index
# supports bounded explicit deletion independently of period-key retirement.
data "aws_iam_policy_document" "aggregate_expiry" {
  count = local.period_work_prepared ? 1 : 0
  statement {
    sid       = "VerifyAggregateTableIdentity"
    actions   = ["dynamodb:DescribeTable"]
    resources = [local.campaign.intelligence_table_arn]
  }
  statement {
    sid       = "DiscoverExpiredAnonymousAggregates"
    actions   = ["dynamodb:Query"]
    resources = ["${local.campaign.intelligence_table_arn}/index/ExpirationIndex"]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = [for shard in range(16) : format("EXPIRY#%s#%02d", var.environment, shard)]
    }
  }
  statement {
    sid       = "ReadAnonymousAggregateProgress"
    actions   = ["dynamodb:GetItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["AGGREGATE_SWEEP#${var.environment}"]
    }
  }
  statement {
    sid       = "PersistAnonymousAggregateProgress"
    actions   = ["dynamodb:PutItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["AGGREGATE_SWEEP#${var.environment}"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
}
resource "aws_iam_policy" "aggregate_expiry" {
  count  = local.period_work_prepared ? 1 : 0
  name   = "${local.name_prefix}-aggregate-expiry"
  policy = data.aws_iam_policy_document.aggregate_expiry[0].json
  tags   = local.common_tags
}
resource "aws_iam_role_policy_attachment" "aggregate_expiry" {
  count      = local.period_work_prepared ? 1 : 0
  role       = aws_iam_role.worker["lifecycle"].id
  policy_arn = aws_iam_policy.aggregate_expiry[0].arn
}
resource "aws_cloudwatch_metric_alarm" "aggregate_expiry" {
  for_each = local.period_work_prepared ? {
    heartbeat  = { metric = "AggregateHeartbeat", statistic = "Sum", threshold = 1, comparison = "LessThanThreshold", periods = 3, missing = "breaching" }
    failures   = { metric = "AggregateFailures", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    unverified = { metric = "AggregateWorkUnverified", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    full_pass  = { metric = "AggregateFullPassAgeSeconds", statistic = "Maximum", threshold = 7200, comparison = "GreaterThanOrEqualToThreshold", periods = 1, missing = "notBreaching" }
  } : {}
  alarm_name          = "${local.name_prefix}-aggregate-${replace(each.key, "_", "-")}"
  alarm_description   = "Anonymous aggregate expiry ${each.key}; no erasure or historical-copy claim."
  namespace           = "TrustCheckRadar/Campaign"
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  period              = 300
  evaluation_periods  = each.value.periods
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison
  treat_missing_data  = each.value.missing
  actions_enabled     = local.period_lifecycle_active
  alarm_actions       = [local.campaign.budget_alert_topic_arn]
  dimensions          = { Environment = var.environment }
  tags                = local.common_tags
}

# Separate invocations prevent a busy period sweep from starving aggregate expiry.
resource "aws_scheduler_schedule" "aggregate_expiry" {
  count                        = local.period_work_prepared ? 1 : 0
  name                         = "${local.name_prefix}-reconcile-aggregates"
  group_name                   = aws_scheduler_schedule_group.campaign[0].name
  schedule_expression          = "rate(5 minutes)"
  schedule_expression_timezone = "Etc/UTC"
  state                        = local.period_lifecycle_active ? "ENABLED" : "DISABLED"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_function.worker["lifecycle"].arn
    role_arn = aws_iam_role.period_lifecycle_scheduler[0].arn
    input    = jsonencode({ schemaVersion = 1, environment = var.environment, operation = "reconcile_aggregates" })
    retry_policy {
      maximum_event_age_in_seconds = 300
      maximum_retry_attempts       = 0
    }
  }
  depends_on = [aws_iam_role_policy.period_lifecycle_scheduler_invoke, aws_iam_role_policy_attachment.aggregate_expiry, aws_iam_role_policy_attachment.period_work, aws_iam_role_policy.lifecycle_runtime]
}
