data "aws_caller_identity" "current" {}
locals {
  prefix = "${var.project_name}-${var.environment}"
  functions = var.enabled ? {
    reader = { suffix = "governed-history", timeout = 23, concurrency = 2, handler = "governed_history.app.lambda_handler" }
  } : {}
  identity_arns = var.deployment == null ? [] : [var.deployment.users_table_arn, var.deployment.devices_table_arn, var.deployment.deletion_table_arn]
  authority_arn = try(var.deployment.authority_table_arn, "")
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
resource "aws_iam_role_policy" "reader" {
  count = var.enabled ? 1 : 0
  name  = "fenced-governed-history-read-only"
  role  = aws_iam_role.runtime["reader"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.prefix}-governed-history:*" },
      ], [for statement in [
        { Sid = "ReadProfileFence", Effect = "Allow", Action = "dynamodb:GetItem", Resource = var.deployment.users_table_arn,
        Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = length(var.engineering_subjects) > 0 ? [for subject in var.engineering_subjects : "USER#${subject}"] : ["DENIED#NO-SUBJECT"], "dynamodb:Attributes" = ["PK", "SK", "sub", "status", "ageVerified"] }, Null = { "dynamodb:Attributes" = "false", "dynamodb:LeadingKeys" = "false" } } },
        { Sid = "ReadDeviceFence", Effect = "Allow", Action = "dynamodb:GetItem", Resource = var.deployment.devices_table_arn,
        Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = length(var.engineering_subjects) > 0 ? [for subject in var.engineering_subjects : "USER#${subject}"] : ["DENIED#NO-SUBJECT"], "dynamodb:Attributes" = ["PK", "SK", "recordType", "bindingFingerprint", "stateVersion", "accountId", "status"] }, Null = { "dynamodb:Attributes" = "false", "dynamodb:LeadingKeys" = "false" } } },
        { Sid = "ReadDeletionFence", Effect = "Allow", Action = "dynamodb:GetItem", Resource = var.deployment.deletion_table_arn,
        Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = length(var.engineering_subjects) > 0 ? [for subject in var.engineering_subjects : "ACCOUNT#${subject}"] : ["DENIED#NO-SUBJECT"], "dynamodb:Attributes" = ["PK", "SK"] }, Null = { "dynamodb:Attributes" = "false", "dynamodb:LeadingKeys" = "false" } } },
        { Sid = "ReadCanonicalReceiptAndInventory", Effect = "Allow", Action = "dynamodb:GetItem", Resource = local.authority_arn,
        Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = concat(["V1#CONTROL"], sort(tolist(var.authority_partitions))), "dynamodb:Attributes" = ["PK", "SK", "recordType", "state", "governedHistory", "governedHistoryDigest", "expiresAt", "retentionDeadlineEpoch", "GSI2PK", "GSI2SK", "schemaVersion", "revision", "coverage", "issuedKeys"] }, Null = { "dynamodb:Attributes" = "false", "dynamodb:LeadingKeys" = "false" } } },
        { Sid = "QuerySparseHistoryIndex", Effect = "Allow", Action = "dynamodb:Query", Resource = "${local.authority_arn}/index/GSI2",
        Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = length(var.authority_partitions) > 0 ? sort(tolist(var.authority_partitions)) : ["DENIED#NO-SUBJECT"], "dynamodb:Attributes" = ["PK", "SK", "GSI2PK", "GSI2SK", "recordType", "state", "governedHistory", "expiresAt"] }, StringEquals = { "dynamodb:Select" = "SPECIFIC_ATTRIBUTES" }, Null = { "dynamodb:Attributes" = "false", "dynamodb:LeadingKeys" = "false" } } },
        { Sid = "ExistingHmacKeyRing", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.deployment.authority_hmac_secret_arn,
        Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } },
      ] : statement if var.list_enabled || var.detail_enabled], [
      { Sid = "NoWritesScanProviderOrObjectStorage", Effect = "Deny", Action = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:BatchWriteItem", "dynamodb:TransactWriteItems", "dynamodb:Scan", "lambda:InvokeFunction", "s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
    ])
  })
  lifecycle {
    precondition {
      condition     = alltrue([for arn in concat(local.identity_arns, [local.authority_arn, var.deployment.authority_hmac_secret_arn]) : split(":", arn)[4] == data.aws_caller_identity.current.account_id])
      error_message = "History dependencies must all belong to the current AWS account."
    }
  }
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
    variables = {
      STAGE                               = var.environment
      AUTHORITY_ENABLED                   = tostring(var.list_enabled || var.detail_enabled)
      AUTHORITY_POLICY_VERSION            = "owner-2026-09-20-v1"
      GOVERNED_HISTORY_INDEX_NAME         = "GSI2"
      GOVERNED_HISTORY_CURSOR_TTL_SECONDS = "900"
      GOVERNED_HISTORY_RETENTION_SECONDS  = "604800"
      GOVERNED_HISTORY_DEFAULT_PAGE_SIZE  = "20"
      GOVERNED_HISTORY_MAX_PAGE_SIZE      = "50"
      GOVERNED_HISTORY_MAX_RESPONSE_BYTES = "262144"
      OPERATION_VALIDITY_SECONDS          = "300"
      WORKER_SETTLEMENT_SECONDS           = "60"
      RECONCILIATION_SECONDS              = "3600"
      RECEIPT_RETENTION_SECONDS           = "604800"
      COUNTER_RETENTION_SECONDS           = "604800"
      ATTEMPT_WINDOW_SECONDS              = "60"
      ATTEMPTS_PER_WINDOW                 = "20"
      MAX_INFLIGHT                        = "2"
      GOVERNED_HISTORY_LIST_ENABLED       = tostring(var.list_enabled)
      GOVERNED_HISTORY_DETAIL_ENABLED     = tostring(var.detail_enabled)
      DEV_SUBJECT_ALLOWLIST_JSON          = jsonencode(sort(tolist(var.engineering_subjects)))
      AUTHORITY_TABLE_NAME                = split("/", local.authority_arn)[1]
      USERS_TABLE_NAME                    = split("/", var.deployment.users_table_arn)[1]
      DEVICE_BINDINGS_TABLE_NAME          = split("/", var.deployment.devices_table_arn)[1]
      DELETION_LEDGER_TABLE_NAME          = split("/", var.deployment.deletion_table_arn)[1]
      COGNITO_ISSUER                      = var.deployment.cognito_issuer
      COGNITO_APP_CLIENT_ID               = var.deployment.cognito_app_client_id
      COGNITO_REQUIRED_SCOPE              = "aws.cognito.signin.user.admin"
      AUTHORITY_HMAC_SECRET_ARN           = var.deployment.authority_hmac_secret_arn
    }
  }
  depends_on = [aws_iam_role_policy.reader]
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
