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

data "terraform_remote_state" "api" {
  backend = "s3"

  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/api.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

data "terraform_remote_state" "campaign_data" {
  count   = (var.campaign_api_enabled || var.campaign_review_api_enabled) ? 1 : 0
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
  api = try(data.terraform_remote_state.api.outputs.campaign_route_contract, {
    schema_version                = 1
    environment                   = var.environment
    campaign_intelligence_enabled = false
    api_id                        = null
    execution_arn                 = null
    authorizer_id                 = null
    stage_name                    = null
  })
  campaign = try(data.terraform_remote_state.campaign_data[0].outputs.downstream_contract, {
    schema_version          = 1
    environment             = var.environment
    enabled                 = false
    outbox_table_arn        = null
    pipeline_table_name     = null
    pipeline_table_arn      = null
    intelligence_table_name = null
    intelligence_table_arn  = null
    publication_index_name  = "PublicationIndex"
    persistent_kms_key_arn  = null
    budget_alert_topic_arn  = null
  })
  enabled     = var.campaign_api_enabled
  any_enabled = var.campaign_api_enabled || var.campaign_review_api_enabled
  name_prefix = "${var.project_name}-${var.environment}-campaign"

  common_tags = merge(var.tags, {
    Project      = var.project_name
    Environment  = var.environment
    ManagedBy    = "terraform"
    Stack        = "campaign-api"
    CostCategory = "campaign-intelligence"
  })
}

check "upstream_contract_versions" {
  assert {
    condition = (
      local.foundation.schema_version == 1 &&
      local.api.schema_version == 1 &&
      local.campaign.schema_version == 1 &&
      local.api.environment == var.environment &&
      local.campaign.environment == var.environment
    )
    error_message = "Campaign API received an incompatible or cross-environment state contract."
  }
}

check "enabled_dependencies" {
  assert {
    condition = (
      !local.any_enabled ||
      (
        local.campaign.enabled &&
        local.api.campaign_intelligence_enabled &&
        local.api.api_id != null &&
        local.api.execution_arn != null &&
        local.api.authorizer_id != null &&
        var.artifact_release != null
      )
    )
    error_message = "Enable campaign data and provide an immutable artifact release before enabling campaign APIs."
  }
}

check "reviewer_identity" {
  assert {
    condition = (
      !var.campaign_review_api_enabled ||
      (var.campaign_reviewer_username != null && length(trim(var.campaign_reviewer_username, " ")) > 0)
    )
    error_message = "campaign_reviewer_username is required when the review API is enabled."
  }
}

check "environment_promotion_gate" {
  assert {
    condition     = !local.any_enabled || var.environment == "dev" || var.promotion_approved
    error_message = "UAT and Production campaign APIs require promotion_approved=true."
  }
}

check "api_contract_bounds" {
  assert {
    condition = (
      var.trends_path == "/v1/scam-trends" &&
      var.review_path == "/v1/internal/campaigns/{campaignId}/transitions" &&
      var.maximum_page_size >= 1 &&
      var.maximum_page_size <= 100 &&
      var.pagination_token_ttl_seconds >= 60 &&
      var.pagination_token_ttl_seconds <= 3600 &&
      var.trends_memory_mb >= 128 &&
      var.trends_memory_mb <= 1024 &&
      var.review_memory_mb >= 128 &&
      var.review_memory_mb <= 1024 &&
      var.lambda_timeout_seconds <= 15 &&
      var.reserved_concurrency >= 1 &&
      var.reserved_concurrency <= 10
    )
    error_message = "Campaign route, pagination, timeout, or concurrency is outside the approved V1 bounds."
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

resource "aws_cognito_user_group" "campaign_reviewer" {
  count = var.campaign_review_api_enabled ? 1 : 0

  name         = "campaign-reviewer"
  user_pool_id = local.foundation.cognito_user_pool_id
  description  = "Sole V1 campaign reviewer; membership is Terraform-managed"
  precedence   = 10
}

resource "aws_cognito_user_in_group" "campaign_reviewer" {
  count = var.campaign_review_api_enabled ? 1 : 0

  user_pool_id = local.foundation.cognito_user_pool_id
  group_name   = aws_cognito_user_group.campaign_reviewer[0].name
  username     = var.campaign_reviewer_username
}

resource "aws_iam_role" "trends" {
  count = local.enabled ? 1 : 0

  name               = "${local.name_prefix}-trends-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "trends" {
  count = local.enabled ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-trends"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    DataClass = "content-free-operational"
  })
}

data "aws_iam_policy_document" "trends_runtime" {
  count = local.enabled ? 1 : 0

  statement {
    sid    = "ReadPublishedAggregatesOnly"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = [
      local.campaign.intelligence_table_arn,
      "${local.campaign.intelligence_table_arn}/index/${local.campaign.publication_index_name}",
    ]
  }

  statement {
    sid     = "DenyTransientCampaignData"
    effect  = "Deny"
    actions = ["dynamodb:*"]
    resources = [
      local.campaign.outbox_table_arn,
      local.campaign.pipeline_table_arn,
      "${local.campaign.pipeline_table_arn}/index/*",
    ]
  }

  statement {
    sid     = "DenyIdentityData"
    effect  = "Deny"
    actions = ["dynamodb:*"]
    resources = [
      local.foundation.users_table_arn,
      "${local.foundation.users_table_arn}/index/*",
    ]
  }

  statement {
    sid       = "DenyContributorMac"
    effect    = "Deny"
    actions   = ["kms:GenerateMac"]
    resources = ["*"]
  }

  statement {
    sid    = "UsePersistentEncryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]
    resources = [local.campaign.persistent_kms_key_arn]
  }

  statement {
    sid    = "WriteOwnContentFreeLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.trends[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "trends_runtime" {
  count = local.enabled ? 1 : 0

  name   = "trends-runtime"
  role   = aws_iam_role.trends[0].id
  policy = data.aws_iam_policy_document.trends_runtime[0].json
}

resource "aws_lambda_function" "trends" {
  count = local.enabled ? 1 : 0

  function_name = "${local.name_prefix}-trends"
  description   = "Returns privacy-thresholded confirmed campaign summaries"
  role          = aws_iam_role.trends[0].arn
  runtime       = "python3.13"
  handler       = "app.lambda_handler"

  timeout                        = var.lambda_timeout_seconds
  memory_size                    = var.trends_memory_mb
  architectures                  = ["arm64"]
  reserved_concurrent_executions = var.reserved_concurrency

  s3_bucket = local.foundation.artifact_bucket_name
  s3_key    = "releases/${var.artifact_release}/${var.trends_artifact_name}"

  environment {
    variables = {
      APP_ENVIRONMENT           = var.environment
      CAMPAIGN_SCHEMA_VERSION   = "1"
      INTELLIGENCE_TABLE_NAME   = local.campaign.intelligence_table_name
      PUBLICATION_INDEX_NAME    = local.campaign.publication_index_name
      MIN_CONTRIBUTOR_COUNT     = "10"
      MAXIMUM_PAGE_SIZE         = tostring(var.maximum_page_size)
      PAGINATION_TOKEN_TTL_SECS = tostring(var.pagination_token_ttl_seconds)
      PUBLIC_COUNT_BANDS        = "10-24,25-49,50-99,100-249,250+"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.trends,
    aws_iam_role_policy.trends_runtime,
  ]

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "trends" {
  count = local.enabled ? 1 : 0

  api_id                 = local.api.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.trends[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = var.lambda_timeout_seconds * 1000
}

resource "aws_apigatewayv2_route" "trends" {
  count = local.enabled ? 1 : 0

  api_id             = local.api.api_id
  route_key          = "GET ${var.trends_path}"
  target             = "integrations/${aws_apigatewayv2_integration.trends[0].id}"
  authorization_type = "JWT"
  authorizer_id      = local.api.authorizer_id
}

resource "aws_lambda_permission" "trends" {
  count = local.enabled ? 1 : 0

  statement_id  = "AllowCampaignTrendsFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trends[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${local.api.execution_arn}/*/GET${var.trends_path}"
}

resource "aws_iam_role" "review" {
  count = var.campaign_review_api_enabled ? 1 : 0

  name               = "${local.name_prefix}-review-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "review" {
  count = var.campaign_review_api_enabled ? 1 : 0

  name              = "/aws/lambda/${local.name_prefix}-review"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    DataClass = "content-free-operational"
  })
}

data "aws_iam_policy_document" "review_runtime" {
  count = var.campaign_review_api_enabled ? 1 : 0

  statement {
    sid    = "ReviewAggregateTransitions"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
    ]
    resources = [
      local.campaign.intelligence_table_arn,
      "${local.campaign.intelligence_table_arn}/index/${local.campaign.publication_index_name}",
    ]
  }

  statement {
    sid     = "DenyTransientAndIdentityData"
    effect  = "Deny"
    actions = ["dynamodb:*"]
    resources = [
      local.campaign.outbox_table_arn,
      local.campaign.pipeline_table_arn,
      "${local.campaign.pipeline_table_arn}/index/*",
      local.foundation.users_table_arn,
      "${local.foundation.users_table_arn}/index/*",
    ]
  }

  statement {
    sid       = "DenyContributorMac"
    effect    = "Deny"
    actions   = ["kms:GenerateMac"]
    resources = ["*"]
  }

  statement {
    sid    = "UsePersistentEncryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]
    resources = [local.campaign.persistent_kms_key_arn]
  }

  statement {
    sid    = "WriteOwnContentFreeLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.review[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "review_runtime" {
  count = var.campaign_review_api_enabled ? 1 : 0

  name   = "review-runtime"
  role   = aws_iam_role.review[0].id
  policy = data.aws_iam_policy_document.review_runtime[0].json
}

resource "aws_lambda_function" "review" {
  count = var.campaign_review_api_enabled ? 1 : 0

  function_name = "${local.name_prefix}-review"
  description   = "Performs audited campaign review transitions for the sole authorized reviewer"
  role          = aws_iam_role.review[0].arn
  runtime       = "python3.13"
  handler       = "app.lambda_handler"

  timeout                        = var.lambda_timeout_seconds
  memory_size                    = var.review_memory_mb
  architectures                  = ["arm64"]
  reserved_concurrent_executions = 1

  s3_bucket = local.foundation.artifact_bucket_name
  s3_key    = "releases/${var.artifact_release}/${var.review_artifact_name}"

  environment {
    variables = {
      APP_ENVIRONMENT         = var.environment
      CAMPAIGN_SCHEMA_VERSION = "1"
      INTELLIGENCE_TABLE_NAME = local.campaign.intelligence_table_name
      PUBLICATION_INDEX_NAME  = local.campaign.publication_index_name
      REVIEWER_GROUP          = aws_cognito_user_group.campaign_reviewer[0].name
      MIN_CONTRIBUTOR_COUNT   = "10"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.review,
    aws_iam_role_policy.review_runtime,
  ]

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "review" {
  count = var.campaign_review_api_enabled ? 1 : 0

  api_id                 = local.api.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.review[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = var.lambda_timeout_seconds * 1000
}

resource "aws_apigatewayv2_route" "review" {
  count = var.campaign_review_api_enabled ? 1 : 0

  api_id             = local.api.api_id
  route_key          = "POST ${var.review_path}"
  target             = "integrations/${aws_apigatewayv2_integration.review[0].id}"
  authorization_type = "JWT"
  authorizer_id      = local.api.authorizer_id
}

resource "aws_lambda_permission" "review" {
  count = var.campaign_review_api_enabled ? 1 : 0

  statement_id  = "AllowCampaignReviewFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.review[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${local.api.execution_arn}/*/POST/v1/internal/campaigns/*/transitions"
}

resource "aws_cloudwatch_metric_alarm" "api_errors" {
  for_each = merge(
    local.enabled ? { trends = aws_lambda_function.trends[0].function_name } : {},
    var.campaign_review_api_enabled ? { review = aws_lambda_function.review[0].function_name } : {},
  )

  alarm_name          = "${each.value}-errors"
  alarm_description   = "Campaign API Lambda errors; notifications must remain content-free"
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

resource "aws_cloudwatch_metric_alarm" "api_throttles" {
  for_each = merge(
    local.enabled ? { trends = aws_lambda_function.trends[0].function_name } : {},
    var.campaign_review_api_enabled ? { review = aws_lambda_function.review[0].function_name } : {},
  )

  alarm_name          = "${each.value}-throttles"
  alarm_description   = "Campaign API Lambda is throttled"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
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

resource "aws_cloudwatch_dashboard" "api" {
  count = local.any_enabled ? 1 : 0

  dashboard_name = "${local.name_prefix}-api"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          title  = "Campaign API health"
          region = var.aws_region
          stat   = "Sum"
          period = 300
          metrics = concat(
            [
              for name in compact([
                local.enabled ? aws_lambda_function.trends[0].function_name : null,
                var.campaign_review_api_enabled ? aws_lambda_function.review[0].function_name : null,
              ]) : ["AWS/Lambda", "Invocations", "FunctionName", name]
            ],
            [
              for name in compact([
                local.enabled ? aws_lambda_function.trends[0].function_name : null,
                var.campaign_review_api_enabled ? aws_lambda_function.review[0].function_name : null,
              ]) : ["AWS/Lambda", "Errors", "FunctionName", name]
            ],
            [
              for name in compact([
                local.enabled ? aws_lambda_function.trends[0].function_name : null,
                var.campaign_review_api_enabled ? aws_lambda_function.review[0].function_name : null,
              ]) : ["AWS/Lambda", "Throttles", "FunctionName", name]
            ],
          )
        }
      },
    ]
  })
}
