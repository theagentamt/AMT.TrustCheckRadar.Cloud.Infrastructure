data "aws_caller_identity" "current" {}
locals {
  prefix = "${var.project_name}-${var.environment}"
  functions = var.enabled ? {
    consumer  = { suffix = "message-consumer", timeout = 29, concurrency = 2, handler = "message_consumer.app.lambda_handler" }
    evaluator = { suffix = "message-evaluator", timeout = 23, concurrency = 2, handler = "message_evaluator.app.lambda_handler" }
  } : {}
  identity_arns                = var.deployment == null ? [] : [var.deployment.users_table_arn, var.deployment.devices_table_arn, var.deployment.deletion_table_arn]
  authority_arn                = try(var.deployment.authority_table_arn, "")
  evaluator_alias_arn          = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${local.prefix}-message-evaluator:live"
  provider_permissions_enabled = var.message_ai_primary_enabled || var.dev_staging_secret_arn != null
  provider_secret_arn          = var.message_ai_primary_enabled ? try(var.ai_configuration.secret_arn, null) : var.dev_staging_secret_arn
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
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
      { Sid = "MessageProviderBudget", Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = local.authority_arn,
        Condition = {
          "ForAllValues:StringEquals" = {
            "dynamodb:LeadingKeys" = ["V1#CONTROL"]
            "dynamodb:Attributes"  = concat(["PK", "SK", "recordType", "revision", "windowStart", "attempts", "failures"], local.provider_permissions_enabled ? ["windowSeconds", "reservedNanoUsd", "unpricedAttempts"] : [])
          }
          "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] }
        }
      },
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
    Statement = concat([
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.runtime["evaluator"].arn}:*" },
      { Sid = "OneReviewedUrlAssessmentAlias", Effect = var.url_assessment_enabled ? "Allow" : "Deny", Action = "lambda:InvokeFunction", Resource = var.deployment.assessment_alias_arn },
      { Sid = "NoConsumerStorageSecretsOrRoleChaining", Effect = "Deny", Action = concat(["dynamodb:*"], local.provider_permissions_enabled ? [] : ["secretsmanager:*"], ["s3:*", "ssm:*", "sts:AssumeRole"]), Resource = "*" }
      ], jsondecode(local.provider_permissions_enabled ? jsonencode([
        { Sid = "OneQualifiedProviderSecret", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = local.provider_secret_arn,
        Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } },
        { Sid = "NoOtherSecrets", Effect = "Deny", Action = "secretsmanager:*", NotResource = local.provider_secret_arn },
        { Sid = "NoProviderSecretMutation", Effect = "Deny", NotAction = "secretsmanager:GetSecretValue", Resource = local.provider_secret_arn },
        { Sid = "NoOtherProviderSecretStage", Effect = "Deny", Action = "secretsmanager:GetSecretValue", Resource = local.provider_secret_arn,
        Condition = { StringNotEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } }
    ]) : "[]"))
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
    # Exact fingerprints admit nonsecret configuration/ARN references only.
    # Keep the private profile sensitive, but preserve existing resource marks:
    # marking this unchanged map sensitive alone schedules a Lambda update.
    variables = local.ocr_preservation_enabled ? nonsensitive(var.dev_ocr_preservation.environments[each.key]) : merge({
      STAGE                                 = var.environment
      MESSAGE_POLICY_VERSION                = "message-rules-2026-09-20-v1"
      MESSAGE_POLICY_APPROVAL_SHA256        = "0367140fbdbaef36dd59ba81030f3e35e04e78dbbed4129277c9cb0758971a80"
      MESSAGE_AI_ENABLED                    = tostring(var.message_ai_primary_enabled)
      MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED = tostring(var.candidate3_rules_only_enabled)
      MESSAGE_AI_POLICY_VERSION             = "message-ai-2026-09-21-v1"
      MESSAGE_AI_POLICY_APPROVAL_SHA256     = "d6e9fff12225540bef9ba7833cce457cca4b9c791af3b49dd8a4f1601d204349"
      }, each.key == "consumer" ? {
      GOVERNED_HISTORY_SETTLEMENT_ENABLED = tostring(var.governed_history_settlement_enabled)
      MESSAGE_CONSUMER_ENABLED            = tostring(var.activate_rules_engineering)
      AUTHORITY_ENABLED                   = tostring(var.activate_rules_engineering)
      AUTHORITY_TABLE_NAME                = split("/", local.authority_arn)[1]
      USERS_TABLE_NAME                    = split("/", var.deployment.users_table_arn)[1]
      DEVICE_BINDINGS_TABLE_NAME          = split("/", var.deployment.devices_table_arn)[1]
      DELETION_LEDGER_TABLE_NAME          = split("/", var.deployment.deletion_table_arn)[1]
      COGNITO_ISSUER                      = var.deployment.cognito_issuer
      COGNITO_APP_CLIENT_ID               = var.deployment.cognito_app_client_id
      COGNITO_REQUIRED_SCOPE              = "aws.cognito.signin.user.admin"
      AUTHORITY_HMAC_SECRET_ARN           = var.deployment.authority_hmac_secret_arn
      AUTHORITY_POLICY_VERSION            = "owner-2026-09-20-v1"
      DEV_SUBJECT_ALLOWLIST_JSON          = var.preserved_engineering_subjects_json != null ? var.preserved_engineering_subjects_json : jsonencode(sort(tolist(var.engineering_subjects)))
      MESSAGE_EVALUATOR_FUNCTION_ARN      = local.evaluator_alias_arn
      MESSAGE_PROVIDER_CIRCUIT_OPEN       = tostring(!var.activate_rules_engineering || var.candidate3_rules_only_enabled)
      } : {
      MESSAGE_EVALUATOR_ENABLED   = tostring(var.activate_rules_engineering)
      MESSAGE_PROPOSER_ENABLED    = "false"
      MESSAGE_AI_QUALIFIED        = tostring(var.message_ai_primary_enabled)
      URL_ASSESSMENT_FUNCTION_ARN = var.deployment.assessment_alias_arn
      }, each.key == "consumer" && var.authority_configuration != null ? {
      OPERATION_VALIDITY_SECONDS = tostring(var.authority_configuration.operation_validity_seconds)
      WORKER_SETTLEMENT_SECONDS  = tostring(var.authority_configuration.worker_settlement_seconds)
      RECONCILIATION_SECONDS     = tostring(var.authority_configuration.reconciliation_seconds)
      RECEIPT_RETENTION_SECONDS  = "604800"
      COUNTER_RETENTION_SECONDS  = tostring(var.authority_configuration.counter_retention_seconds)
      ATTEMPT_WINDOW_SECONDS     = "60"
      ATTEMPTS_PER_WINDOW        = "20"
      MAX_INFLIGHT               = "2"
      } : {}, each.key == "consumer" && var.provider_budget != null ? {
      MESSAGE_PROVIDER_WINDOW_SECONDS      = tostring(var.provider_budget.window_seconds)
      MESSAGE_PROVIDER_ATTEMPTS_PER_WINDOW = tostring(var.provider_budget.max_attempts_per_window)
      MESSAGE_PROVIDER_FAILURES_PER_WINDOW = tostring(var.provider_budget.max_failures_per_window)
      } : {}, var.message_ai_primary_enabled ? {
      MESSAGE_AI_PRIMARY_ENABLED = "true"
      MESSAGE_AI_COST_POLICY     = jsonencode(var.ai_configuration.cost_policy)
      } : {}, var.message_ai_primary_enabled && each.key == "consumer" ? {
      MESSAGE_PROVIDER_NANO_USD_PER_WINDOW = tostring(var.ai_configuration.max_nano_usd_per_window)
      } : {}, var.message_ai_primary_enabled && each.key == "evaluator" ? {
      MESSAGE_AI_QUALIFICATION_ID        = var.ai_configuration.qualification_id
      MESSAGE_PROPOSER_MODEL             = var.ai_configuration.cost_policy.model
      MESSAGE_PROPOSER_SECRET_ARN        = var.ai_configuration.secret_arn
      MESSAGE_PROPOSER_TIMEOUT_MS        = tostring(var.ai_configuration.timeout_ms)
      MESSAGE_PROPOSER_MAX_OUTPUT_TOKENS = tostring(var.ai_configuration.cost_policy.maxOutputTokens)
    } : {})
  }
  depends_on = [aws_iam_role_policy.consumer, aws_iam_role_policy.evaluator]
  tags       = var.tags
  lifecycle {
    postcondition {
      condition = !local.ocr_preservation_enabled ? true : (
        self.code_sha256 == (each.key == "consumer" ? "kgUck3tzaq0RSVSuWbS1OW2Q8hNZx6shc2BzEaDa1vU=" : local.ocr_evaluator_code_hash)
      )
      error_message = "OCR preservation must observe exactly the staged consumer and selected evaluator code; use the reviewed CAS rollout, never root apply."
    }
  }
}
resource "aws_lambda_alias" "runtime" {
  for_each         = local.functions
  name             = "live"
  function_name    = aws_lambda_function.runtime[each.key].function_name
  function_version = local.ocr_preservation_enabled ? (each.key == "consumer" ? "8" : nonsensitive(var.dev_ocr_preservation.evaluator_live_version)) : aws_lambda_function.runtime[each.key].version
}
resource "aws_lambda_function_event_invoke_config" "no_async_retries" {
  for_each                     = local.functions
  function_name                = aws_lambda_function.runtime[each.key].function_name
  qualifier                    = aws_lambda_alias.runtime[each.key].name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}
