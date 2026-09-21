data "aws_caller_identity" "current" {}
locals {
  prefix = "${var.project_name}-${var.environment}"
  functions = var.enabled ? {
    consumer  = { suffix = "message-consumer", timeout = 29, concurrency = 2, handler = "message_consumer.app.lambda_handler" }
    evaluator = { suffix = "message-evaluator", timeout = 23, concurrency = 2, handler = "message_evaluator.app.lambda_handler" }
  } : {}
  identity_arns       = var.deployment == null ? [] : [var.deployment.users_table_arn, var.deployment.devices_table_arn, var.deployment.deletion_table_arn]
  authority_arn       = try(var.deployment.authority_table_arn, "")
  evaluator_alias_arn = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.prefix}-message-evaluator:live"
}
resource "aws_cloudwatch_log_group" "runtime" {
  for_each          = local.functions
  name              = "/aws/lambda/${local.prefix}-${each.value.suffix}"
  retention_in_days = 14
  tags              = var.tags
}
resource "aws_iam_role" "runtime" {
  for_each = local.functions
  name     = "${local.prefix}-${each.value.suffix}-execution"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = var.tags
}
resource "aws_iam_role_policy" "consumer" {
  count = var.enabled ? 1 : 0
  name  = "fenced-message-authority-and-private-evaluator"
  role  = aws_iam_role.runtime["consumer"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.runtime["consumer"].arn}:*" },
      { Sid = "ReadIdentityFences", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = local.identity_arns },
      { Sid = "ReadAuthority", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*"] } } },
      { Sid = "AtomicAuthorityMutations", Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:UpdateItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
      { Sid = "ExistingHmacKeyRing", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.deployment.authority_hmac_secret_arn,
      Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } },
      { Sid = "OnePrivateEvaluatorAlias", Effect = "Allow", Action = "lambda:InvokeFunction", Resource = local.evaluator_alias_arn },
      { Sid = "NoObjectStorageOrRoleChaining", Effect = "Deny", Action = ["s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
    ]
  })
  lifecycle {
    precondition {
      condition     = alltrue([for arn in concat(local.identity_arns, [local.authority_arn, var.deployment.authority_hmac_secret_arn, var.deployment.assessment_alias_arn]) : split(":", arn)[4] == data.aws_caller_identity.current.account_id])
      error_message = "Message dependencies must all belong to the current AWS account."
    }
  }
}
resource "aws_iam_role_policy" "evaluator" {
  count = var.enabled ? 1 : 0
  name  = "private-message-evaluation-only"
  role  = aws_iam_role.runtime["evaluator"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.runtime["evaluator"].arn}:*" },
      { Sid = "OneReviewedUrlAssessmentAlias", Effect = "Allow", Action = "lambda:InvokeFunction", Resource = var.deployment.assessment_alias_arn },
      { Sid = "NoConsumerStorageSecretsOrRoleChaining", Effect = "Deny", Action = ["dynamodb:*", "secretsmanager:*", "s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
    ]
  })
}
resource "aws_lambda_function" "runtime" {
  for_each                       = local.functions
  function_name                  = "${local.prefix}-${each.value.suffix}"
  role                           = aws_iam_role.runtime[each.key].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = each.value.handler
  timeout                        = each.value.timeout
  memory_size                    = 256
  reserved_concurrent_executions = each.value.concurrency
  s3_bucket                      = var.deployment.artifacts[each.key].bucket
  s3_key                         = var.deployment.artifacts[each.key].key
  s3_object_version              = var.deployment.artifacts[each.key].object_version
  source_code_hash               = var.deployment.artifacts[each.key].source_hash
  publish                        = true
  environment {
    variables = merge({
      STAGE                          = var.environment
      MESSAGE_POLICY_VERSION         = "message-rules-2026-09-20-v1"
      MESSAGE_POLICY_APPROVAL_SHA256 = "0367140fbdbaef36dd59ba81030f3e35e04e78dbbed4129277c9cb0758971a80"
      }, each.key == "consumer" ? {
      MESSAGE_CONSUMER_ENABLED       = "false"
      AUTHORITY_ENABLED              = "false"
      AUTHORITY_TABLE_NAME           = split("/", local.authority_arn)[1]
      USERS_TABLE_NAME               = split("/", var.deployment.users_table_arn)[1]
      DEVICE_BINDINGS_TABLE_NAME     = split("/", var.deployment.devices_table_arn)[1]
      DELETION_LEDGER_TABLE_NAME     = split("/", var.deployment.deletion_table_arn)[1]
      COGNITO_ISSUER                 = var.deployment.cognito_issuer
      COGNITO_APP_CLIENT_ID          = var.deployment.cognito_app_client_id
      COGNITO_REQUIRED_SCOPE         = "aws.cognito.signin.user.admin"
      AUTHORITY_HMAC_SECRET_ARN      = var.deployment.authority_hmac_secret_arn
      AUTHORITY_POLICY_VERSION       = "owner-2026-09-20-v1"
      MESSAGE_EVALUATOR_FUNCTION_ARN = local.evaluator_alias_arn
      MESSAGE_PROVIDER_CIRCUIT_OPEN  = "true"
      } : {
      MESSAGE_EVALUATOR_ENABLED   = "false"
      MESSAGE_PROPOSER_ENABLED    = "false"
      URL_ASSESSMENT_FUNCTION_ARN = var.deployment.assessment_alias_arn
    })
  }
  depends_on = [aws_iam_role_policy.consumer, aws_iam_role_policy.evaluator]
  tags       = var.tags
}
resource "aws_lambda_alias" "runtime" {
  for_each         = local.functions
  name             = "live"
  function_name    = aws_lambda_function.runtime[each.key].function_name
  function_version = aws_lambda_function.runtime[each.key].version
}
resource "aws_lambda_function_event_invoke_config" "no_async_retries" {
  for_each                     = local.functions
  function_name                = aws_lambda_function.runtime[each.key].function_name
  qualifier                    = aws_lambda_alias.runtime[each.key].name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}
