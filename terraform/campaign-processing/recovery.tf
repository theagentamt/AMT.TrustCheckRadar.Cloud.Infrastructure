variable "campaign_recovery_preparation" {
  description = "Prepare disabled scheduled cleanup recovery against a reviewed sparse ledger index. This cannot enable recovery or qualify historical coverage."
  type        = object({ review_reference = string })
  default     = null
  validation {
    condition = var.campaign_recovery_preparation == null ? true : try(
      local.account_privacy_candidate && var.kill_switch_enabled &&
      length(trimspace(var.campaign_recovery_preparation.review_reference)) > 0 &&
      local.foundation.campaign_recovery.schema_version == 1 && local.foundation.campaign_recovery.enabled &&
      local.foundation.campaign_recovery.environment == var.environment &&
      local.foundation.campaign_recovery.table_name == local.foundation.deletion_ledger_table_name &&
      local.foundation.campaign_recovery.table_arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-${var.environment}-deletion-ledger" &&
      local.foundation.campaign_recovery.index_name == "CampaignRecoveryDueIndex" &&
      local.foundation.campaign_recovery.index_arn == "${local.foundation.campaign_recovery.table_arn}/index/CampaignRecoveryDueIndex" &&
      local.foundation.campaign_recovery.partition_key == "campaignRecoveryPartition" &&
      local.foundation.campaign_recovery.sort_key == "nextAttemptAtEpoch" &&
      local.foundation.campaign_recovery.projection == "KEYS_ONLY" && local.foundation.campaign_recovery.shard_count == 16,
      false
    )
    error_message = "Recovery preparation requires paused immutable campaign candidates and the exact same-account sparse ledger index contract."
  }
}

locals {
  recovery_prepared = var.campaign_recovery_preparation != null
  recovery_shards   = [for shard in range(16) : "CAMPAIGN_RECOVERY#${var.environment}#${format("%02d", shard)}"]
}

data "aws_iam_policy_document" "recovery_runtime" {
  count = local.recovery_prepared ? 1 : 0
  statement {
    sid       = "DiscoverDueCampaignRecoveryKeys"
    actions   = ["dynamodb:Query"]
    resources = [local.foundation.campaign_recovery.index_arn]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = local.recovery_shards
    }
  }
  statement {
    sid       = "ReadCampaignRecoveryInventory"
    actions   = ["dynamodb:GetItem"]
    resources = [local.foundation.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["INVENTORY#${var.environment}"]
    }
  }
  statement {
    sid       = "CheckCampaignRecoveryInventory"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [local.foundation.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["INVENTORY#${var.environment}"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
  statement {
    sid       = "AdvanceOwnedRecoveryRetryTransaction"
    actions   = ["dynamodb:UpdateItem"]
    resources = [local.foundation.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCOUNT#*"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
  }
}

resource "aws_iam_role_policy" "recovery_runtime" {
  count  = local.recovery_prepared ? 1 : 0
  name   = "campaign-recovery-candidate"
  role   = aws_iam_role.worker["deletion"].id
  policy = data.aws_iam_policy_document.recovery_runtime[0].json
}

data "aws_iam_policy_document" "recovery_scheduler_assume" {
  count = local.recovery_prepared ? 1 : 0
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
resource "aws_iam_role" "recovery_scheduler" {
  count              = local.recovery_prepared ? 1 : 0
  name               = "${local.name_prefix}-recovery-scheduler"
  assume_role_policy = data.aws_iam_policy_document.recovery_scheduler_assume[0].json
  tags               = local.common_tags
}
data "aws_iam_policy_document" "recovery_scheduler_invoke" {
  count = local.recovery_prepared ? 1 : 0
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.worker["deletion"].arn]
  }
}
resource "aws_iam_role_policy" "recovery_scheduler_invoke" {
  count  = local.recovery_prepared ? 1 : 0
  name   = "invoke-campaign-recovery"
  role   = aws_iam_role.recovery_scheduler[0].id
  policy = data.aws_iam_policy_document.recovery_scheduler_invoke[0].json
}
resource "aws_scheduler_schedule" "recovery" {
  count                        = local.recovery_prepared ? 1 : 0
  name                         = "${local.name_prefix}-reconcile-cleanup"
  group_name                   = aws_scheduler_schedule_group.campaign[0].name
  schedule_expression          = "rate(5 minutes)"
  schedule_expression_timezone = "Etc/UTC"
  state                        = "DISABLED"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_function.worker["deletion"].arn
    role_arn = aws_iam_role.recovery_scheduler[0].arn
    input    = jsonencode({ schemaVersion = 1, operation = "reconcile-campaign-cleanup" })
    retry_policy {
      maximum_event_age_in_seconds = 300
      maximum_retry_attempts       = 0
    }
  }
  depends_on = [aws_iam_role_policy.recovery_scheduler_invoke, aws_iam_role_policy.recovery_runtime]
}
resource "aws_lambda_function_event_invoke_config" "recovery" {
  count                        = local.recovery_prepared ? 1 : 0
  function_name                = aws_lambda_function.worker["deletion"].function_name
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 0
}
resource "aws_cloudwatch_metric_alarm" "recovery" {
  for_each = local.recovery_prepared ? {
    budget      = { metric = "RecoveryBudgetExhausted", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    truncated   = { metric = "RecoveryShardTruncated", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    heartbeat   = { metric = "RecoveryTicks", statistic = "Sum", threshold = 1, comparison = "LessThanThreshold", periods = 3, missing = "breaching" }
    failures    = { metric = "RecoveryFailures", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    unverified  = { metric = "CommandsUnverified", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    schema      = { metric = "SidecarSchemaFailures", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
    pending_age = { metric = "ObservedPendingAgeSeconds", statistic = "Maximum", threshold = 72000, comparison = "GreaterThanOrEqualToThreshold", periods = 1, missing = "notBreaching" }
    overdue     = { metric = "ObservedOverdueCommands", statistic = "Sum", threshold = 0, comparison = "GreaterThanThreshold", periods = 1, missing = "notBreaching" }
  } : {}
  alarm_name          = "${local.name_prefix}-recovery-${replace(each.key, "_", "-")}"
  alarm_description   = "Campaign recovery ${each.key}; observed work only, not full coverage or completed erasure. Candidate actions remain disabled."
  namespace           = "TrustCheckRadar/Campaign"
  metric_name         = each.value.metric
  statistic           = each.value.statistic
  period              = 300
  evaluation_periods  = each.value.periods
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison
  treat_missing_data  = each.value.missing
  actions_enabled     = false
  alarm_actions       = [local.campaign.budget_alert_topic_arn]
  dimensions          = { Environment = var.environment }
  tags                = local.common_tags
}
output "campaign_recovery_preparation_contract" {
  value = {
    prepared                      = local.recovery_prepared
    recovery_enabled              = false
    producer_writes_enabled       = false
    historical_coverage_qualified = false
    schedule_enabled              = false
    alarm_actions_enabled         = false
  }
}
