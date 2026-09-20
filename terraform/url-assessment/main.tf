data "aws_caller_identity" "current" {}
locals {
  name = "${var.project_name}-${var.environment}-url-assessment"
}
resource "aws_cloudwatch_log_group" "assessment" {
  count             = var.enabled ? 1 : 0
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 14
  tags              = var.tags
}
resource "aws_iam_role" "assessment" {
  count = var.enabled ? 1 : 0
  name  = "${local.name}-execution"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = var.tags
}
resource "aws_iam_role_policy" "runtime" {
  count = var.enabled ? 1 : 0
  name  = "private-lookup-and-resolver"
  role  = aws_iam_role.assessment[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.assessment[0].arn}:*" },
      { Sid = "ReadOneProviderCredential", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.secret_arn },
      { Sid = "InvokeResolverAlias", Effect = "Allow", Action = "lambda:InvokeFunction", Resource = var.resolver_alias_arn },
      { Sid = "NoConsumerStorageOrRoleChaining", Effect = "Deny", Action = ["dynamodb:*", "s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
    ]
  })
  lifecycle {
    precondition {
      condition     = try(split(":", var.secret_arn)[4] == data.aws_caller_identity.current.account_id && split(":", var.secret_arn)[3] == var.aws_region && split(":", var.resolver_alias_arn)[4] == data.aws_caller_identity.current.account_id && split(":", var.resolver_alias_arn)[3] == var.aws_region, false)
      error_message = "Provider secret and resolver must be in this account and region."
    }
  }
}
resource "aws_lambda_function" "assessment" {
  count                          = var.enabled ? 1 : 0
  function_name                  = local.name
  role                           = aws_iam_role.assessment[0].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = "app.lambda_handler"
  memory_size                    = 256
  timeout                        = 35
  reserved_concurrent_executions = var.reserved_concurrency
  s3_bucket                      = var.artifact.bucket
  s3_key                         = var.artifact.key
  s3_object_version              = var.artifact.object_version
  source_code_hash               = var.artifact.source_hash
  publish                        = true
  environment {
    variables = {
      STAGE                     = var.environment
      WEB_RISK_SECRET_ARN       = var.secret_arn
      URL_RESOLVER_FUNCTION_ARN = var.resolver_alias_arn
    }
  }
  depends_on = [aws_iam_role_policy.runtime]
  tags       = var.tags
}
resource "aws_lambda_alias" "assessment" {
  count            = var.enabled ? 1 : 0
  name             = "live"
  function_name    = aws_lambda_function.assessment[0].function_name
  function_version = aws_lambda_function.assessment[0].version
}
resource "aws_lambda_function_event_invoke_config" "no_async_retries" {
  count                        = var.enabled ? 1 : 0
  function_name                = aws_lambda_function.assessment[0].function_name
  qualifier                    = aws_lambda_alias.assessment[0].name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}
resource "aws_iam_role" "dev_test" {
  count                = var.enabled && var.dev_test_principal_arn != null ? 1 : 0
  name                 = "${local.name}-dev-test"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { AWS = var.dev_test_principal_arn } }]
  })
  lifecycle {
    precondition {
      condition     = try(split(":", var.dev_test_principal_arn)[4] == data.aws_caller_identity.current.account_id, false)
      error_message = "The operator test role principal must belong to this account."
    }
  }
  tags = var.tags
}
resource "aws_iam_role_policy" "dev_test" {
  count = var.enabled && var.dev_test_principal_arn != null ? 1 : 0
  name  = "invoke-only-assessment-alias"
  role  = aws_iam_role.dev_test[0].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_alias.assessment[0].arn }]
  })
}
