data "aws_caller_identity" "current" {}

data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/foundation.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

data "terraform_remote_state" "campaign_data" {
  count   = var.campaign_processing_enabled ? 1 : 0
  backend = "s3"

  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/campaign-data.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  foundation = data.terraform_remote_state.foundation.outputs.downstream_contract
  campaign = try(data.terraform_remote_state.campaign_data[0].outputs.downstream_contract, {
    schema_version          = 1
    environment             = var.environment
    enabled                 = false
    outbox_table_name       = null
    outbox_stream_arn       = null
    pipeline_table_name     = null
    pipeline_table_arn      = null
    expiration_index_name   = "ExpirationIndex"
    intelligence_table_name = null
    intelligence_table_arn  = null
    cluster_queue_url       = null
    cluster_queue_arn       = null
    cluster_dlq_arn         = null
    transient_kms_key_arn   = null
    persistent_kms_key_arn  = null
    budget_alert_topic_arn  = null
  })
  enabled      = var.campaign_processing_enabled
  active       = local.enabled && !var.kill_switch_enabled
  name_prefix  = "${var.project_name}-${var.environment}-campaign"
  artifact_key = var.artifact_release == null ? null : "releases/${var.artifact_release}"

  functions = {
    publisher = {
      name        = "${local.name_prefix}-observation-publisher"
      memory      = var.publisher_memory_mb
      timeout     = var.publisher_timeout_seconds
      kms_key     = try(local.campaign.transient_kms_key_arn, null)
      artifact    = var.publisher_artifact_name
      description = "Pseudonymizes opted-in app-featured analyses and publishes opaque clustering work"
    }
    cluster = {
      name        = "${local.name_prefix}-cluster-aggregator"
      memory      = var.cluster_memory_mb
      timeout     = var.cluster_timeout_seconds
      kms_key     = try(local.campaign.persistent_kms_key_arn, null)
      artifact    = var.cluster_artifact_name
      description = "Updates bounded candidates and thresholded campaign aggregates"
    }
    lifecycle = {
      name        = "${local.name_prefix}-lifecycle"
      memory      = var.lifecycle_memory_mb
      timeout     = var.lifecycle_timeout_seconds
      kms_key     = try(local.campaign.persistent_kms_key_arn, null)
      artifact    = var.lifecycle_artifact_name
      description = "Expires transient data, finalizes periods, and retires period keys"
    }
    deletion = {
      name        = "${local.name_prefix}-deletion-bridge"
      memory      = var.deletion_memory_mb
      timeout     = var.deletion_timeout_seconds
      kms_key     = try(local.campaign.transient_kms_key_arn, null)
      artifact    = var.deletion_artifact_name
      description = "Removes active campaign contributions after consent withdrawal or account deletion"
    }
  }

  common_tags = merge(var.tags, {
    Project      = var.project_name
    Environment  = var.environment
    ManagedBy    = "terraform"
    Stack        = "campaign-processing"
    CostCategory = "campaign-intelligence"
  })
}

check "upstream_contract_versions" {
  assert {
    condition = (
      local.foundation.schema_version == 1 &&
      local.campaign.schema_version == 1 &&
      local.campaign.environment == var.environment
    )
    error_message = "Campaign processing received an incompatible or cross-environment state contract."
  }
}

check "enabled_dependencies" {
  assert {
    condition = (
      !local.enabled ||
      (
        local.campaign.enabled &&
        local.foundation.deletion_ledger_stream_arn != null &&
        local.campaign.outbox_stream_arn != null &&
        local.campaign.expiration_index_name == "ExpirationIndex" &&
        var.artifact_release != null
      )
    )
    error_message = "Enable campaign data and provide immutable worker artifacts before enabling processing."
  }
}

check "environment_promotion_gate" {
  assert {
    condition     = !local.enabled || var.environment == "dev" || var.promotion_approved
    error_message = "UAT and Production campaign processing requires promotion_approved=true."
  }
}

check "runtime_bounds" {
  assert {
    condition = (
      var.contract_schema_version == 1 &&
      var.publisher_memory_mb >= 128 &&
      var.publisher_memory_mb <= 1024 &&
      var.cluster_memory_mb >= 128 &&
      var.cluster_memory_mb <= 2048 &&
      var.lifecycle_memory_mb >= 128 &&
      var.lifecycle_memory_mb <= 1024 &&
      var.deletion_memory_mb >= 128 &&
      var.deletion_memory_mb <= 1024 &&
      var.publisher_timeout_seconds <= 30 &&
      var.cluster_timeout_seconds <= 30 &&
      var.lifecycle_timeout_seconds <= 60 &&
      var.deletion_timeout_seconds <= 30 &&
      var.reserved_concurrency >= 1 &&
      var.reserved_concurrency <= 10 &&
      var.queue_batch_size >= 1 &&
      var.queue_batch_size <= 10
    )
    error_message = "Campaign Lambda sizing or concurrency exceeds the approved V1 bounds."
  }
}

check "log_retention_contract" {
  assert {
    condition = (
      (var.environment == "dev" && var.log_retention_days == 14) ||
      (var.environment == "uat" && var.log_retention_days == 30) ||
      (var.environment == "prod" && var.log_retention_days == 90)
    )
    error_message = "Campaign log retention must be Dev 14, UAT 30, or Production 90 days."
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "worker" {
  for_each = local.enabled ? local.functions : {}

  name               = "${each.value.name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = merge(local.common_tags, {
    Component = each.key
  })
}

resource "aws_cloudwatch_log_group" "worker" {
  for_each = local.enabled ? local.functions : {}

  name              = "/aws/lambda/${each.value.name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Component = each.key
    DataClass = "content-free-operational"
  })
}

data "aws_iam_policy_document" "worker_logging" {
  for_each = local.enabled ? local.functions : {}

  statement {
    sid    = "WriteOwnContentFreeLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.worker[each.key].arn}:*"]
  }

  statement {
    sid       = "PublishContentFreeMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["TrustCheckRadar/Campaign"]
    }
  }
}

resource "aws_iam_role_policy" "worker_logging" {
  for_each = local.enabled ? local.functions : {}

  name   = "content-free-logging"
  role   = aws_iam_role.worker[each.key].id
  policy = data.aws_iam_policy_document.worker_logging[each.key].json
}

data "aws_iam_policy_document" "publisher_runtime" {
  count = local.enabled ? 1 : 0

  statement {
    sid    = "ReadCampaignOutboxStream"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:ListStreams",
    ]
    resources = [local.campaign.outbox_stream_arn]
  }

  statement {
    sid    = "WriteTransientPipeline"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
    ]
    resources = [local.campaign.pipeline_table_arn]
  }

  statement {
    sid       = "SendOpaqueClusterWork"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [local.campaign.cluster_queue_arn]
  }

  statement {
    sid    = "UseTransientEncryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]
    resources = [local.campaign.transient_kms_key_arn]
  }

  statement {
    sid       = "GenerateCurrentPeriodToken"
    effect    = "Allow"
    actions   = ["kms:GenerateMac"]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [var.environment]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Purpose"
      values   = ["campaign-contributor-token"]
    }
  }
}

resource "aws_iam_role_policy" "publisher_runtime" {
  count = local.enabled ? 1 : 0

  name   = "publisher-runtime"
  role   = aws_iam_role.worker["publisher"].id
  policy = data.aws_iam_policy_document.publisher_runtime[0].json
}

data "aws_iam_policy_document" "cluster_runtime" {
  count = local.enabled ? 1 : 0

  statement {
    sid    = "ConsumeClusterQueue"
    effect = "Allow"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [local.campaign.cluster_queue_arn]
  }

  statement {
    sid    = "ReadTransientCandidates"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      local.campaign.pipeline_table_arn,
      "${local.campaign.pipeline_table_arn}/index/CandidateBucketIndex",
    ]
  }

  statement {
    sid    = "UpdatePersistentAggregates"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      local.campaign.intelligence_table_arn,
      "${local.campaign.intelligence_table_arn}/index/PublicationIndex",
    ]
  }

  statement {
    sid    = "UseCampaignEncryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]
    resources = [
      local.campaign.transient_kms_key_arn,
      local.campaign.persistent_kms_key_arn,
    ]
  }
}

resource "aws_iam_role_policy" "cluster_runtime" {
  count = local.enabled ? 1 : 0

  name   = "cluster-runtime"
  role   = aws_iam_role.worker["cluster"].id
  policy = data.aws_iam_policy_document.cluster_runtime[0].json
}

data "aws_iam_policy_document" "deletion_runtime" {
  count = local.enabled ? 1 : 0

  statement {
    sid    = "ReadDeletionLedgerStream"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:ListStreams",
    ]
    resources = [local.foundation.deletion_ledger_stream_arn]
  }

  statement {
    sid    = "DeleteActiveContributions"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      local.campaign.pipeline_table_arn,
      "${local.campaign.pipeline_table_arn}/index/ContributorPeriodIndex",
    ]
  }

  statement {
    sid       = "DeriveActivePeriodTokens"
    effect    = "Allow"
    actions   = ["kms:GenerateMac"]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [var.environment]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Purpose"
      values   = ["campaign-contributor-token"]
    }
  }
}

resource "aws_iam_role_policy" "deletion_runtime" {
  count = local.enabled ? 1 : 0

  name   = "deletion-runtime"
  role   = aws_iam_role.worker["deletion"].id
  policy = data.aws_iam_policy_document.deletion_runtime[0].json
}

data "aws_iam_policy_document" "lifecycle_runtime" {
  count = local.enabled ? 1 : 0

  statement {
    sid    = "LifecycleTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:BatchWriteItem",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
    ]
    resources = [
      local.campaign.pipeline_table_arn,
      "${local.campaign.pipeline_table_arn}/index/CandidateBucketIndex",
      "${local.campaign.pipeline_table_arn}/index/${local.campaign.expiration_index_name}",
      local.campaign.intelligence_table_arn,
    ]
  }

  statement {
    sid       = "CreatePeriodHmacKeys"
    effect    = "Allow"
    actions   = ["kms:CreateKey"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:KeySpec"
      values   = ["HMAC_256"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:KeyUsage"
      values   = ["GENERATE_VERIFY_MAC"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = [var.environment]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Purpose"
      values   = ["campaign-contributor-token"]
    }
  }

  statement {
    sid    = "ManageTaggedPeriodHmacKeys"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:DisableKey",
      "kms:EnableKey",
      "kms:GetKeyPolicy",
      "kms:TagResource",
    ]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [var.environment]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Purpose"
      values   = ["campaign-contributor-token"]
    }
  }

  statement {
    sid       = "TagNewPeriodHmacKeys"
    effect    = "Allow"
    actions   = ["kms:TagResource"]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = [var.environment]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Purpose"
      values   = ["campaign-contributor-token"]
    }
  }

  statement {
    sid       = "ScheduleTaggedPeriodKeyDeletion"
    effect    = "Allow"
    actions   = ["kms:ScheduleKeyDeletion"]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [var.environment]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Purpose"
      values   = ["campaign-contributor-token"]
    }

    condition {
      test     = "NumericEquals"
      variable = "kms:ScheduleKeyDeletionPendingWindowInDays"
      values   = ["7"]
    }
  }

  statement {
    sid    = "UseCampaignEncryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]
    resources = [
      local.campaign.transient_kms_key_arn,
      local.campaign.persistent_kms_key_arn,
    ]
  }
}

resource "aws_iam_role_policy" "lifecycle_runtime" {
  count = local.enabled ? 1 : 0

  name   = "lifecycle-runtime"
  role   = aws_iam_role.worker["lifecycle"].id
  policy = data.aws_iam_policy_document.lifecycle_runtime[0].json
}

resource "aws_lambda_function" "worker" {
  for_each = local.enabled ? local.functions : {}

  function_name = each.value.name
  description   = each.value.description
  role          = aws_iam_role.worker[each.key].arn
  runtime       = "python3.13"
  handler       = "app.lambda_handler"

  timeout                        = each.value.timeout
  memory_size                    = each.value.memory
  architectures                  = ["arm64"]
  reserved_concurrent_executions = var.reserved_concurrency

  s3_bucket = local.foundation.artifact_bucket_name
  s3_key    = "${local.artifact_key}/${each.value.artifact}"

  environment {
    variables = {
      APP_ENVIRONMENT             = var.environment
      CAMPAIGN_SCHEMA_VERSION     = tostring(var.contract_schema_version)
      OUTBOX_TABLE_NAME           = local.campaign.outbox_table_name
      PIPELINE_TABLE_NAME         = local.campaign.pipeline_table_name
      EXPIRATION_INDEX_NAME       = local.campaign.expiration_index_name
      INTELLIGENCE_TABLE_NAME     = local.campaign.intelligence_table_name
      CLUSTER_QUEUE_URL           = local.campaign.cluster_queue_url
      CONTRIBUTOR_PERIOD_DAYS     = "14"
      CONTRIBUTOR_RECOVERY_DAYS   = "7"
      OBSERVATION_RETENTION_HOURS = "72"
      TRANSIENT_RETENTION_DAYS    = "21"
      AGGREGATE_RETENTION_DAYS    = "400"
      MIN_CONTRIBUTOR_COUNT       = "10"
      MAX_CONTRIBUTOR_SUBMISSIONS = "3"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.worker,
    aws_iam_role_policy.worker_logging,
  ]

  tags = merge(local.common_tags, {
    Component = each.key
  })
}

resource "aws_lambda_event_source_mapping" "publisher" {
  count = local.enabled ? 1 : 0

  event_source_arn  = local.campaign.outbox_stream_arn
  function_name     = aws_lambda_function.worker["publisher"].arn
  starting_position = "LATEST"
  batch_size        = 10
  enabled           = local.active

  bisect_batch_on_function_error = true
  maximum_retry_attempts         = -1
  parallelization_factor         = 1

  filter_criteria {
    filter {
      pattern = jsonencode({ eventName = ["INSERT"] })
    }
  }

  depends_on = [aws_iam_role_policy.publisher_runtime]
}

resource "aws_lambda_event_source_mapping" "cluster" {
  count = local.enabled ? 1 : 0

  event_source_arn = local.campaign.cluster_queue_arn
  function_name    = aws_lambda_function.worker["cluster"].arn
  batch_size       = var.queue_batch_size
  enabled          = local.active

  function_response_types = ["ReportBatchItemFailures"]

  depends_on = [aws_iam_role_policy.cluster_runtime]
}

resource "aws_lambda_event_source_mapping" "deletion" {
  count = local.enabled ? 1 : 0

  event_source_arn  = local.foundation.deletion_ledger_stream_arn
  function_name     = aws_lambda_function.worker["deletion"].arn
  starting_position = "LATEST"
  batch_size        = 10
  enabled           = local.active

  bisect_batch_on_function_error = true
  maximum_retry_attempts         = -1
  parallelization_factor         = 1

  filter_criteria {
    filter {
      pattern = jsonencode({ eventName = ["INSERT", "MODIFY"] })
    }
  }

  depends_on = [aws_iam_role_policy.deletion_runtime]
}

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    sid     = "SchedulerAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  count = local.enabled ? 1 : 0

  name               = "${local.name_prefix}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "scheduler_invoke" {
  count = local.enabled ? 1 : 0

  statement {
    sid       = "InvokeLifecycle"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.worker["lifecycle"].arn]
  }
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  count = local.enabled ? 1 : 0

  name   = "invoke-lifecycle"
  role   = aws_iam_role.scheduler[0].id
  policy = data.aws_iam_policy_document.scheduler_invoke[0].json
}

resource "aws_scheduler_schedule_group" "campaign" {
  count = local.enabled ? 1 : 0

  name = local.name_prefix

  tags = local.common_tags
}

resource "aws_scheduler_schedule" "lifecycle" {
  for_each = local.enabled ? {
    expire_transient = "rate(1 hour)"
    finalize_periods = "rate(6 hours)"
    manage_keys      = "rate(1 day)"
  } : {}

  name                         = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  group_name                   = aws_scheduler_schedule_group.campaign[0].name
  schedule_expression          = each.value
  schedule_expression_timezone = "Etc/UTC"
  state                        = local.active ? "ENABLED" : "DISABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.worker["lifecycle"].arn
    role_arn = aws_iam_role.scheduler[0].arn
    input = jsonencode({
      operation     = each.key
      environment   = var.environment
      schemaVersion = var.contract_schema_version
    })

    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 2
    }
  }

  depends_on = [aws_iam_role_policy.scheduler_invoke]
}

resource "aws_cloudwatch_metric_alarm" "worker_errors" {
  for_each = local.enabled ? { for key, value in local.functions : key => value.name } : {}

  alarm_name          = "${each.value}-errors"
  alarm_description   = "Campaign worker errors; logs and notifications must remain content-free"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.campaign.budget_alert_topic_arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "queue_age" {
  for_each = local.enabled ? {
    cluster = local.campaign.cluster_queue_arn
  } : {}

  alarm_name          = "${local.name_prefix}-${each.key}-queue-age"
  alarm_description   = "Oldest campaign queue message exceeds the five-minute processing target"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 300
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.campaign.budget_alert_topic_arn]

  dimensions = {
    QueueName = element(reverse(split(":", each.value)), 0)
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dead_letter" {
  for_each = local.enabled ? {
    cluster = local.campaign.cluster_dlq_arn
  } : {}

  alarm_name          = "${local.name_prefix}-${each.key}-dlq"
  alarm_description   = "Campaign dead-letter queue contains messages"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.campaign.budget_alert_topic_arn]

  dimensions = {
    QueueName = element(reverse(split(":", each.value)), 0)
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  count = local.enabled ? 1 : 0

  alarm_name          = "${local.name_prefix}-dynamodb-throttles"
  alarm_description   = "Campaign DynamoDB requests are being throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.campaign.budget_alert_topic_arn]

  metric_query {
    id          = "total"
    expression  = "m1+m2"
    label       = "Campaign throttled requests"
    return_data = true
  }

  metric_query {
    id          = "m1"
    return_data = false

    metric {
      namespace   = "AWS/DynamoDB"
      metric_name = "ThrottledRequests"
      period      = 300
      stat        = "Sum"

      dimensions = {
        TableName = local.campaign.pipeline_table_name
      }
    }
  }

  metric_query {
    id          = "m2"
    return_data = false

    metric {
      namespace   = "AWS/DynamoDB"
      metric_name = "ThrottledRequests"
      period      = 300
      stat        = "Sum"

      dimensions = {
        TableName = local.campaign.intelligence_table_name
      }
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "privacy_deadline" {
  count = local.enabled ? 1 : 0

  alarm_name          = "${local.name_prefix}-privacy-deadline-missed"
  alarm_description   = "Campaign deletion or period-key retirement exceeded its approved deadline"
  namespace           = "TrustCheckRadar/Campaign"
  metric_name         = "PrivacyDeadlineMissed"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.campaign.budget_alert_topic_arn]

  dimensions = {
    Environment = var.environment
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_dashboard" "campaign" {
  count = local.enabled ? 1 : 0

  dashboard_name = "${local.name_prefix}-operations"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Campaign queue age"
          region = var.aws_region
          stat   = "Maximum"
          period = 60
          metrics = [
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", element(reverse(split(":", local.campaign.cluster_queue_arn)), 0)],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Worker errors and throttles"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = concat(
            [
              for value in values(local.functions) : ["AWS/Lambda", "Errors", "FunctionName", value.name]
            ],
            [
              for value in values(local.functions) : ["AWS/Lambda", "Throttles", "FunctionName", value.name]
            ],
          )
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title  = "Privacy-safe campaign counters"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = [
            ["TrustCheckRadar/Campaign", "Published", "Environment", var.environment],
            [".", "Confirmed", ".", "."],
            [".", "SuppressedBelowThreshold", ".", "."],
            [".", "ConsentSuppressed", ".", "."],
            [".", "Duplicate", ".", "."],
            [".", "Malformed", ".", "."],
            [".", "DeletionRequested", ".", "."],
            [".", "DeletionCompleted", ".", "."],
            [".", "FinalizationFailed", ".", "."],
            [".", "KeyRetirementFailed", ".", "."],
            [".", "PrivacyDeadlineMissed", ".", "."],
          ]
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 12
        width  = 24
        height = 2
        properties = {
          markdown = "Feature source: app | Contract schema: `${var.contract_schema_version}`"
        }
      },
    ]
  })
}
