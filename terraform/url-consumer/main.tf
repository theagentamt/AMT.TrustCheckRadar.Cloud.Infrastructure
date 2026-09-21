data "aws_caller_identity" "current" {}

locals {
  prefix = "${var.project_name}-${var.environment}"
  functions = merge(var.enabled ? {
    consumer     = { suffix = "url-consumer", timeout = 29, concurrency = 2, handler = "app.lambda_handler" }
    recovery     = { suffix = "url-lease-recovery", timeout = 15, concurrency = 1, handler = "app.lambda_handler" }
    entitlements = { suffix = "v1-entitlements", timeout = 10, concurrency = 2, handler = "v1_entitlements.app.lambda_handler" }
    } : {}, var.enabled && try(contains(keys(var.deployment.artifacts), "deletion"), false) ? {
    deletion = { suffix = "v1-authority-deletion", timeout = 30, concurrency = 1, handler = "v1_authority_deletion.app.lambda_handler" }
  } : {})
  authority_arn = try(var.deployment.authority_table_arn, "")
  identity_arns = var.deployment == null ? [] : [var.deployment.users_table_arn, var.deployment.devices_table_arn, var.deployment.deletion_table_arn]
}

# Only the secret container is managed here. Generate/write its value outside
# Terraform after review so key material never enters source, plan, or state.
resource "aws_secretsmanager_secret" "authority_hmac" {
  count                   = var.enabled ? 1 : 0
  name                    = "${var.project_name}/${var.environment}/v1-authority-hmac"
  description             = "Versioned HMAC key ring for V1 check identity and operation proofs"
  recovery_window_in_days = 30
  tags                    = var.tags
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
  name  = "fenced-check-authority-and-private-assessment"
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
      { Sid = "OneHmacKeyRing", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = aws_secretsmanager_secret.authority_hmac[0].arn,
      Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } },
      { Sid = "OnePrivateAssessmentAlias", Effect = "Allow", Action = "lambda:InvokeFunction", Resource = var.deployment.assessment_alias_arn },
      { Sid = "NoObjectStorageOrRoleChaining", Effect = "Deny", Action = ["s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
    ]
  })
  lifecycle {
    precondition {
      condition     = alltrue([for arn in concat(local.identity_arns, [local.authority_arn, var.deployment.assessment_alias_arn]) : split(":", arn)[4] == data.aws_caller_identity.current.account_id])
      error_message = "All consumer dependencies must belong to the current AWS account."
    }
  }
}

resource "aws_iam_role_policy" "recovery" {
  count = var.enabled ? 1 : 0
  name  = "expired-lease-cleanup-only"
  role  = aws_iam_role.runtime["recovery"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.runtime["recovery"].arn}:*" },
      { Sid = "ReadExistingLease", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*"] } } },
      { Sid = "FindExpiredLeases", Effect = "Allow", Action = "dynamodb:Query", Resource = "${local.authority_arn}/index/GSI1",
      Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["V1_PENDING", "V1_EXPIRING"] } } },
      { Sid = "AtomicLeaseCleanup", Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
      { Sid = "ExpireIndexedRows", Effect = "Allow", Action = ["dynamodb:DeleteItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
      { Sid = "NoProviderIdentitySecretsOrInvocation", Effect = "Deny", Action = ["secretsmanager:*", "lambda:InvokeFunction", "s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
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
      STAGE                = var.environment
      AUTHORITY_TABLE_NAME = split("/", local.authority_arn)[1]
      }, contains(["consumer", "entitlements"], each.key) ? {
      CONSUMER_ENABLED                   = tostring(var.activate_engineering)
      AUTHORITY_ENABLED                  = tostring(var.activate_engineering)
      V1_ENTITLEMENTS_ENABLED            = tostring(var.activate_engineering)
      TRIAL_AUTHORITY_RETENTION_APPROVED = "true"
      USERS_TABLE_NAME                   = split("/", var.deployment.users_table_arn)[1]
      DEVICE_BINDINGS_TABLE_NAME         = split("/", var.deployment.devices_table_arn)[1]
      DELETION_LEDGER_TABLE_NAME         = split("/", var.deployment.deletion_table_arn)[1]
      COGNITO_ISSUER                     = var.deployment.cognito_issuer
      COGNITO_APP_CLIENT_ID              = var.deployment.cognito_app_client_id
      COGNITO_REQUIRED_SCOPE             = "aws.cognito.signin.user.admin"
      AUTHORITY_HMAC_SECRET_ARN          = aws_secretsmanager_secret.authority_hmac[0].arn
      AUTHORITY_POLICY_VERSION           = "owner-2026-09-20-v1"
      DEV_SUBJECT_ALLOWLIST_JSON         = jsonencode(sort(tolist(var.engineering_subjects)))
      } : each.key == "recovery" ? {
      LEASE_SWEEP_ENABLED = tostring(var.activate_engineering)
      } : {
      V1_AUTHORITY_DELETION_ENABLED      = tostring(var.activate_engineering)
      DEV_SUBJECT_ALLOWLIST_JSON         = jsonencode(sort(tolist(var.engineering_subjects)))
      DELETION_LEDGER_TABLE_NAME         = split("/", var.deployment.deletion_table_arn)[1]
      DELETION_LEDGER_STREAM_ARN         = var.deletion_stream_arn
      AUTHORITY_HMAC_SECRET_ARN          = aws_secretsmanager_secret.authority_hmac[0].arn
      DELETION_RECEIPT_RETENTION_SECONDS = "10368000"
      }, contains(["consumer", "entitlements"], each.key) && var.authority_configuration != null ? {
      OPERATION_VALIDITY_SECONDS = tostring(var.authority_configuration.operation_validity_seconds)
      WORKER_SETTLEMENT_SECONDS  = tostring(var.authority_configuration.worker_settlement_seconds)
      RECONCILIATION_SECONDS     = tostring(var.authority_configuration.reconciliation_seconds)
      RECEIPT_RETENTION_SECONDS  = "604800"
      COUNTER_RETENTION_SECONDS  = tostring(var.authority_configuration.counter_retention_seconds)
      ATTEMPT_WINDOW_SECONDS     = "60"
      ATTEMPTS_PER_WINDOW        = "20"
      MAX_INFLIGHT               = "2"
    } : {}, each.key == "consumer" ? { URL_ASSESSMENT_FUNCTION_ARN = var.deployment.assessment_alias_arn } : {})
  }
  depends_on = [aws_iam_role_policy.consumer, aws_iam_role_policy.recovery, aws_iam_role_policy.entitlements, aws_iam_role_policy.deletion]
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
