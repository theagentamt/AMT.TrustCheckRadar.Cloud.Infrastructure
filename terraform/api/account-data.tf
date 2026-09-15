variable "account_data_deployment" {
  description = "Immutable disabled account-data candidate. Public routing and activation await complete inventory, cleanup, revocation recovery and finalization acceptance."
  type = object({
    release_id         = string
    object_version     = string
    source_hash        = string
    approval_reference = string
    promotion_approved = bool
  })
  default = null
  validation {
    condition = var.account_data_deployment == null ? true : try(
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.account_data_deployment.release_id)) &&
      length(trimspace(var.account_data_deployment.object_version)) > 0 && var.account_data_deployment.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.account_data_deployment.source_hash)) &&
      length(trimspace(var.account_data_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.account_data_deployment.promotion_approved), false
    )
    error_message = "Account-data candidates require version/hash pinning, approval reference and separate UAT/Prod promotion approval."
  }
}

locals {
  account_data_name       = "${local.name_prefix}-account-data-api"
  account_data_pool_arn   = "arn:aws:cognito-idp:${var.aws_region}:${split(":", local.users_table_arn)[4]}:userpool/${local.cognito_user_pool_id}"
  account_data_stream_arn = try(local.foundation.deletion_ledger_stream_arn, null)
}

resource "aws_cloudwatch_log_group" "account_data" {
  count             = var.account_data_deployment == null ? 0 : 1
  name              = "/aws/lambda/${local.account_data_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_iam_role" "account_data" {
  count              = var.account_data_deployment == null ? 0 : 1
  name               = "${local.account_data_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "account_data" {
  count = var.account_data_deployment == null ? 0 : 1
  statement {
    sid       = "TransactionallyFenceAuthoritativeProfile"
    actions   = ["dynamodb:UpdateItem"]
    resources = [local.users_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
    condition {
      test     = "StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
  }
  # IAM LeadingKeys constrains PK, not SK. The reviewed handler must enforce
  # Fixed ACCOUNT_DELETION commands and the reviewed component/progress keys.
  statement {
    sid       = "ReadCommandAndWriteRevocationReceipt"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [local.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCOUNT#*"]
    }
  }
  statement {
    sid       = "EraseFencedUserDeviceBindings"
    actions   = ["dynamodb:Query", "dynamodb:DeleteItem"]
    resources = [local.device_bindings_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }
  statement {
    sid       = "ReconcileMissedRevocations"
    actions   = ["dynamodb:Scan"]
    resources = [local.deletion_ledger_table_arn]
  }
  dynamic "statement" {
    for_each = local.recovery_storage_valid ? [1] : []
    content {
      sid       = "MinimizeFencedUserRecoveryEvidence"
      actions   = ["dynamodb:Query", "dynamodb:PutItem", "dynamodb:DeleteItem"]
      resources = [local.recovery_storage.table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["USER#*"]
      }
    }
  }
  statement {
    sid       = "PersistOwnReconciliationCheckpoint"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [local.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["LIFECYCLE#${var.environment}"]
    }
  }
  statement {
    sid       = "RevokeSessionsInOwnPool"
    actions   = ["cognito-idp:AdminUserGlobalSignOut"]
    resources = [local.account_data_pool_arn]
  }
  statement {
    sid       = "ReadOwnDeletionStream"
    actions   = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"]
    resources = compact([local.account_data_stream_arn])
  }
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.account_data[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "account_data" {
  count  = var.account_data_deployment == null ? 0 : 1
  name   = "account-data-runtime"
  role   = aws_iam_role.account_data[0].id
  policy = data.aws_iam_policy_document.account_data[0].json
}

resource "aws_lambda_function" "account_data" {
  count                          = var.account_data_deployment == null ? 0 : 1
  function_name                  = local.account_data_name
  role                           = aws_iam_role.account_data[0].arn
  runtime                        = "python3.13"
  architectures                  = ["arm64"]
  handler                        = "app.lambda_handler"
  memory_size                    = 256
  timeout                        = 30
  reserved_concurrent_executions = 1
  s3_bucket                      = local.foundation.artifact_bucket_name
  s3_key                         = "releases/${var.account_data_deployment.release_id}/account_data_api.zip"
  s3_object_version              = var.account_data_deployment.object_version
  source_code_hash               = var.account_data_deployment.source_hash
  environment {
    variables = {
      APP_ENVIRONMENT                            = var.environment
      USERS_TABLE_NAME                           = local.users_table_name
      DELETION_LEDGER_TABLE_NAME                 = local.deletion_ledger_table_name
      DEVICE_BINDINGS_TABLE_NAME                 = local.device_bindings_table_name
      DEVICE_RECOVERY_CONTROL_TABLE_NAME         = local.recovery_storage_valid ? local.recovery_storage.table_name : ""
      ACCOUNT_DELETION_RECOVERY_DELETE_PAGE_SIZE = "100"
      DEVICE_RECOVERY_RECEIPT_RETENTION_DAYS     = "7"
      DEVICE_RECOVERY_AUDIT_RETENTION_DAYS       = "90"
      DEVICE_RECOVERY_RATE_STATE_TTL_SECONDS     = "86400"
      ACCOUNT_DELETION_RECEIPT_RETENTION_DAYS    = "120"
      COGNITO_ISSUER                             = local.jwt_issuer
      COGNITO_APP_CLIENT_ID                      = local.cognito_app_client_id
      COGNITO_USER_POOL_ID                       = local.cognito_user_pool_id
      COGNITO_REQUIRED_SCOPE                     = "aws.cognito.signin.user.admin"
      COGNITO_USERNAME_IS_SUB                    = "false"
      ACCOUNT_DELETION_ENABLED                   = "false"
      ACCOUNT_DELETION_POLICY_STATUS             = "pending"
      ACCOUNT_DELETION_COMPLETION_STATUS         = "incomplete"
      ACCOUNT_DELETION_RECONCILIATION_SCAN_LIMIT = "100"
      ACCOUNT_DELETION_RECONCILIATION_MAX_PAGES  = "10"
      ACCOUNT_DELETION_DEVICE_DELETE_PAGE_SIZE   = "100"
      ACCOUNT_DATA_INVENTORY_STATUS              = "pending"
      ACCOUNT_DELETION_REQUIRED_COMPONENTS_JSON  = "[]"
      ACCOUNT_DELETION_MAX_REAUTH_AGE_SECONDS    = "300"
      ACCOUNT_DELETION_SLA_HOURS                 = "24"
    }
  }
  lifecycle {
    precondition {
      condition = try(
        local.users_table_name == "${local.name_prefix}-users" &&
        local.deletion_ledger_table_name == "${local.name_prefix}-deletion-ledger" &&
        local.device_bindings_table_name == "${local.name_prefix}-device-bindings" &&
        local.device_bindings_table_arn == "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.device_bindings_table_name}" &&
        local.users_table_arn == "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.users_table_name}" &&
        local.deletion_ledger_table_arn == "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.deletion_ledger_table_name}" &&
        startswith(local.account_data_stream_arn, "${local.deletion_ledger_table_arn}/stream/") &&
        startswith(local.cognito_user_pool_id, "${var.aws_region}_"), false
      )
      error_message = "Account-data candidates require matching environment tables, account/Region and the exact deletion-ledger stream."
    }
  }
  depends_on = [aws_iam_role_policy.account_data]
  tags       = local.common_tags
}

resource "aws_lambda_event_source_mapping" "account_data_revocation" {
  count                          = var.account_data_deployment == null ? 0 : 1
  event_source_arn               = local.account_data_stream_arn
  function_name                  = aws_lambda_function.account_data[0].arn
  enabled                        = false
  starting_position              = "TRIM_HORIZON"
  batch_size                     = 10
  parallelization_factor         = 1
  bisect_batch_on_function_error = true
  maximum_retry_attempts         = -1
  function_response_types        = ["ReportBatchItemFailures"]
  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT", "MODIFY"]
        dynamodb = { NewImage = {
          PK            = { S = [{ prefix = "ACCOUNT#" }] }
          SK            = { S = ["ACCOUNT_DELETION"] }
          eventType     = { S = ["account.deletion.requested"] }
          environment   = { S = [var.environment] }
          schemaVersion = { N = ["1"] }
          status        = { S = ["REQUESTED"] }
        } }
      })
    }
  }
  depends_on = [aws_iam_role_policy.account_data]
}

resource "aws_cloudwatch_event_rule" "account_data_reconcile" {
  count               = var.account_data_deployment == null ? 0 : 1
  name                = "${local.name_prefix}-account-deletion-reconcile"
  schedule_expression = "rate(5 minutes)"
  state               = "DISABLED"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "account_data_reconcile" {
  count = var.account_data_deployment == null ? 0 : 1
  rule  = aws_cloudwatch_event_rule.account_data_reconcile[0].name
  arn   = aws_lambda_function.account_data[0].arn
  input = jsonencode({ schemaVersion = 1, operation = "reconcile-session-revocation" })
  retry_policy {
    maximum_event_age_in_seconds = 300
    maximum_retry_attempts       = 1
  }
}

resource "aws_lambda_permission" "account_data_reconcile" {
  count         = var.account_data_deployment == null ? 0 : 1
  statement_id  = "AllowAccountDeletionReconciliation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.account_data[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.account_data_reconcile[0].arn
}

resource "aws_lambda_function_event_invoke_config" "account_data_reconcile" {
  count                        = var.account_data_deployment == null ? 0 : 1
  function_name                = aws_lambda_function.account_data[0].function_name
  maximum_event_age_in_seconds = 300
  maximum_retry_attempts       = 1
}

output "account_data_candidate_contract" {
  value = {
    schema_version                        = 1
    environment                           = var.environment
    deployed                              = var.account_data_deployment != null
    enabled                               = false
    routes                                = []
    planned_routes                        = ["POST /v1/users/account-deletion", "GET /v1/users/account-deletion"]
    full_account_export_available         = false
    overall_deletion_completion_available = false
    function_arn                          = try(aws_lambda_function.account_data[0].arn, null)
  }
}
