data "aws_caller_identity" "current" {}
locals {
  prefix  = "${var.project_name}-${var.environment}-url-qualification"
  cleanup = var.enabled && var.cleanup_artifact != null
  tags = merge(var.tags, {
    DataClassification = "synthetic-url-qualification-only"
    BackupPolicy       = "disabled"
  })
}

# No URLs, subjects, proofs or customer records belong in this isolated table.
# Account-wide Backup selections must additionally be checked before activation;
# this tag and PITR=false alone are not evidence that AWS Backup excludes it.
resource "aws_dynamodb_table" "qualification" {
  count                       = var.enabled ? 1 : 0
  name                        = local.prefix
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "PK"
  range_key                   = "SK"
  deletion_protection_enabled = true
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
    name               = "GSI1"
    hash_key           = "GSI1PK"
    range_key          = "GSI1SK"
    projection_type    = "INCLUDE"
    non_key_attributes = ["expiresAt"]
  }
  server_side_encryption { enabled = true }
  point_in_time_recovery { enabled = false }
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
  tags = local.tags
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = data.aws_caller_identity.current.account_id == "107827791950"
      error_message = "Only the existing Dev AWS account is permitted."
    }
  }
}

resource "aws_cloudwatch_log_group" "cleanup" {
  count             = local.cleanup ? 1 : 0
  name              = "/aws/lambda/${local.prefix}-cleanup"
  retention_in_days = 14
  tags              = local.tags
}
resource "aws_iam_role" "cleanup" {
  count = local.cleanup ? 1 : 0
  name  = "${local.prefix}-cleanup"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = local.tags
}
resource "aws_iam_role_policy" "cleanup" {
  count = local.cleanup ? 1 : 0
  name  = "expire-synthetic-qualification-only"
  role  = aws_iam_role.cleanup[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.cleanup[0].arn}:*" },
      { Sid = "ExpiryIndexOnly", Effect = "Allow", Action = "dynamodb:Query", Resource = "${aws_dynamodb_table.qualification[0].arn}/index/GSI1", Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["URL_QUALIFICATION_EXPIRING"] } } },
      { Sid = "ConditionalExpiryOnly", Effect = "Allow", Action = "dynamodb:DeleteItem", Resource = aws_dynamodb_table.qualification[0].arn, Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["RUN#*"] } } },
      { Sid = "CleanupHeartbeatOnly", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:UpdateItem"], Resource = aws_dynamodb_table.qualification[0].arn, Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["CONTROL"] } } },
      { Sid = "NoOtherTables", Effect = "Deny", Action = "dynamodb:*", NotResource = [aws_dynamodb_table.qualification[0].arn, "${aws_dynamodb_table.qualification[0].arn}/index/GSI1"] },
      { Sid = "NoScanBulkWritesOrBackups", Effect = "Deny", Action = ["dynamodb:Scan", "dynamodb:BatchWriteItem", "dynamodb:CreateBackup", "dynamodb:ExportTableToPointInTime", "backup:*"], Resource = "*" },
      { Sid = "NoProvidersSecretsIdentityOrRoleChaining", Effect = "Deny", Action = ["lambda:InvokeFunction", "secretsmanager:*", "cognito-idp:*", "s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
    ]
  })
}
resource "aws_lambda_function" "cleanup" {
  count                          = local.cleanup ? 1 : 0
  function_name                  = "${local.prefix}-cleanup"
  role                           = aws_iam_role.cleanup[0].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = "url_qualification_cleanup.app.lambda_handler"
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 1
  s3_bucket                      = var.cleanup_artifact.bucket
  s3_key                         = var.cleanup_artifact.key
  s3_object_version              = var.cleanup_artifact.object_version
  source_code_hash               = var.cleanup_artifact.source_hash
  publish                        = true
  environment {
    variables = {
      STAGE                        = "dev"
      URL_QUALIFICATION_TABLE_NAME = aws_dynamodb_table.qualification[0].name
      URL_CLEANUP_ENABLED          = tostring(var.cleanup_enabled)
      URL_RETENTION_APPROVED       = tostring(var.retention_approved)
    }
  }
  tags       = local.tags
  depends_on = [aws_iam_role_policy.cleanup]
}
resource "aws_lambda_alias" "cleanup" {
  count            = local.cleanup ? 1 : 0
  name             = "live"
  function_name    = aws_lambda_function.cleanup[0].function_name
  function_version = aws_lambda_function.cleanup[0].version
}
resource "aws_lambda_function_event_invoke_config" "cleanup" {
  count                        = local.cleanup ? 1 : 0
  function_name                = aws_lambda_function.cleanup[0].function_name
  qualifier                    = "live"
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}
resource "aws_scheduler_schedule_group" "cleanup" {
  count = local.cleanup ? 1 : 0
  name  = local.prefix
  tags  = local.tags
}
resource "aws_iam_role" "scheduler" {
  count = local.cleanup ? 1 : 0
  name  = "${local.prefix}-schedule"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "scheduler.amazonaws.com" }, Condition = { StringEquals = { "aws:SourceAccount" = "107827791950" }, ArnEquals = { "aws:SourceArn" = aws_scheduler_schedule_group.cleanup[0].arn } } }]
  })
  tags = local.tags
}
resource "aws_iam_role_policy" "scheduler" {
  count = local.cleanup ? 1 : 0
  name  = "invoke-one-cleanup-alias"
  role  = aws_iam_role.scheduler[0].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_alias.cleanup[0].arn }]
  })
}
resource "aws_scheduler_schedule" "cleanup" {
  count               = local.cleanup ? 1 : 0
  name                = "${local.prefix}-cleanup"
  group_name          = aws_scheduler_schedule_group.cleanup[0].name
  state               = var.cleanup_enabled ? "ENABLED" : "DISABLED"
  schedule_expression = "rate(5 minutes)"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_alias.cleanup[0].arn
    role_arn = aws_iam_role.scheduler[0].arn
    input    = jsonencode({ schemaVersion = 1, operation = "expire_synthetic_url_qualification" })
    retry_policy {
      maximum_event_age_in_seconds = 60
      maximum_retry_attempts       = 0
    }
  }
  depends_on = [aws_iam_role_policy.scheduler]
}

resource "aws_cloudwatch_metric_alarm" "cleanup" {
  for_each = local.cleanup ? {
    errors   = { metric = "Errors", threshold = 1, comparison = "GreaterThanOrEqualToThreshold", missing = "notBreaching", periods = 1 }
    throttle = { metric = "Throttles", threshold = 1, comparison = "GreaterThanOrEqualToThreshold", missing = "notBreaching", periods = 1 }
    missing  = { metric = "Invocations", threshold = 1, comparison = "LessThanThreshold", missing = "breaching", periods = 2 }
  } : {}
  alarm_name          = "${local.prefix}-cleanup-${each.key}"
  namespace           = "AWS/Lambda"
  metric_name         = each.value.metric
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = each.value.periods
  comparison_operator = each.value.comparison
  threshold           = each.value.threshold
  treat_missing_data  = each.value.missing
  dimensions          = { FunctionName = aws_lambda_function.cleanup[0].function_name }
  actions_enabled     = var.cleanup_enabled
  alarm_actions       = var.alert_topic_arn == null ? [] : [var.alert_topic_arn]
  ok_actions          = var.alert_topic_arn == null ? [] : [var.alert_topic_arn]
  tags                = local.tags
}
