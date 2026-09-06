data "aws_caller_identity" "current" {}

locals {
  enabled     = var.campaign_intelligence_enabled
  name_prefix = "${var.project_name}-${var.environment}-campaign"

  common_tags = merge(var.tags, {
    Project      = var.project_name
    Environment  = var.environment
    ManagedBy    = "terraform"
    Stack        = "campaign-data"
    CostCategory = "campaign-intelligence"
  })
}

check "environment_promotion_gate" {
  assert {
    condition     = !local.enabled || var.environment == "dev" || var.promotion_approved
    error_message = "UAT and Production campaign resources require promotion_approved=true."
  }
}

check "approved_budget" {
  assert {
    condition = (
      !local.enabled ||
      (var.environment == "dev" && var.campaign_budget_limit_usd == 25) ||
      (var.environment == "prod" && var.campaign_budget_limit_usd == 50) ||
      var.environment == "uat"
    )
    error_message = "The approved monthly campaign budget is $25 for Dev and $50 for Production."
  }
}

check "budget_has_recipient" {
  assert {
    condition     = !local.enabled || length(var.budget_notification_emails) > 0
    error_message = "At least one budget_notification_emails value is required when campaign intelligence is enabled."
  }
}

check "retention_contract" {
  assert {
    condition = (
      var.source_queue_retention_seconds == 345600 &&
      var.dead_letter_queue_retention_seconds == 1209600 &&
      var.queue_max_receive_count == 5 &&
      var.feature_queue_visibility_timeout_seconds >= 180 &&
      var.cluster_queue_visibility_timeout_seconds >= 180
    )
    error_message = "Campaign queue retention and redrive values must match the approved V1 contract."
  }
}

check "throughput_bounds" {
  assert {
    condition = (
      var.pipeline_max_read_request_units >= 1 &&
      var.pipeline_max_read_request_units <= 100 &&
      var.pipeline_max_write_request_units >= 1 &&
      var.pipeline_max_write_request_units <= 50 &&
      var.intelligence_max_read_request_units >= 1 &&
      var.intelligence_max_read_request_units <= 100 &&
      var.intelligence_max_write_request_units >= 1 &&
      var.intelligence_max_write_request_units <= 25
    )
    error_message = "Campaign DynamoDB on-demand caps exceed the approved V1 cost bounds."
  }
}

check "production_deletion_protection" {
  assert {
    condition = (
      !local.enabled ||
      var.environment != "prod" ||
      var.persistent_deletion_protection_enabled
    )
    error_message = "The Production campaign intelligence table requires deletion protection."
  }
}

resource "aws_kms_key" "transient" {
  count = local.enabled ? 1 : 0

  description             = "${local.name_prefix} transient table and queue encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    DataClass = "transient"
    Purpose   = "campaign-transient-encryption"
  })
}

resource "aws_kms_alias" "transient" {
  count = local.enabled ? 1 : 0

  name          = "alias/${local.name_prefix}-transient"
  target_key_id = aws_kms_key.transient[0].key_id
}

resource "aws_kms_key" "persistent" {
  count = local.enabled ? 1 : 0

  description             = "${local.name_prefix} aggregate and audit encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    DataClass = "persistent-aggregate"
    Purpose   = "campaign-persistent-encryption"
  })
}

resource "aws_kms_alias" "persistent" {
  count = local.enabled ? 1 : 0

  name          = "alias/${local.name_prefix}-persistent"
  target_key_id = aws_kms_key.persistent[0].key_id
}

resource "aws_dynamodb_table" "outbox" {
  count = local.enabled ? 1 : 0

  name         = "${local.name_prefix}-outbox"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  on_demand_throughput {
    max_read_request_units  = var.pipeline_max_read_request_units
    max_write_request_units = var.pipeline_max_write_request_units
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.transient[0].arn
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  tags = merge(local.common_tags, {
    DataClass    = "transient"
    RetentionMax = "72-hours"
  })
}

resource "aws_dynamodb_table" "pipeline" {
  count = local.enabled ? 1 : 0

  name         = "${local.name_prefix}-pipeline"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  attribute {
    name = "GSI2PK"
    type = "S"
  }

  attribute {
    name = "GSI2SK"
    type = "S"
  }

  global_secondary_index {
    name            = "ContributorPeriodIndex"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "KEYS_ONLY"

    on_demand_throughput {
      max_read_request_units  = var.pipeline_max_read_request_units
      max_write_request_units = var.pipeline_max_write_request_units
    }
  }

  global_secondary_index {
    name            = "CandidateBucketIndex"
    hash_key        = "GSI2PK"
    range_key       = "GSI2SK"
    projection_type = "KEYS_ONLY"

    on_demand_throughput {
      max_read_request_units  = var.pipeline_max_read_request_units
      max_write_request_units = var.pipeline_max_write_request_units
    }
  }

  on_demand_throughput {
    max_read_request_units  = var.pipeline_max_read_request_units
    max_write_request_units = var.pipeline_max_write_request_units
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.transient[0].arn
  }

  tags = merge(local.common_tags, {
    DataClass    = "transient-pseudonymous"
    RetentionMax = "21-days"
  })
}

resource "aws_dynamodb_table" "intelligence" {
  count = local.enabled ? 1 : 0

  name                        = "${local.name_prefix}-intelligence"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "PK"
  range_key                   = "SK"
  deletion_protection_enabled = var.persistent_deletion_protection_enabled

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  global_secondary_index {
    name            = "PublicationIndex"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "INCLUDE"
    non_key_attributes = [
      "campaignId",
      "categoryId",
      "contributorCountBand",
      "languageIds",
      "periodWeek",
      "riskBand",
      "submissionCountBand",
      "summaryKey",
      "taxonomyVersion",
      "trendDirection",
    ]

    on_demand_throughput {
      max_read_request_units  = var.intelligence_max_read_request_units
      max_write_request_units = var.intelligence_max_write_request_units
    }
  }

  on_demand_throughput {
    max_read_request_units  = var.intelligence_max_read_request_units
    max_write_request_units = var.intelligence_max_write_request_units
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.persistent[0].arn
  }

  tags = merge(local.common_tags, {
    DataClass    = "persistent-aggregate"
    RetentionMax = "400-days"
  })
}

locals {
  campaign_tables = local.enabled ? {
    outbox = {
      arn = aws_dynamodb_table.outbox[0].arn
    }
    pipeline = {
      arn = aws_dynamodb_table.pipeline[0].arn
    }
    intelligence = {
      arn = aws_dynamodb_table.intelligence[0].arn
    }
  } : {}
}

data "aws_iam_policy_document" "table_boundary" {
  for_each = local.campaign_tables

  statement {
    sid     = "DenyCrossAccountAccess"
    effect  = "Deny"
    actions = ["dynamodb:*"]
    resources = [
      each.value.arn,
      "${each.value.arn}/index/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "Bool"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }
  }
}

resource "aws_dynamodb_resource_policy" "table_boundary" {
  for_each = local.campaign_tables

  resource_arn = each.value.arn
  policy       = data.aws_iam_policy_document.table_boundary[each.key].json
}

resource "aws_sqs_queue" "feature_dlq" {
  count = local.enabled ? 1 : 0

  name                      = "${local.name_prefix}-feature-dlq"
  message_retention_seconds = var.dead_letter_queue_retention_seconds
  kms_master_key_id         = aws_kms_key.transient[0].arn

  tags = merge(local.common_tags, {
    DataClass = "opaque-control-metadata"
  })
}

resource "aws_sqs_queue" "feature" {
  count = local.enabled ? 1 : 0

  name                       = "${local.name_prefix}-feature"
  message_retention_seconds  = var.source_queue_retention_seconds
  visibility_timeout_seconds = var.feature_queue_visibility_timeout_seconds
  kms_master_key_id          = aws_kms_key.transient[0].arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.feature_dlq[0].arn
    maxReceiveCount     = var.queue_max_receive_count
  })

  tags = merge(local.common_tags, {
    DataClass = "opaque-control-metadata"
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "feature" {
  count = local.enabled ? 1 : 0

  queue_url = aws_sqs_queue.feature_dlq[0].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.feature[0].arn]
  })
}

resource "aws_sqs_queue" "cluster_dlq" {
  count = local.enabled ? 1 : 0

  name                      = "${local.name_prefix}-cluster-dlq"
  message_retention_seconds = var.dead_letter_queue_retention_seconds
  kms_master_key_id         = aws_kms_key.transient[0].arn

  tags = merge(local.common_tags, {
    DataClass = "opaque-control-metadata"
  })
}

resource "aws_sqs_queue" "cluster" {
  count = local.enabled ? 1 : 0

  name                       = "${local.name_prefix}-cluster"
  message_retention_seconds  = var.source_queue_retention_seconds
  visibility_timeout_seconds = var.cluster_queue_visibility_timeout_seconds
  kms_master_key_id          = aws_kms_key.transient[0].arn
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.cluster_dlq[0].arn
    maxReceiveCount     = var.queue_max_receive_count
  })

  tags = merge(local.common_tags, {
    DataClass = "opaque-control-metadata"
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "cluster" {
  count = local.enabled ? 1 : 0

  queue_url = aws_sqs_queue.cluster_dlq[0].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.cluster[0].arn]
  })
}

locals {
  campaign_queues = local.enabled ? {
    feature = {
      arn = aws_sqs_queue.feature[0].arn
      url = aws_sqs_queue.feature[0].id
    }
    feature_dlq = {
      arn = aws_sqs_queue.feature_dlq[0].arn
      url = aws_sqs_queue.feature_dlq[0].id
    }
    cluster = {
      arn = aws_sqs_queue.cluster[0].arn
      url = aws_sqs_queue.cluster[0].id
    }
    cluster_dlq = {
      arn = aws_sqs_queue.cluster_dlq[0].arn
      url = aws_sqs_queue.cluster_dlq[0].id
    }
  } : {}
}

data "aws_iam_policy_document" "queue_transport" {
  for_each = local.campaign_queues

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [each.value.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "transport" {
  for_each = local.campaign_queues

  queue_url = each.value.url
  policy    = data.aws_iam_policy_document.queue_transport[each.key].json
}

resource "aws_ecr_repository" "model" {
  count = local.enabled ? 1 : 0

  name                 = "${local.name_prefix}-model"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.environment == "dev"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    ArtifactClass = "multilingual-model"
  })
}

resource "aws_ecr_lifecycle_policy" "model" {
  count = local.enabled ? 1 : 0

  repository = aws_ecr_repository.model[0].name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after seven days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Retain the five newest approved images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = { type = "expire" }
      },
    ]
  })
}

data "aws_iam_policy_document" "model_repository" {
  count = local.enabled ? 1 : 0

  statement {
    sid    = "AllowSameAccountLambdaPull"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [aws_ecr_repository.model[0].arn]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_ecr_repository_policy" "model" {
  count = local.enabled ? 1 : 0

  repository = aws_ecr_repository.model[0].name
  policy     = data.aws_iam_policy_document.model_repository[0].json
}

resource "aws_sns_topic" "budget" {
  count = local.enabled ? 1 : 0

  name = "${local.name_prefix}-budget-alerts"

  tags = local.common_tags
}

data "aws_iam_policy_document" "budget_topic" {
  count = local.enabled ? 1 : 0

  statement {
    sid     = "AllowBudgetsPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]
    resources = [
      aws_sns_topic.budget[0].arn,
    ]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "AllowCloudWatchPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]
    resources = [
      aws_sns_topic.budget[0].arn,
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.name_prefix}-*"]
    }
  }
}

resource "aws_sns_topic_policy" "budget" {
  count = local.enabled ? 1 : 0

  arn    = aws_sns_topic.budget[0].arn
  policy = data.aws_iam_policy_document.budget_topic[0].json
}

resource "aws_sns_topic_subscription" "budget_email" {
  for_each = local.enabled ? var.budget_notification_emails : []

  topic_arn = aws_sns_topic.budget[0].arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_budgets_budget" "campaign" {
  count = local.enabled ? 1 : 0

  name         = "${local.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.campaign_budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:CostCategory$campaign-intelligence"]
  }

  dynamic "notification" {
    for_each = toset([50, 80, 100])

    content {
      comparison_operator       = "GREATER_THAN"
      notification_type         = "ACTUAL"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      subscriber_sns_topic_arns = [aws_sns_topic.budget[0].arn]
    }
  }

  depends_on = [aws_sns_topic_policy.budget]
}
