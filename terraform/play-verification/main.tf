data "aws_caller_identity" "current" {}
locals {
  name = "${var.project_name}-${var.environment}-v1-play-handoff"
  identity_arns = var.deployment == null ? [] : [
    var.deployment.users_table_arn, var.deployment.devices_table_arn, var.deployment.deletion_table_arn
  ]
}
resource "aws_cloudwatch_log_group" "runtime" {
  count             = var.enabled ? 1 : 0
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 14
  tags              = var.tags
}
resource "aws_iam_role" "runtime" {
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
  name  = "verified-play-ownership-and-authority"
  role  = aws_iam_role.runtime[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.runtime[0].arn}:*" },
      { Sid = "ReadIdentityFences", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = local.identity_arns },
      { Sid       = "ReadPurchaseAndAuthority", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = var.deployment.authority_table_arn,
        Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*", "PURCHASE#CONTROL", "TOKEN#*", "USER#*"] } }
      },
      { Sid = "AtomicPurchaseAndAuthority", Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = var.deployment.authority_table_arn,
        Condition = {
          "ForAllValues:StringLike"  = { "dynamodb:LeadingKeys" = ["V1#*#*", "TOKEN#*", "USER#*"] }
          "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] }
        }
      },
      { Sid       = "ExactExistingSecrets", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = [var.deployment.authority_hmac_secret_arn, var.deployment.google_play_secret_arn],
        Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } }
      },
      { Sid = "NoOtherServiceOrDestructiveAccess", Effect = "Deny", Action = ["lambda:InvokeFunction", "s3:*", "ssm:*", "sts:AssumeRole", "dynamodb:Scan", "dynamodb:Query", "dynamodb:DeleteItem", "dynamodb:UpdateItem"], Resource = "*" }
    ]
  })
  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == "107827791950"
      error_message = "The inactive candidate is restricted to the reviewed Dev account."
    }
  }
}
resource "aws_lambda_function" "runtime" {
  count                          = var.enabled ? 1 : 0
  function_name                  = local.name
  role                           = aws_iam_role.runtime[0].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = "v1_play_handoff.app.lambda_handler"
  timeout                        = 29
  memory_size                    = 256
  reserved_concurrent_executions = 2
  s3_bucket                      = var.deployment.artifact.bucket
  s3_key                         = var.deployment.artifact.key
  s3_object_version              = var.deployment.artifact.object_version
  source_code_hash               = var.deployment.artifact.source_hash
  publish                        = true
  environment {
    variables = {
      STAGE                                  = var.environment
      PLAY_HANDOFF_ENABLED                   = "false"
      AUTHORITY_ENABLED                      = "false"
      DEV_SUBJECT_ALLOWLIST_JSON             = "[]"
      PLAY_CATALOG_P1M_VERIFIED              = tostring(var.catalog_p1m_verified)
      PLAY_REQUIRE_TEST_PURCHASES            = "true"
      USERS_TABLE_NAME                       = split("/", var.deployment.users_table_arn)[1]
      DEVICE_BINDINGS_TABLE_NAME             = split("/", var.deployment.devices_table_arn)[1]
      DELETION_LEDGER_TABLE_NAME             = split("/", var.deployment.deletion_table_arn)[1]
      AUTHORITY_TABLE_NAME                   = split("/", var.deployment.authority_table_arn)[1]
      PURCHASE_OWNERSHIP_TABLE_NAME          = split("/", var.deployment.authority_table_arn)[1]
      AUTHORITY_HMAC_SECRET_ARN              = var.deployment.authority_hmac_secret_arn
      GOOGLE_PLAY_SERVICE_ACCOUNT_SECRET_ARN = var.deployment.google_play_secret_arn
      COGNITO_ISSUER                         = var.deployment.cognito_issuer
      COGNITO_APP_CLIENT_ID                  = var.deployment.cognito_app_client_id
      COGNITO_REQUIRED_SCOPE                 = "aws.cognito.signin.user.admin"
      AUTHORITY_POLICY_VERSION               = "owner-2026-09-20-v1"
      GOOGLE_PLAY_PACKAGE_NAME               = var.deployment.package_name
      GOOGLE_PLAY_PRODUCT_ID                 = var.deployment.product_id
      GOOGLE_PLAY_BASE_PLAN_ID               = var.deployment.base_plan_id
      GOOGLE_PLAY_BILLING_PERIOD             = "P1M"
      OPERATION_VALIDITY_SECONDS             = "300"
      WORKER_SETTLEMENT_SECONDS              = "60"
      RECONCILIATION_SECONDS                 = "3600"
      RECEIPT_RETENTION_SECONDS              = "604800"
      COUNTER_RETENTION_SECONDS              = "604800"
      ATTEMPT_WINDOW_SECONDS                 = "60"
      ATTEMPTS_PER_WINDOW                    = "20"
      MAX_INFLIGHT                           = "2"
    }
  }
  depends_on = [aws_iam_role_policy.runtime]
  tags       = var.tags
}
resource "aws_lambda_alias" "runtime" {
  count            = var.enabled ? 1 : 0
  name             = "live"
  function_name    = aws_lambda_function.runtime[0].function_name
  function_version = aws_lambda_function.runtime[0].version
}
resource "aws_lambda_function_event_invoke_config" "runtime" {
  count                        = var.enabled ? 1 : 0
  function_name                = aws_lambda_function.runtime[0].function_name
  qualifier                    = aws_lambda_alias.runtime[0].name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}
