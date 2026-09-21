variable "account_data_monitoring" {
  description = "Opt-in account-deletion alarms. Requires an approved same-account/Region standard SNS topic; delivery acceptance remains a deployment prerequisite."
  type        = object({ alarm_topic_arn = string })
  default     = null
  validation {
    condition = var.account_data_monitoring == null ? true : (
      var.account_data_deployment != null &&
      try(split(":", local.users_table_arn)[4] == data.aws_caller_identity.account_fence[0].account_id, false) &&
      can(regex("^arn:aws:sns:${var.aws_region}:${split(":", local.users_table_arn)[4]}:[A-Za-z0-9_-]+$", var.account_data_monitoring.alarm_topic_arn))
    )
    error_message = "Account-data monitoring requires a pinned candidate and a same-account/Region standard SNS topic."
  }
}

locals {
  account_data_function_alarm_specs = var.account_data_monitoring == null || var.account_data_deployment == null ? {} : {
    errors    = { metric = "Errors", statistic = "Sum", threshold = 0, unit = "Count" }
    throttles = { metric = "Throttles", statistic = "Sum", threshold = 0, unit = "Count" }
    lag       = { metric = "IteratorAge", statistic = "Maximum", threshold = 300000, unit = "Milliseconds" }
  }
  account_data_reconciliation_alarm_specs = var.account_data_monitoring == null || var.account_data_deployment == null ? {} : {
    heartbeat       = { metric = "SessionRevocationReconciliationSuccess", operator = "LessThanThreshold", threshold = 1, period = 300, periods = 3, missing = "breaching", statistic = "Sum", unit = "Count", scheduled = true }
    failure         = { metric = "SessionRevocationReconciliationFailure", operator = "GreaterThanThreshold", threshold = 0, period = 300, periods = 1, missing = "notBreaching", statistic = "Sum", unit = "Count", scheduled = false }
    command_failure = { metric = "AccountDeletionReconciliationCommandFailures", operator = "GreaterThanThreshold", threshold = 0, period = 300, periods = 1, missing = "notBreaching", statistic = "Sum", unit = "Count", scheduled = false }
    pass_failure    = { metric = "AccountDeletionReconciliationPassFailures", operator = "GreaterThanThreshold", threshold = 0, period = 300, periods = 1, missing = "notBreaching", statistic = "Sum", unit = "Count", scheduled = false }
    no_full_pass    = { metric = "SessionRevocationReconciliationFullPassCompleted", operator = "LessThanThreshold", threshold = 1, period = 21600, periods = 1, missing = "breaching", statistic = "Sum", unit = "Count", scheduled = true }
    stale_full_pass = { metric = "SessionRevocationReconciliationFullPassAgeSeconds", operator = "GreaterThanOrEqualToThreshold", threshold = 21600, period = 300, periods = 1, missing = "notBreaching", statistic = "Maximum", unit = "Seconds", scheduled = true }
    policy_blocked  = { metric = "AccountDeletionAnalysisAbusePolicyBlocked", operator = "GreaterThanThreshold", threshold = 0, period = 300, periods = 1, missing = "notBreaching", statistic = "Sum", unit = "Count", scheduled = false }
    outbox_blocked  = { metric = "AccountDeletionCampaignOutboxPolicyBlocked", operator = "GreaterThanThreshold", threshold = 0, period = 300, periods = 1, missing = "notBreaching", statistic = "Sum", unit = "Count", scheduled = false }
    profile_blocked = { metric = "AccountDeletionUserProfilePolicyBlocked", operator = "GreaterThanThreshold", threshold = 0, period = 300, periods = 1, missing = "notBreaching", statistic = "Sum", unit = "Count", scheduled = false }
  }
}

resource "aws_cloudwatch_metric_alarm" "account_data_function" {
  for_each            = local.account_data_function_alarm_specs
  alarm_name          = "${local.account_data_name}-${each.key}"
  alarm_description   = "Account deletion worker failure or stream lag. Preserve deletion fences and follow HISTORY-OPERATIONS.md."
  namespace           = "AWS/Lambda"
  metric_name         = each.value.metric
  dimensions          = { FunctionName = aws_lambda_function.account_data[0].function_name }
  period              = 300
  statistic           = each.value.statistic
  unit                = each.value.unit
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.account_data_monitoring.alarm_topic_arn]
  ok_actions          = [var.account_data_monitoring.alarm_topic_arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "account_data_reconciliation" {
  for_each            = local.account_data_reconciliation_alarm_specs
  alarm_name          = "${local.account_data_name}-reconciliation-${each.key}"
  alarm_description   = "Account deletion reconciliation ${each.key}; investigate before the 24-hour erasure deadline. A successful scan is not full account erasure."
  namespace           = "AMT/TrustCheckRadar/AccountData"
  metric_name         = each.value.metric
  dimensions          = { Environment = var.environment }
  period              = each.value.period
  statistic           = each.value.statistic
  unit                = each.value.unit
  threshold           = each.value.threshold
  comparison_operator = each.value.operator
  evaluation_periods  = each.value.periods
  datapoints_to_alarm = each.value.periods
  # A deliberately disabled candidate has no successful scheduled heartbeat.
  actions_enabled    = !each.value.scheduled || aws_cloudwatch_event_rule.account_data_reconcile[0].state == "ENABLED"
  treat_missing_data = each.value.scheduled && aws_cloudwatch_event_rule.account_data_reconcile[0].state != "ENABLED" ? "notBreaching" : each.value.missing
  alarm_actions      = [var.account_data_monitoring.alarm_topic_arn]
  ok_actions         = [var.account_data_monitoring.alarm_topic_arn]
  tags               = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "account_data_stream_failure" {
  count               = var.account_data_monitoring == null || var.account_data_deployment == null ? 0 : 1
  alarm_name          = "${local.account_data_name}-session-revocation-failure"
  alarm_description   = "Account deletion stream reported a partial batch failure, which need not increment Lambda Errors. Preserve the durable command and investigate retries."
  namespace           = "AMT/TrustCheckRadar/AccountData"
  metric_name         = "AccountDeletionFailure"
  dimensions          = { Environment = var.environment, Operation = "session-revocation" }
  period              = 300
  statistic           = "Sum"
  unit                = "Count"
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.account_data_monitoring.alarm_topic_arn]
  ok_actions          = [var.account_data_monitoring.alarm_topic_arn]
  tags                = local.common_tags
}
