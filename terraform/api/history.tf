data "terraform_remote_state" "history_data" {
  count   = var.history_deployment != null ? 1 : 0
  backend = "s3"
  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/history-data.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

data "terraform_remote_state" "history_processing" {
  count   = var.history_deployment != null ? 1 : 0
  backend = "s3"
  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/history-processing.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  history_data       = try(data.terraform_remote_state.history_data[0].outputs.downstream_contract, null)
  history_processing = try(data.terraform_remote_state.history_processing[0].outputs.lifecycle_contract, null)
  history_functions = var.history_deployment == null ? {} : {
    read     = { name = "history-read-api", zip = "history_read_api.zip" }
    mutation = { name = "history-mutation-api", zip = "history_mutation_api.zip" }
  }
  history_routes = var.history_deployment == null ? {} : {
    bootstrap = { handler = "mutation", method = "POST", path = "/v1/users/history/bootstrap", permission_path = "v1/users/history/bootstrap" }
    list      = { handler = "read", method = "GET", path = "/v1/users/history", permission_path = "v1/users/history" }
    export    = { handler = "read", method = "GET", path = "/v1/users/history/export", permission_path = "v1/users/history/export" }
    detail    = { handler = "read", method = "GET", path = "/v1/users/history/{requestId}", permission_path = "v1/users/history/*" }
    progress  = { handler = "read", method = "GET", path = "/v1/users/progress", permission_path = "v1/users/progress" }
    delete    = { handler = "mutation", method = "DELETE", path = "/v1/users/history/{requestId}", permission_path = "v1/users/history/*" }
    clear     = { handler = "mutation", method = "DELETE", path = "/v1/users/history", permission_path = "v1/users/history" }
    reset     = { handler = "mutation", method = "POST", path = "/v1/users/progress/reset", permission_path = "v1/users/progress/reset" }
  }
  history_catalog = [for threshold in [1, 5, 20] : {
    id             = "checks_${threshold}"
    threshold      = threshold
    titleKey       = "badges.checks_${threshold}.title"
    descriptionKey = "badges.checks_${threshold}.description"
  }]
  history_common_env = var.history_deployment == null ? {} : {
    APP_ENVIRONMENT                           = var.environment
    COGNITO_USER_POOL_ID                      = local.cognito_user_pool_id
    COGNITO_APP_CLIENT_ID                     = local.cognito_app_client_id
    COGNITO_ISSUER                            = local.jwt_issuer
    COGNITO_REQUIRED_SCOPE                    = "aws.cognito.signin.user.admin"
    HISTORY_CONTENT_TABLE_NAME                = local.history_data.content_table_name
    HISTORY_CONTROL_TABLE_NAME                = local.history_data.control_table_name
    DEVICE_BINDINGS_TABLE_NAME                = local.device_bindings_table_name
    ANALYSIS_ABUSE_TABLE_NAME                 = local.analysis_abuse_control_table_name
    USERS_TABLE_NAME                          = local.users_table_name
    DELETION_LEDGER_TABLE_NAME                = local.deletion_ledger_table_name
    HISTORY_SCHEMA_VERSION                    = "1"
    HISTORY_RETENTION_DAYS                    = "90"
    HISTORY_ERASURE_SLA_HOURS                 = "24"
    HISTORY_EXPIRATION_INDEX_NAME             = "ExpirationIndex"
    HISTORY_LIFECYCLE_INDEX_NAME              = "PendingLifecycleIndex"
    HISTORY_PITR_POLICY_APPROVED              = tostring(local.history_data.storage_policy.approved)
    HISTORY_CONTROL_RETENTION_POLICY_APPROVED = tostring(local.history_data.storage_policy.approved)
    HISTORY_DEDUP_RETENTION_DAYS              = tostring(local.history_data.storage_policy.dedup_retention_seconds / 86400)
    HISTORY_MUTATION_RETENTION_DAYS           = "7"
    HISTORY_API_CONTRACT_STATUS               = "approved"
    HISTORY_RECOGNITION_CONTRACT_STATUS       = "approved"
    HISTORY_CURSOR_TTL_SECONDS                = "900"
    HISTORY_DEFAULT_PAGE_SIZE                 = "20"
    HISTORY_MAX_PAGE_SIZE                     = "50"
    HISTORY_MAX_RESPONSE_BYTES                = "262144"
    HISTORY_MAX_SUMMARY_BYTES                 = "4096"
    HISTORY_MAX_LIST_ITEMS                    = "20"
    HISTORY_MAX_TEXT_FIELD_BYTES              = "1024"
    HISTORY_BADGE_CATALOG_JSON                = jsonencode(local.history_catalog)
    HISTORY_NEW_ID_RECOGNITION_POLICY         = "count"
    HISTORY_BADGE_QUALIFICATION_POLICY        = "all_server_accepted_completed_assessments"
    HISTORY_LIFECYCLE_ENABLED                 = "false"
    HISTORY_READS_ENABLED                     = "false"
    HISTORY_MUTATIONS_ENABLED                 = "false"
    HISTORY_WRITES_ENABLED                    = "false"
    HISTORY_DURABLE_REPLAY_ENABLED            = "false"
    RECOGNITION_ENABLED                       = "false"
  }
  # Read-only settings are irrelevant to analysis; the pinned Lambda carries
  # the validated V1 badge catalog. Keep headroom under the 4 KB env limit.
  history_analysis_env = var.history_deployment == null ? {} : merge({
    for key, value in local.history_common_env : key => value if !contains([
      "COGNITO_USER_POOL_ID", "HISTORY_CURSOR_TTL_SECONDS", "HISTORY_DEFAULT_PAGE_SIZE",
      "HISTORY_MAX_PAGE_SIZE", "HISTORY_MAX_RESPONSE_BYTES", "HISTORY_BADGE_CATALOG_JSON",
      "HISTORY_READS_ENABLED", "HISTORY_MUTATIONS_ENABLED", "HISTORY_LIFECYCLE_ENABLED",
    ], key)
    }, {
    HISTORY_WRITES_ENABLED         = tostring(var.history_features.writes)
    HISTORY_DURABLE_REPLAY_ENABLED = tostring(var.history_features.durable_replay)
    RECOGNITION_ENABLED            = tostring(var.history_features.recognition)
  })
}

# Secret material is generated through Secrets Manager, never stored in Terraform.
resource "aws_secretsmanager_secret" "history_cursor" {
  count                   = var.history_deployment != null ? 1 : 0
  name                    = "${var.project_name}/${var.environment}/history-cursor"
  recovery_window_in_days = 7
  tags                    = merge(local.common_tags, { DataClass = "cursor-subject-binding-key" })
}

resource "aws_cloudwatch_log_group" "history_api" {
  for_each          = local.history_functions
  name              = "/aws/lambda/${local.name_prefix}-${each.value.name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_iam_role" "history_api" {
  for_each           = local.history_functions
  name               = "${local.name_prefix}-${each.value.name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "history_api" {
  for_each = local.history_functions

  statement {
    sid       = "ReadOwnUserControl"
    actions   = ["dynamodb:GetItem"]
    resources = [local.history_data.control_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = each.key == "read" ? ["USER#*", "CURSOR#*"] : ["USER#*"]
    }
  }
  statement {
    sid       = "ReadAuthoritativeDeviceBinding"
    actions   = ["dynamodb:GetItem"]
    resources = [local.device_bindings_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }
  statement {
    sid       = "VerifyActiveDeviceBinding"
    actions   = ["dynamodb:Query"]
    resources = ["${local.device_bindings_table_arn}/index/GSI1"]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*#ACTIVE"]
    }
  }
  dynamic "statement" {
    for_each = { users = local.users_table_arn, ledger = local.deletion_ledger_table_arn }
    content {
      sid       = statement.key == "users" ? "ReadEligibleProfile" : "ReadAuthoritativeDeletionFence"
      actions   = ["dynamodb:GetItem"]
      resources = [statement.value]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = statement.key == "users" ? ["USER#*"] : ["ACCOUNT#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = each.key == "mutation" ? { users = local.users_table_arn, ledger = local.deletion_ledger_table_arn } : {}
    content {
      sid       = statement.key == "users" ? "CheckEligibleProfileAtomically" : "CheckDeletionFenceAtomically"
      actions   = ["dynamodb:ConditionCheckItem"]
      resources = [statement.value]
      condition {
        test     = "StringEquals"
        variable = "dynamodb:EnclosingOperation"
        values   = ["TransactWriteItems"]
      }
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = statement.key == "users" ? ["USER#*"] : ["ACCOUNT#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = each.key == "read" ? [1] : []
    content {
      sid       = "ReadOwnHistory"
      actions   = ["dynamodb:GetItem", "dynamodb:Query"]
      resources = [local.history_data.content_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["USER#*#HISTORY#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = each.key == "read" ? [1] : []
    content {
      sid       = "CreateOnlyOpaqueCursors"
      actions   = ["dynamodb:PutItem"]
      resources = [local.history_data.control_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["CURSOR#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = each.key == "read" ? [1] : []
    content {
      sid       = "ReadCursorBindingSecret"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [aws_secretsmanager_secret.history_cursor[0].arn]
    }
  }
  dynamic "statement" {
    for_each = each.key == "mutation" ? [1] : []
    content {
      sid       = "AtomicHistoryMutations"
      actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
      resources = [local.history_data.content_table_arn, local.history_data.control_table_arn, local.analysis_abuse_control_table_arn]
      condition {
        test     = "StringEquals"
        variable = "dynamodb:EnclosingOperation"
        values   = ["TransactWriteItems"]
      }
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["USER#*", "ANALYSIS#REQUEST#*"]
      }
    }
  }
  statement {
    sid       = "ContentFreeOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.history_api[each.key].arn}:*"]
  }
}

resource "aws_iam_role_policy" "history_api" {
  for_each = local.history_functions
  name     = "history-api-runtime"
  role     = aws_iam_role.history_api[each.key].name
  policy   = data.aws_iam_policy_document.history_api[each.key].json
}

data "aws_iam_policy_document" "history_analysis" {
  count = var.history_deployment != null ? 1 : 0
  dynamic "statement" {
    for_each = { users = local.users_table_arn, ledger = local.deletion_ledger_table_arn }
    content {
      sid       = statement.key == "users" ? "ReadAuthoritativeProfile" : "ReadAuthoritativeDeletionFence"
      actions   = ["dynamodb:GetItem"]
      resources = [statement.value]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = statement.key == "users" ? ["USER#*"] : ["ACCOUNT#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = { users = local.users_table_arn, ledger = local.deletion_ledger_table_arn }
    content {
      sid       = statement.key == "users" ? "CheckAuthoritativeProfileAtomically" : "CheckDeletionFenceAtomically"
      actions   = ["dynamodb:ConditionCheckItem"]
      resources = [statement.value]
      condition {
        test     = "StringEquals"
        variable = "dynamodb:EnclosingOperation"
        values   = ["TransactWriteItems"]
      }
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = statement.key == "users" ? ["USER#*"] : ["ACCOUNT#*"]
      }
    }
  }
  statement {
    sid       = "ReadHistoryReplayAndState"
    actions   = ["dynamodb:GetItem"]
    resources = [local.history_data.content_table_arn, local.history_data.control_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }
  statement {
    sid       = "AtomicHistoryCompletion"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:ConditionCheckItem"]
    resources = [local.history_data.content_table_arn, local.history_data.control_table_arn]
    condition {
      test     = "StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }
}

resource "aws_iam_role_policy" "history_analysis" {
  count  = var.history_deployment != null ? 1 : 0
  name   = "history-analysis-runtime"
  role   = aws_iam_role.analysis.name
  policy = data.aws_iam_policy_document.history_analysis[0].json
}

resource "aws_lambda_function" "history_api" {
  for_each                       = local.history_functions
  function_name                  = "${local.name_prefix}-${each.value.name}"
  role                           = aws_iam_role.history_api[each.key].arn
  runtime                        = "python3.13"
  handler                        = "app.lambda_handler"
  architectures                  = ["arm64"]
  memory_size                    = 256
  timeout                        = 15
  reserved_concurrent_executions = 2
  s3_bucket                      = local.foundation.artifact_bucket_name
  s3_key                         = "releases/${var.history_deployment.release_id}/${each.value.zip}"
  s3_object_version              = var.history_deployment.artifacts[each.key].object_version
  source_code_hash               = var.history_deployment.artifacts[each.key].source_hash
  environment {
    variables = merge(local.history_common_env, each.key == "read" ? {
      HISTORY_READS_ENABLED      = tostring(var.history_features.reads)
      RECOGNITION_ENABLED        = tostring(var.history_features.recognition)
      HISTORY_CURSOR_SECRET_NAME = aws_secretsmanager_secret.history_cursor[0].name
      } : {
      HISTORY_MUTATIONS_ENABLED = tostring(var.history_features.mutations)
      RECOGNITION_ENABLED       = tostring(var.history_features.recognition)
    })
  }
  lifecycle {
    precondition {
      condition = try(
        local.history_data.enabled && local.history_data.schema_version == 1 &&
        local.history_data.environment == var.environment && local.history_data.storage_policy.approved &&
        local.history_data.content_table_name == "${local.name_prefix}-history-content" &&
        local.history_data.control_table_name == "${local.name_prefix}-history-control" &&
        local.history_data.content_table_arn == "arn:${split(":", local.users_table_arn)[1]}:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.name_prefix}-history-content" &&
        local.history_data.control_table_arn == "arn:${split(":", local.users_table_arn)[1]}:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.name_prefix}-history-control" &&
        local.history_data.history_retention_seconds == 90 * 86400 &&
        local.history_data.active_deletion_sla_seconds == 86400 &&
        local.history_data.expiration_index_name == "ExpirationIndex" &&
        local.history_data.lifecycle_index_name == "PendingLifecycleIndex" &&
        local.history_data.storage_policy.dedup_retention_seconds >= 91 * 86400 &&
        local.history_data.storage_policy.dedup_retention_seconds % 86400 == 0,
        false
      )
      error_message = "History API requires enabled same-environment storage with approved retention covering content and cleanup."
    }
    precondition {
      condition = !(var.history_features.writes || var.history_features.mutations) || try(
        local.history_processing.schema_version == 1 && local.history_processing.environment == var.environment &&
        local.history_processing.deployed && local.history_processing.active &&
        local.history_processing.account_deletion_active, false
      )
      error_message = "Writes and mutations require active same-environment cleanup and account-deletion integration."
    }
  }
  depends_on = [aws_iam_role_policy.history_api]
  tags       = local.common_tags
}

resource "aws_apigatewayv2_integration" "history" {
  for_each               = local.history_functions
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.history_api[each.key].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 15000
}

resource "aws_apigatewayv2_route" "history" {
  for_each             = local.history_routes
  api_id               = aws_apigatewayv2_api.age_attestation.id
  route_key            = "${each.value.method} ${each.value.path}"
  target               = "integrations/${aws_apigatewayv2_integration.history[each.value.handler].id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito_jwt.id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

resource "aws_lambda_permission" "history_gateway" {
  for_each      = local.history_routes
  statement_id  = "HistoryRoute-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.history_api[each.value.handler].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/${each.value.method}/${each.value.permission_path}"
}

output "history_contract" {
  value = {
    schema_version    = 1
    environment       = var.environment
    deployed          = var.history_deployment != null
    features          = var.history_features
    route_keys        = [for route in aws_apigatewayv2_route.history : route.route_key]
    cursor_secret_arn = try(aws_secretsmanager_secret.history_cursor[0].arn, null)
    identity_source   = "validated_cognito_access_token_sub"
    badge_catalog     = local.history_catalog
  }
}
