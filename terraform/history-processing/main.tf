data "terraform_remote_state" "upstream" {
  for_each = var.lifecycle_deployment_enabled ? toset(["foundation", "history-data"]) : toset([])
  backend  = "s3"
  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/${each.key}.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

data "aws_caller_identity" "current" {
  count = var.lifecycle_deployment_enabled ? 1 : 0
}

locals {
  deployed   = var.lifecycle_deployment_enabled
  foundation = local.deployed ? data.terraform_remote_state.upstream["foundation"].outputs.downstream_contract : null
  history    = local.deployed ? data.terraform_remote_state.upstream["history-data"].outputs.downstream_contract : null
  name       = "${var.project_name}-${var.environment}-history-lifecycle"
  common_tags = merge(var.tags, {
    Project   = var.project_name, Environment = var.environment,
    ManagedBy = "terraform", Stack = "history-processing", CostCategory = "history-badges"
  })
  runtime_env = var.runtime_policy == null ? {} : {
    HISTORY_MUTATION_RETENTION_DAYS                = tostring(var.runtime_policy.mutation_retention_days)
    HISTORY_LIFECYCLE_START_EPOCH_HOUR             = tostring(var.runtime_policy.start_epoch_hour)
    HISTORY_LIFECYCLE_MAX_ITEMS_PER_SWEEP          = tostring(var.runtime_policy.max_items_per_sweep)
    HISTORY_LIFECYCLE_MAX_BUCKET_QUERIES_PER_SWEEP = tostring(var.runtime_policy.max_bucket_queries_per_sweep)
    HISTORY_ERASURE_BATCH_SIZE                     = tostring(var.runtime_policy.erasure_batch_size)
    HISTORY_COMPLETION_STUCK_SECONDS               = tostring(var.runtime_policy.completion_stuck_seconds)
    HISTORY_COMPLETION_RECHECK_SECONDS             = tostring(var.runtime_policy.completion_recheck_seconds)
    HISTORY_EXPIRATION_RECONCILIATION_HOURS        = tostring(var.runtime_policy.expiration_reconciliation_hours)
  }
}

resource "aws_cloudwatch_log_group" "lifecycle" {
  count             = local.deployed ? 1 : 0
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 14
  tags              = local.common_tags
}

data "aws_iam_policy_document" "assume" {
  count = local.deployed ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lifecycle" {
  count              = local.deployed ? 1 : 0
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume[0].json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "runtime" {
  count = local.deployed ? 1 : 0
  statement {
    sid       = "ContentCleanup"
    actions   = ["dynamodb:Query", "dynamodb:DeleteItem"]
    resources = [local.history.content_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*#HISTORY#*"]
    }
  }
  statement {
    sid       = "ControlJobsAndCheckpoints"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
    resources = [local.history.control_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*", "CURSOR#*", "LIFECYCLE#${var.environment}"]
    }
  }
  statement {
    sid       = "ReplayContentErasure"
    actions   = concat(["dynamodb:Query", "dynamodb:UpdateItem"], local.account_deletion_deployed ? ["dynamodb:PutItem"] : [])
    resources = [local.foundation.analysis_abuse_control_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ANALYSIS#REQUEST#*"]
    }
  }
  dynamic "statement" {
    for_each = local.account_deletion_deployed ? [1] : []
    content {
      sid       = "EnumerateAllAccountGenerations"
      actions   = ["dynamodb:Query"]
      resources = [local.history.control_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["USER#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = local.account_deletion_deployed ? [1] : []
    content {
      sid       = "HistoryComponentCompletionReceipt"
      actions   = var.account_deletion_terminal_candidate ? ["dynamodb:GetItem"] : ["dynamodb:GetItem", "dynamodb:PutItem"]
      resources = [local.foundation.deletion_ledger_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["ACCOUNT#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = var.account_deletion_terminal_candidate && local.account_deletion_deployed ? [1] : []
    content {
      sid       = "GuardHistoryCompletionReceiptTransaction"
      actions   = ["dynamodb:PutItem", "dynamodb:ConditionCheckItem"]
      resources = [local.foundation.deletion_ledger_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["ACCOUNT#*"]
      }
      condition {
        test     = "StringEquals"
        variable = "dynamodb:EnclosingOperation"
        values   = ["TransactWriteItems"]
      }
    }
  }
  statement {
    sid     = "BoundedLifecycleIndexQueries"
    actions = ["dynamodb:Query"]
    resources = [
      "${local.history.content_table_arn}/index/ExpirationIndex",
      "${local.history.control_table_arn}/index/ExpirationIndex",
      "${local.history.control_table_arn}/index/PendingLifecycleIndex",
    ]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["HISTORY#*", "CONTROL#*", "PENDING#*"]
    }
  }
  statement {
    sid       = "ContentFreeLogsAndEmbeddedMetrics"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lifecycle[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "runtime" {
  count  = local.deployed ? 1 : 0
  name   = "history-lifecycle-runtime"
  role   = aws_iam_role.lifecycle[0].id
  policy = data.aws_iam_policy_document.runtime[0].json
}

resource "aws_lambda_function" "lifecycle" {
  count                          = local.deployed ? 1 : 0
  function_name                  = local.name
  role                           = aws_iam_role.lifecycle[0].arn
  runtime                        = var.account_deletion_terminal_candidate ? "python3.14" : "python3.12"
  handler                        = "app.lambda_handler"
  architectures                  = ["arm64"]
  memory_size                    = 256
  timeout                        = 60
  reserved_concurrent_executions = 1
  s3_bucket                      = local.foundation.artifact_bucket_name
  s3_key                         = "releases/${var.artifact.release_id}/history_lifecycle.zip"
  s3_object_version              = var.artifact.object_version
  source_code_hash               = var.artifact.source_hash

  environment {
    variables = merge(local.runtime_env, local.account_deletion_deployed ? {
      DELETION_LEDGER_TABLE_NAME = local.foundation.deletion_ledger_table_name
      } : {}, {
      APP_ENVIRONMENT                           = var.environment
      HISTORY_CONTENT_TABLE_NAME                = local.history.content_table_name
      HISTORY_CONTROL_TABLE_NAME                = local.history.control_table_name
      DEVICE_BINDINGS_TABLE_NAME                = local.foundation.device_bindings_table_name
      ANALYSIS_ABUSE_TABLE_NAME                 = local.foundation.analysis_abuse_control_table_name
      HISTORY_SCHEMA_VERSION                    = "1"
      HISTORY_RETENTION_DAYS                    = "90"
      HISTORY_DEDUP_RETENTION_DAYS              = tostring(local.history.storage_policy.dedup_retention_seconds / 86400)
      HISTORY_ERASURE_SLA_HOURS                 = "24"
      HISTORY_EXPIRATION_INDEX_NAME             = "ExpirationIndex"
      HISTORY_LIFECYCLE_INDEX_NAME              = "PendingLifecycleIndex"
      HISTORY_LIFECYCLE_ENABLED                 = tostring(var.lifecycle_active)
      HISTORY_READS_ENABLED                     = "false"
      HISTORY_WRITES_ENABLED                    = "false"
      HISTORY_DURABLE_REPLAY_ENABLED            = "false"
      HISTORY_MUTATIONS_ENABLED                 = "false"
      RECOGNITION_ENABLED                       = "false"
      HISTORY_PITR_POLICY_APPROVED              = tostring(try(local.history.storage_policy.approved, false))
      HISTORY_CONTROL_RETENTION_POLICY_APPROVED = tostring(try(local.history.storage_policy.approved, false))
    })
  }

  lifecycle {
    precondition {
      condition = try(
        local.history.schema_version == 1 && local.history.enabled &&
        local.history.environment == var.environment && local.foundation.schema_version == 1 &&
        local.history.content_table_name == "${var.project_name}-${var.environment}-history-content" &&
        local.history.control_table_name == "${var.project_name}-${var.environment}-history-control" &&
        local.foundation.analysis_abuse_control_table_name == "${var.project_name}-${var.environment}-analysis-abuse-control" &&
        local.foundation.device_bindings_table_name == "${var.project_name}-${var.environment}-device-bindings" &&
        alltrue([for pair in [
          { name = local.history.content_table_name, arn = local.history.content_table_arn },
          { name = local.history.control_table_name, arn = local.history.control_table_arn },
          { name = local.foundation.analysis_abuse_control_table_name, arn = local.foundation.analysis_abuse_control_table_arn },
        ] : pair.arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current[0].account_id}:table/${pair.name}"]) &&
        local.history.expiration_index_name == "ExpirationIndex" &&
        local.history.lifecycle_index_name == "PendingLifecycleIndex",
        false,
      )
      error_message = "Lifecycle requires enabled, version-compatible and same-environment data/foundation contracts."
    }
    precondition {
      condition = try(
        local.history.storage_policy.approved &&
        local.history.storage_policy.dedup_retention_seconds >= (90 + 1) * 86400 &&
        local.history.storage_policy.dedup_retention_seconds % 86400 == 0,
        false,
      )
      error_message = "Approved dedup retention must cover 90-day History plus the 24-hour cleanup window and convert exactly to whole days; never round retention."
    }
  }
  depends_on = [aws_iam_role_policy.runtime]
  tags       = local.common_tags
}

resource "aws_lambda_function_event_invoke_config" "lifecycle" {
  count                        = local.deployed ? 1 : 0
  function_name                = aws_lambda_function.lifecycle[0].function_name
  maximum_event_age_in_seconds = 300
  maximum_retry_attempts       = 1
}

resource "aws_cloudwatch_event_rule" "sweep" {
  count               = local.deployed ? 1 : 0
  name                = "${local.name}-sweep"
  schedule_expression = "rate(5 minutes)"
  state               = var.lifecycle_active ? "ENABLED" : "DISABLED"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "sweep" {
  count = local.deployed ? 1 : 0
  rule  = aws_cloudwatch_event_rule.sweep[0].name
  arn   = aws_lambda_function.lifecycle[0].arn
  input = jsonencode({ schemaVersion = 1, operation = "sweep" })
  retry_policy {
    maximum_event_age_in_seconds = 300
    maximum_retry_attempts       = 2
  }
}

resource "aws_lambda_permission" "schedule" {
  count         = local.deployed ? 1 : 0
  statement_id  = "OnlyHistoryLifecycleSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lifecycle[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sweep[0].arn
}
