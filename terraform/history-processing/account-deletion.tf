variable "account_deletion_artifact" {
  description = "Optional version-pinned History account-deletion bridge; must match the lifecycle release."
  type        = object({ release_id = string, object_version = string, source_hash = string })
  default     = null
  validation {
    condition = var.account_deletion_artifact == null ? true : try(
      var.lifecycle_deployment_enabled && var.account_deletion_artifact.release_id == var.artifact.release_id &&
      length(trimspace(var.account_deletion_artifact.object_version)) > 0 && var.account_deletion_artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.account_deletion_artifact.source_hash)), false
    )
    error_message = "The bridge requires a version/hash-pinned artifact from the same deployed lifecycle release."
  }
}

variable "account_deletion_terminal_candidate" {
  description = "Prepare the corrected terminal-fence bridge on Python 3.14 with transactional receipts. Preparation stays inactive unless separately qualified terminal activation is selected."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition     = !var.account_deletion_terminal_candidate || var.account_deletion_artifact != null
    error_message = "The terminal-fence candidate requires a pinned bridge artifact."
  }
}

variable "account_deletion_active" {
  description = "Enable the deletion stream only after account-fence producer, outage recovery, alert delivery and erasure acceptance."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition     = !var.account_deletion_active || (var.account_deletion_artifact != null && var.lifecycle_active && var.account_deletion_observability_approved && var.account_deletion_terminal_activation != null)
    error_message = "Account deletion activation requires the deployed bridge, active lifecycle cleanup and verified reconciliation metrics/alert delivery."
  }
}

variable "account_deletion_observability_approved" {
  description = "Confirm the pinned bridge emits reconciliation/full-pass metrics and the notification path has passed acceptance."
  type        = bool
  default     = false
  nullable    = false
}

locals {
  account_deletion_deployed = local.deployed && var.account_deletion_artifact != null
  account_deletion_name     = "${var.project_name}-${var.environment}-history-account-deletion-bridge"
}

resource "aws_cloudwatch_log_group" "account_deletion" {
  count             = local.account_deletion_deployed ? 1 : 0
  name              = "/aws/lambda/${local.account_deletion_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_iam_role" "account_deletion" {
  count              = local.account_deletion_deployed ? 1 : 0
  name               = "${local.account_deletion_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "account_deletion" {
  count = local.account_deletion_deployed ? 1 : 0
  dynamic "statement" {
    for_each = var.account_deletion_terminal_candidate ? [1] : []
    content {
      sid       = "CheckHistoryStateForCompletion"
      actions   = ["dynamodb:ConditionCheckItem"]
      resources = [local.history.control_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["USER#*"]
      }
      condition {
        test     = "StringEqualsIfExists"
        variable = "dynamodb:ReturnValues"
        values   = ["NONE"]
      }
    }
  }

  statement {
    sid       = "ConsumeOnlyDeletionLedgerStream"
    actions   = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator"]
    resources = [local.foundation.deletion_ledger_stream_arn]
  }
  statement {
    sid       = "DiscoverRegionalStreams"
    actions   = ["dynamodb:ListStreams"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
  dynamic "statement" {
    for_each = var.account_deletion_terminal_candidate ? [1] : []
    content {
      sid       = "ReadAuthoritativeAccountFence"
      actions   = ["dynamodb:GetItem"]
      resources = [local.foundation.deletion_ledger_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["ACCOUNT#*"]
      }
    }
  }
  statement {
    sid       = "ReadHistoryAccountState"
    actions   = ["dynamodb:GetItem"]
    resources = [local.history.control_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }
  statement {
    sid       = "ResumeDeletionReconciliationCheckpoint"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [local.history.control_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["LIFECYCLE#${var.environment}"]
    }
  }
  # This bounded background scan recovers fixed deletion fences after stream
  # retention. Public APIs and the content store never receive Scan permission.
  statement {
    sid       = "ReconcileDurableDeletionFences"
    actions   = ["dynamodb:Scan"]
    resources = [local.foundation.deletion_ledger_table_arn]
  }
  statement {
    sid       = "AtomicallyFenceHistoryAndCreateErasureJob"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [local.history.control_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
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
  statement {
    sid       = "CheckAuthoritativeDeletionRequest"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [local.foundation.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCOUNT#*"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
  # IAM LeadingKeys cannot constrain SK; the tested handler permits only the
  # HISTORY component receipt, never the overall account-deletion status.
  statement {
    sid       = "RecordHistoryAbsentCompletion"
    actions   = ["dynamodb:PutItem"]
    resources = [local.foundation.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCOUNT#*"]
    }
    dynamic "condition" {
      for_each = var.account_deletion_terminal_candidate ? [1] : []
      content {
        test     = "ForAnyValue:StringEquals"
        variable = "dynamodb:EnclosingOperation"
        values   = ["TransactWriteItems"]
      }
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
  statement {
    sid       = "ContentFreeOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.account_deletion[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "account_deletion" {
  count  = local.account_deletion_deployed ? 1 : 0
  name   = "history-account-deletion-runtime"
  role   = aws_iam_role.account_deletion[0].id
  policy = data.aws_iam_policy_document.account_deletion[0].json
}

resource "aws_lambda_function" "account_deletion" {
  count                          = local.account_deletion_deployed ? 1 : 0
  function_name                  = local.account_deletion_name
  role                           = aws_iam_role.account_deletion[0].arn
  runtime                        = var.account_deletion_terminal_candidate ? "python3.14" : "python3.13"
  handler                        = "app.lambda_handler"
  architectures                  = ["arm64"]
  memory_size                    = 256
  timeout                        = 30
  reserved_concurrent_executions = 1
  s3_bucket                      = local.foundation.artifact_bucket_name
  s3_key                         = "releases/${var.account_deletion_artifact.release_id}/history_account_deletion_bridge.zip"
  s3_object_version              = var.account_deletion_artifact.object_version
  source_code_hash               = var.account_deletion_artifact.source_hash
  environment {
    variables = {
      APP_ENVIRONMENT                                    = var.environment
      HISTORY_CONTROL_TABLE_NAME                         = local.history.control_table_name
      DELETION_LEDGER_TABLE_NAME                         = local.foundation.deletion_ledger_table_name
      HISTORY_ACCOUNT_DELETION_ENABLED                   = tostring(var.account_deletion_active)
      HISTORY_ACCOUNT_DELETION_RECONCILIATION_SCAN_LIMIT = "100"
      HISTORY_ACCOUNT_DELETION_RECONCILIATION_MAX_PAGES  = "10"
    }
  }
  lifecycle {
    precondition {
      condition     = !var.account_deletion_terminal_candidate || ((!var.account_deletion_active && !var.lifecycle_active) || var.account_deletion_terminal_activation != null)
      error_message = "Terminal-safe consumers must stay inactive until separate terminal activation is qualified."
    }
    precondition {
      condition = try(
        local.foundation.deletion_ledger_table_name == "${var.project_name}-${var.environment}-deletion-ledger" &&
        local.foundation.deletion_ledger_table_arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current[0].account_id}:table/${local.foundation.deletion_ledger_table_name}" &&
        startswith(local.foundation.deletion_ledger_stream_arn, "${local.foundation.deletion_ledger_table_arn}/stream/"), false
      )
      error_message = "The bridge requires the same-account, region and environment deletion-ledger stream."
    }
  }
  depends_on = [aws_iam_role_policy.account_deletion]
  tags       = local.common_tags
}

resource "aws_lambda_event_source_mapping" "account_deletion" {
  count                          = local.account_deletion_deployed ? 1 : 0
  event_source_arn               = local.foundation.deletion_ledger_stream_arn
  function_name                  = aws_lambda_function.account_deletion[0].arn
  starting_position              = "TRIM_HORIZON"
  batch_size                     = 10
  enabled                        = var.account_deletion_active
  bisect_batch_on_function_error = true
  maximum_retry_attempts         = -1
  parallelization_factor         = 1
  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT", "MODIFY"]
        dynamodb = { NewImage = {
          PK            = { S = [{ prefix = "ACCOUNT#" }] }
          SK            = { S = ["ACCOUNT_DELETION"] }
          eventType     = { S = ["account.deletion.requested"] }
          environment   = { S = [var.environment] }
          schemaVersion = { N = ["1"] }
          status        = { S = ["REQUESTED"] }
        } }
      })
    }
  }
  depends_on = [aws_iam_role_policy.account_deletion]
}

resource "aws_cloudwatch_metric_alarm" "account_deletion" {
  for_each = local.account_deletion_deployed && var.alarm_topic_arn != null ? {
    errors    = { metric = "Errors", statistic = "Sum", threshold = 0 }
    throttles = { metric = "Throttles", statistic = "Sum", threshold = 0 }
    lag       = { metric = "IteratorAge", statistic = "Maximum", threshold = 300000 }
  } : {}
  alarm_name          = "${local.account_deletion_name}-${each.key}"
  alarm_description   = "History account-deletion bridge failure or lag. Reconcile durable deletion commands; stream retention is not durable recovery."
  namespace           = "AWS/Lambda"
  metric_name         = each.value.metric
  dimensions          = { FunctionName = aws_lambda_function.account_deletion[0].function_name }
  statistic           = each.value.statistic
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = each.value.threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_rule" "account_deletion_reconcile" {
  count               = local.account_deletion_deployed ? 1 : 0
  name                = "${var.project_name}-${var.environment}-history-deletion-reconcile"
  schedule_expression = "rate(5 minutes)"
  state               = var.account_deletion_active ? "ENABLED" : "DISABLED"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "account_deletion_reconcile" {
  count = local.account_deletion_deployed ? 1 : 0
  rule  = aws_cloudwatch_event_rule.account_deletion_reconcile[0].name
  arn   = aws_lambda_function.account_deletion[0].arn
  input = jsonencode({ schemaVersion = 1, operation = "reconcile" })
  retry_policy {
    maximum_event_age_in_seconds = 300
    maximum_retry_attempts       = 1
  }
}

resource "aws_lambda_permission" "account_deletion_reconcile" {
  count         = local.account_deletion_deployed ? 1 : 0
  statement_id  = "OnlyHistoryDeletionReconciliation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.account_deletion[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.account_deletion_reconcile[0].arn
}

resource "aws_lambda_function_event_invoke_config" "account_deletion_reconcile" {
  count                        = local.account_deletion_deployed ? 1 : 0
  function_name                = aws_lambda_function.account_deletion[0].function_name
  maximum_event_age_in_seconds = 300
  maximum_retry_attempts       = 1
}
