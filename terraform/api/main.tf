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

locals {
  foundation                                  = data.terraform_remote_state.foundation.outputs.downstream_contract
  artifact_prefix                             = "releases/${var.artifact_release}"
  name_prefix                                 = "${var.project_name}-${var.environment}"
  lambda_name                                 = coalesce(var.age_attestation_lambda_name, "${local.name_prefix}-age-attestation")
  artifact_bucket_name                        = coalesce(var.age_attestation_lambda_s3_bucket, local.foundation.artifact_bucket_name)
  analysis_lambda_name                        = coalesce(var.analysis_lambda_name, "${local.name_prefix}-conversation-analysis")
  analysis_artifact_bucket_name               = coalesce(var.analysis_lambda_s3_bucket, local.foundation.artifact_bucket_name)
  device_registration_lambda_name             = coalesce(var.device_registration_lambda_name, "${local.name_prefix}-device-registration")
  device_registration_artifact_bucket_name    = coalesce(var.device_registration_lambda_s3_bucket, local.foundation.artifact_bucket_name)
  device_recovery_lambda_name                 = coalesce(var.device_recovery_lambda_name, "${local.name_prefix}-device-recovery")
  device_recovery_artifact_bucket_name        = coalesce(var.device_recovery_lambda_s3_bucket, local.foundation.artifact_bucket_name)
  purchase_handoff_lambda_name                = coalesce(var.purchase_handoff_lambda_name, "${local.name_prefix}-purchase-handoff")
  purchase_handoff_artifact_bucket_name       = coalesce(var.purchase_handoff_lambda_s3_bucket, local.foundation.artifact_bucket_name)
  entitlement_snapshot_lambda_name            = coalesce(var.entitlement_snapshot_lambda_name, "${local.name_prefix}-entitlement-snapshot")
  entitlement_snapshot_artifact_bucket_name   = coalesce(var.entitlement_snapshot_lambda_s3_bucket, local.foundation.artifact_bucket_name)
  web_risk_communication_lambda_name          = coalesce(var.web_risk_communication_lambda_name, "${local.name_prefix}-web-risk-communication")
  web_risk_communication_artifact_bucket_name = coalesce(var.web_risk_communication_lambda_s3_bucket, local.foundation.artifact_bucket_name)
  openai_secret_name                          = coalesce(var.openai_secret_name, "${var.project_name}/${var.environment}/openai")
  effective_openai_secret_arn                 = var.openai_secret_arn != null ? var.openai_secret_arn : aws_secretsmanager_secret.openai[0].arn
  google_play_secret_name                     = coalesce(var.google_play_secret_name, "${var.project_name}/${var.environment}/google-play-service-account")
  effective_google_play_secret_arn            = var.google_play_secret_arn != null ? var.google_play_secret_arn : aws_secretsmanager_secret.google_play[0].arn
  web_risk_secret_name                        = coalesce(var.web_risk_secret_name, "${var.project_name}/${var.environment}/web-risk-api-key")
  effective_web_risk_secret_arn               = var.enable_web_risk_communication ? (var.web_risk_secret_arn != null ? var.web_risk_secret_arn : aws_secretsmanager_secret.web_risk[0].arn) : null
  cognito_user_pool_id                        = local.foundation.cognito_user_pool_id
  cognito_app_client_id                       = local.foundation.cognito_app_client_id
  users_table_arn                             = local.foundation.users_table_arn
  users_table_name                            = local.foundation.users_table_name
  analysis_abuse_control_table_arn            = local.foundation.analysis_abuse_control_table_arn
  analysis_abuse_control_table_name           = local.foundation.analysis_abuse_control_table_name
  analysis_entitlements_table_arn             = local.foundation.purchase_entitlements_table_arn
  analysis_entitlements_table_name            = local.foundation.purchase_entitlements_table_name
  device_bindings_table_arn                   = local.foundation.device_bindings_table_arn
  device_bindings_table_name                  = local.foundation.device_bindings_table_name
  purchase_entitlements_table_arn             = local.foundation.purchase_entitlements_table_arn
  purchase_entitlements_table_name            = local.foundation.purchase_entitlements_table_name
  web_risk_cache_table_arn                    = local.foundation.web_risk_cache_table_arn
  web_risk_cache_table_name                   = local.foundation.web_risk_cache_table_name
  jwt_issuer                                  = "https://cognito-idp.${var.aws_region}.amazonaws.com/${local.cognito_user_pool_id}"
  age_attestation_artifact_key                = coalesce(var.age_attestation_lambda_s3_key, "${local.artifact_prefix}/age_attestation.zip")
  analysis_artifact_key                       = coalesce(var.analysis_lambda_s3_key, "${local.artifact_prefix}/conversation_analysis.zip")
  device_registration_artifact_key            = coalesce(var.device_registration_lambda_s3_key, "${local.artifact_prefix}/device_registration.zip")
  device_recovery_artifact_key                = coalesce(var.device_recovery_lambda_s3_key, "${local.artifact_prefix}/device_recovery.zip")
  purchase_handoff_artifact_key               = coalesce(var.purchase_handoff_lambda_s3_key, "${local.artifact_prefix}/purchase_handoff.zip")
  entitlement_snapshot_artifact_key           = coalesce(var.entitlement_snapshot_lambda_s3_key, "${local.artifact_prefix}/entitlement_snapshot.zip")
  web_risk_communication_artifact_key         = coalesce(var.web_risk_communication_lambda_s3_key, "${local.artifact_prefix}/web_risk_communication.zip")

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "api"
  })
}

check "foundation_contract_version" {
  assert {
    condition     = local.foundation.schema_version == 1
    error_message = "The foundation state contract is incompatible with this API stack."
  }
}

check "api_has_reachable_endpoint" {
  assert {
    condition     = var.custom_domain_enabled || !var.disable_execute_api_endpoint
    error_message = "The default execute-api endpoint cannot be disabled unless a custom domain is enabled."
  }
}

resource "aws_secretsmanager_secret" "openai" {
  count = var.openai_secret_arn == null ? 1 : 0

  name                    = local.openai_secret_name
  recovery_window_in_days = var.openai_secret_recovery_window_in_days

  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "google_play" {
  count = var.google_play_secret_arn == null ? 1 : 0

  name                    = local.google_play_secret_name
  recovery_window_in_days = var.google_play_secret_recovery_window_in_days

  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "web_risk" {
  count = var.enable_web_risk_communication && var.web_risk_secret_arn == null ? 1 : 0

  name                    = local.web_risk_secret_name
  recovery_window_in_days = var.web_risk_secret_recovery_window_in_days

  tags = local.common_tags
}

data "aws_route53_zone" "api" {
  count        = var.custom_domain_enabled ? 1 : 0
  name         = var.route53_zone_name
  private_zone = false
}

data "aws_iam_policy_document" "age_attestation_assume_role" {
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

resource "aws_iam_role" "age_attestation" {
  name               = "${local.lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "age_attestation_basic_execution" {
  role       = aws_iam_role.age_attestation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "age_attestation_dynamodb" {
  statement {
    sid    = "UsersTableReadUpdate"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]

    resources = [local.users_table_arn]
  }
}

resource "aws_iam_policy" "age_attestation_dynamodb" {
  name   = "${local.lambda_name}-dynamodb"
  policy = data.aws_iam_policy_document.age_attestation_dynamodb.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "age_attestation_dynamodb" {
  role       = aws_iam_role.age_attestation.name
  policy_arn = aws_iam_policy.age_attestation_dynamodb.arn
}

resource "aws_iam_role" "analysis" {
  name               = "${local.analysis_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "device_registration" {
  name               = "${local.device_registration_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "device_recovery" {
  count              = var.enable_device_recovery ? 1 : 0
  name               = "${local.device_recovery_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "purchase_handoff" {
  name               = "${local.purchase_handoff_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "entitlement_snapshot" {
  name               = "${local.entitlement_snapshot_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "web_risk_communication" {
  count              = var.enable_web_risk_communication ? 1 : 0
  name               = "${local.web_risk_communication_lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "analysis_basic_execution" {
  role       = aws_iam_role.analysis.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "device_registration_basic_execution" {
  role       = aws_iam_role.device_registration.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "device_recovery_basic_execution" {
  count      = var.enable_device_recovery ? 1 : 0
  role       = aws_iam_role.device_recovery[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "purchase_handoff_basic_execution" {
  role       = aws_iam_role.purchase_handoff.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "entitlement_snapshot_basic_execution" {
  role       = aws_iam_role.entitlement_snapshot.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "web_risk_communication_basic_execution" {
  count      = var.enable_web_risk_communication ? 1 : 0
  role       = aws_iam_role.web_risk_communication[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "analysis_runtime" {
  statement {
    sid    = "UsersTableReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]

    resources = [local.users_table_arn]
  }

  statement {
    sid    = "AbuseControlTableReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]

    resources = [local.analysis_abuse_control_table_arn]
  }

  statement {
    sid    = "EntitlementsTableReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]

    resources = [
      local.analysis_entitlements_table_arn,
      "${local.analysis_entitlements_table_arn}/index/*"
    ]
  }

  statement {
    sid    = "DeviceBindingsReadOnly"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query"
    ]

    resources = [
      local.device_bindings_table_arn,
      "${local.device_bindings_table_arn}/index/*"
    ]
  }

  statement {
    sid    = "ReadOpenAISecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [local.effective_openai_secret_arn]
  }
}

resource "aws_iam_policy" "analysis_runtime" {
  name   = "${local.analysis_lambda_name}-runtime"
  policy = data.aws_iam_policy_document.analysis_runtime.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "analysis_runtime" {
  role       = aws_iam_role.analysis.name
  policy_arn = aws_iam_policy.analysis_runtime.arn
}

data "aws_iam_policy_document" "device_registration_runtime" {
  statement {
    sid    = "DeviceBindingsReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]

    resources = [
      local.device_bindings_table_arn,
      "${local.device_bindings_table_arn}/index/*"
    ]
  }
}

resource "aws_iam_policy" "device_registration_runtime" {
  name   = "${local.device_registration_lambda_name}-runtime"
  policy = data.aws_iam_policy_document.device_registration_runtime.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "device_registration_runtime" {
  role       = aws_iam_role.device_registration.name
  policy_arn = aws_iam_policy.device_registration_runtime.arn
}

data "aws_iam_policy_document" "device_recovery_runtime" {
  count = var.enable_device_recovery ? 1 : 0
  statement {
    sid    = "DeviceBindingsReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]

    resources = [
      local.device_bindings_table_arn,
      "${local.device_bindings_table_arn}/index/*"
    ]
  }
}

resource "aws_iam_policy" "device_recovery_runtime" {
  count  = var.enable_device_recovery ? 1 : 0
  name   = "${local.device_recovery_lambda_name}-runtime"
  policy = data.aws_iam_policy_document.device_recovery_runtime[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "device_recovery_runtime" {
  count      = var.enable_device_recovery ? 1 : 0
  role       = aws_iam_role.device_recovery[0].name
  policy_arn = aws_iam_policy.device_recovery_runtime[0].arn
}

data "aws_iam_policy_document" "purchase_handoff_runtime" {
  statement {
    sid    = "PurchaseEntitlementsReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ]

    resources = [
      local.purchase_entitlements_table_arn,
      "${local.purchase_entitlements_table_arn}/index/*"
    ]
  }

  statement {
    sid    = "ReadGooglePlaySecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [local.effective_google_play_secret_arn]
  }
}

resource "aws_iam_policy" "purchase_handoff_runtime" {
  name   = "${local.purchase_handoff_lambda_name}-runtime"
  policy = data.aws_iam_policy_document.purchase_handoff_runtime.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "purchase_handoff_runtime" {
  role       = aws_iam_role.purchase_handoff.name
  policy_arn = aws_iam_policy.purchase_handoff_runtime.arn
}

data "aws_iam_policy_document" "entitlement_snapshot_runtime" {
  statement {
    sid    = "EntitlementsTableReadOnly"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query"
    ]

    resources = [
      local.purchase_entitlements_table_arn,
      "${local.purchase_entitlements_table_arn}/index/*"
    ]
  }
}

resource "aws_iam_policy" "entitlement_snapshot_runtime" {
  name   = "${local.entitlement_snapshot_lambda_name}-runtime"
  policy = data.aws_iam_policy_document.entitlement_snapshot_runtime.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "entitlement_snapshot_runtime" {
  role       = aws_iam_role.entitlement_snapshot.name
  policy_arn = aws_iam_policy.entitlement_snapshot_runtime.arn
}

data "aws_iam_policy_document" "web_risk_communication_runtime" {
  count = var.enable_web_risk_communication ? 1 : 0
  statement {
    sid    = "WebRiskCacheReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]

    resources = [local.web_risk_cache_table_arn]
  }

  statement {
    sid    = "ReadWebRiskSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [local.effective_web_risk_secret_arn]
  }
}

resource "aws_iam_policy" "web_risk_communication_runtime" {
  count  = var.enable_web_risk_communication ? 1 : 0
  name   = "${local.web_risk_communication_lambda_name}-runtime"
  policy = data.aws_iam_policy_document.web_risk_communication_runtime[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "web_risk_communication_runtime" {
  count      = var.enable_web_risk_communication ? 1 : 0
  role       = aws_iam_role.web_risk_communication[0].name
  policy_arn = aws_iam_policy.web_risk_communication_runtime[0].arn
}

resource "aws_cloudwatch_log_group" "age_attestation_lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = var.age_attestation_log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "analysis_lambda" {
  name              = "/aws/lambda/${local.analysis_lambda_name}"
  retention_in_days = var.age_attestation_log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "device_registration_lambda" {
  name              = "/aws/lambda/${local.device_registration_lambda_name}"
  retention_in_days = var.age_attestation_log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "device_recovery_lambda" {
  count             = var.enable_device_recovery ? 1 : 0
  name              = "/aws/lambda/${local.device_recovery_lambda_name}"
  retention_in_days = var.age_attestation_log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "purchase_handoff_lambda" {
  name              = "/aws/lambda/${local.purchase_handoff_lambda_name}"
  retention_in_days = var.age_attestation_log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "entitlement_snapshot_lambda" {
  name              = "/aws/lambda/${local.entitlement_snapshot_lambda_name}"
  retention_in_days = var.age_attestation_log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "web_risk_communication_lambda" {
  count             = var.enable_web_risk_communication ? 1 : 0
  name              = "/aws/lambda/${local.web_risk_communication_lambda_name}"
  retention_in_days = var.age_attestation_log_retention_days

  tags = local.common_tags
}

resource "aws_lambda_function" "age_attestation" {
  function_name = local.lambda_name
  role          = aws_iam_role.age_attestation.arn
  runtime       = var.age_attestation_lambda_runtime
  handler       = var.age_attestation_lambda_handler

  timeout                        = var.age_attestation_lambda_timeout_seconds
  memory_size                    = var.age_attestation_lambda_memory_mb
  architectures                  = var.age_attestation_lambda_architectures
  reserved_concurrent_executions = var.age_attestation_lambda_reserved_concurrency

  s3_bucket         = local.artifact_bucket_name
  s3_key            = local.age_attestation_artifact_key
  s3_object_version = var.age_attestation_lambda_s3_object_version

  environment {
    variables = merge(var.age_attestation_lambda_env, {
      USERS_TABLE_ARN  = local.users_table_arn
      USERS_TABLE_NAME = local.users_table_name
    })
  }

  depends_on = [aws_cloudwatch_log_group.age_attestation_lambda]

  tags = local.common_tags
}

resource "aws_lambda_function" "analysis" {
  function_name = local.analysis_lambda_name
  role          = aws_iam_role.analysis.arn
  runtime       = var.analysis_lambda_runtime
  handler       = var.analysis_lambda_handler

  timeout                        = var.analysis_lambda_timeout_seconds
  memory_size                    = var.analysis_lambda_memory_mb
  architectures                  = var.analysis_lambda_architectures
  reserved_concurrent_executions = var.analysis_lambda_reserved_concurrency

  s3_bucket         = local.analysis_artifact_bucket_name
  s3_key            = local.analysis_artifact_key
  s3_object_version = var.analysis_lambda_s3_object_version

  environment {
    variables = merge(var.analysis_lambda_env, {
      USERS_TABLE_ARN                       = local.users_table_arn
      USERS_TABLE_NAME                      = local.users_table_name
      ABUSE_CONTROL_TABLE_ARN               = local.analysis_abuse_control_table_arn
      ABUSE_CONTROL_TABLE_NAME              = local.analysis_abuse_control_table_name
      ANALYSIS_ABUSE_TABLE_NAME             = local.analysis_abuse_control_table_name
      DEVICE_BINDINGS_TABLE_NAME            = local.device_bindings_table_name
      ENTITLEMENTS_TABLE_ARN                = local.analysis_entitlements_table_arn
      ENTITLEMENTS_TABLE_NAME               = local.analysis_entitlements_table_name
      SCAN_RATE_LIMIT_WINDOW_SECONDS        = tostring(var.analysis_scan_rate_limit_window_seconds)
      SCAN_RATE_LIMIT_MAX_REQUESTS          = tostring(var.analysis_scan_rate_limit_max_requests)
      FREE_MONTHLY_SCAN_LIMIT               = tostring(var.analysis_free_monthly_scan_limit)
      PRO_MONTHLY_SCAN_LIMIT                = tostring(var.analysis_pro_monthly_scan_limit)
      PURCHASE_USAGE_COUNTER_RETENTION_DAYS = tostring(var.purchase_usage_counter_retention_days)
      ENTITLEMENT_DEFAULT_TIER              = var.entitlement_default_tier
      ENTITLEMENT_PREMIUM_TIER              = var.entitlement_premium_tier
      ENTITLEMENT_USAGE_PERIOD_MODE         = var.entitlement_usage_period_mode
      ENTITLEMENT_ACCESS_GRANTING_STATUSES  = jsonencode(var.entitlement_access_granting_statuses)
      ENTITLEMENT_NONTERMINAL_STATUSES      = jsonencode(var.entitlement_nonterminal_statuses)
      ENTITLEMENT_PLATFORM                  = "google_play"
      ENTITLEMENT_PRODUCT_ID                = var.google_play_subscription_product_id
      OPENAI_SECRET_ARN                     = local.effective_openai_secret_arn
      OPENAI_SECRET_NAME                    = local.openai_secret_name
      ANALYSIS_REQUEST_TIMEOUT_MS           = tostring(29000)
    })
  }

  depends_on = [aws_cloudwatch_log_group.analysis_lambda]

  tags = local.common_tags
}

resource "aws_lambda_function" "device_registration" {
  function_name = local.device_registration_lambda_name
  role          = aws_iam_role.device_registration.arn
  runtime       = var.device_registration_lambda_runtime
  handler       = var.device_registration_lambda_handler

  timeout                        = var.device_registration_lambda_timeout_seconds
  memory_size                    = var.device_registration_lambda_memory_mb
  architectures                  = var.device_registration_lambda_architectures
  reserved_concurrent_executions = var.device_registration_lambda_reserved_concurrency

  s3_bucket         = local.device_registration_artifact_bucket_name
  s3_key            = local.device_registration_artifact_key
  s3_object_version = var.device_registration_lambda_s3_object_version

  environment {
    variables = merge(var.device_registration_lambda_env, {
      DEVICE_BINDINGS_TABLE_ARN               = local.device_bindings_table_arn
      DEVICE_BINDINGS_TABLE_NAME              = local.device_bindings_table_name
      DEVICE_BINDINGS_INACTIVE_RETENTION_DAYS = tostring(var.device_bindings_inactive_retention_days)
    })
  }

  depends_on = [aws_cloudwatch_log_group.device_registration_lambda]

  tags = local.common_tags
}

resource "aws_lambda_function" "device_recovery" {
  count         = var.enable_device_recovery ? 1 : 0
  function_name = local.device_recovery_lambda_name
  role          = aws_iam_role.device_recovery[0].arn
  runtime       = var.device_recovery_lambda_runtime
  handler       = var.device_recovery_lambda_handler

  timeout                        = var.device_recovery_lambda_timeout_seconds
  memory_size                    = var.device_recovery_lambda_memory_mb
  architectures                  = var.device_recovery_lambda_architectures
  reserved_concurrent_executions = var.device_recovery_lambda_reserved_concurrency

  s3_bucket         = local.device_recovery_artifact_bucket_name
  s3_key            = local.device_recovery_artifact_key
  s3_object_version = var.device_recovery_lambda_s3_object_version

  environment {
    variables = merge(var.device_recovery_lambda_env, {
      DEVICE_BINDINGS_TABLE_NAME              = local.device_bindings_table_name
      DEVICE_BINDINGS_INACTIVE_RETENTION_DAYS = tostring(var.device_bindings_inactive_retention_days)
    })
  }

  depends_on = [aws_cloudwatch_log_group.device_recovery_lambda]

  tags = local.common_tags
}

resource "aws_lambda_function" "entitlement_snapshot" {
  function_name = local.entitlement_snapshot_lambda_name
  role          = aws_iam_role.entitlement_snapshot.arn
  runtime       = var.entitlement_snapshot_lambda_runtime
  handler       = var.entitlement_snapshot_lambda_handler

  timeout                        = var.entitlement_snapshot_lambda_timeout_seconds
  memory_size                    = var.entitlement_snapshot_lambda_memory_mb
  architectures                  = var.entitlement_snapshot_lambda_architectures
  reserved_concurrent_executions = var.entitlement_snapshot_lambda_reserved_concurrency

  s3_bucket         = local.entitlement_snapshot_artifact_bucket_name
  s3_key            = local.entitlement_snapshot_artifact_key
  s3_object_version = var.entitlement_snapshot_lambda_s3_object_version

  environment {
    variables = merge(var.entitlement_snapshot_lambda_env, {
      ENTITLEMENTS_TABLE_ARN                = local.purchase_entitlements_table_arn
      ENTITLEMENTS_TABLE_NAME               = local.purchase_entitlements_table_name
      PURCHASE_USAGE_COUNTER_RETENTION_DAYS = tostring(var.purchase_usage_counter_retention_days)
      ENTITLEMENT_DEFAULT_TIER              = var.entitlement_default_tier
      ENTITLEMENT_PREMIUM_TIER              = var.entitlement_premium_tier
      ENTITLEMENT_USAGE_PERIOD_MODE         = var.entitlement_usage_period_mode
      ENTITLEMENT_ACCESS_GRANTING_STATUSES  = jsonencode(var.entitlement_access_granting_statuses)
      ENTITLEMENT_NONTERMINAL_STATUSES      = jsonencode(var.entitlement_nonterminal_statuses)
      ENTITLEMENT_PLATFORM                  = "google_play"
      ENTITLEMENT_PRODUCT_ID                = var.google_play_subscription_product_id
      FREE_MONTHLY_SCAN_LIMIT               = tostring(var.analysis_free_monthly_scan_limit)
      PRO_MONTHLY_SCAN_LIMIT                = tostring(var.analysis_pro_monthly_scan_limit)
    })
  }

  depends_on = [aws_cloudwatch_log_group.entitlement_snapshot_lambda]

  tags = local.common_tags
}

resource "aws_lambda_function" "purchase_handoff" {
  function_name = local.purchase_handoff_lambda_name
  role          = aws_iam_role.purchase_handoff.arn
  runtime       = var.purchase_handoff_lambda_runtime
  handler       = var.purchase_handoff_lambda_handler

  timeout                        = var.purchase_handoff_lambda_timeout_seconds
  memory_size                    = var.purchase_handoff_lambda_memory_mb
  architectures                  = var.purchase_handoff_lambda_architectures
  reserved_concurrent_executions = var.purchase_handoff_lambda_reserved_concurrency

  s3_bucket         = local.purchase_handoff_artifact_bucket_name
  s3_key            = local.purchase_handoff_artifact_key
  s3_object_version = var.purchase_handoff_lambda_s3_object_version

  environment {
    variables = merge(var.purchase_handoff_lambda_env, {
      PURCHASE_ENTITLEMENTS_TABLE_ARN       = local.purchase_entitlements_table_arn
      PURCHASE_ENTITLEMENTS_TABLE_NAME      = local.purchase_entitlements_table_name
      ENTITLEMENTS_TABLE_ARN                = local.purchase_entitlements_table_arn
      ENTITLEMENTS_TABLE_NAME               = local.purchase_entitlements_table_name
      PURCHASE_VERIFICATION_MODE            = var.purchase_verification_mode
      PURCHASE_USAGE_COUNTER_RETENTION_DAYS = tostring(var.purchase_usage_counter_retention_days)
      ENTITLEMENT_DEFAULT_TIER              = var.entitlement_default_tier
      ENTITLEMENT_PREMIUM_TIER              = var.entitlement_premium_tier
      ENTITLEMENT_USAGE_PERIOD_MODE         = var.entitlement_usage_period_mode
      ENTITLEMENT_ACCESS_GRANTING_STATUSES  = jsonencode(var.entitlement_access_granting_statuses)
      ENTITLEMENT_NONTERMINAL_STATUSES      = jsonencode(var.entitlement_nonterminal_statuses)
      ENTITLEMENT_PLATFORM                  = "google_play"
      ENTITLEMENT_PRODUCT_ID                = var.google_play_subscription_product_id
      GOOGLE_PLAY_SECRET_ARN                = local.effective_google_play_secret_arn
      GOOGLE_PLAY_SECRET_NAME               = local.google_play_secret_name
      GOOGLE_PLAY_PACKAGE_NAME              = var.google_play_package_name
      GOOGLE_PLAY_SUBSCRIPTION_PRODUCT_ID   = var.google_play_subscription_product_id
      GOOGLE_PLAY_PRO_PRODUCT_ID            = var.google_play_subscription_product_id
    })
  }

  depends_on = [
    aws_cloudwatch_log_group.purchase_handoff_lambda,
  ]

  tags = local.common_tags
}

resource "aws_lambda_function" "web_risk_communication" {
  count         = var.enable_web_risk_communication ? 1 : 0
  function_name = local.web_risk_communication_lambda_name
  role          = aws_iam_role.web_risk_communication[0].arn
  runtime       = var.web_risk_communication_lambda_runtime
  handler       = var.web_risk_communication_lambda_handler

  timeout                        = var.web_risk_communication_lambda_timeout_seconds
  memory_size                    = var.web_risk_communication_lambda_memory_mb
  architectures                  = var.web_risk_communication_lambda_architectures
  reserved_concurrent_executions = var.web_risk_communication_lambda_reserved_concurrency

  s3_bucket         = local.web_risk_communication_artifact_bucket_name
  s3_key            = local.web_risk_communication_artifact_key
  s3_object_version = var.web_risk_communication_lambda_s3_object_version

  environment {
    variables = merge(var.web_risk_communication_lambda_env, {
      WEB_RISK_TABLE_NAME  = local.web_risk_cache_table_name
      WEB_RISK_SECRET_NAME = local.web_risk_secret_name
    })
  }

  depends_on = [aws_cloudwatch_log_group.web_risk_communication_lambda]

  tags = local.common_tags
}

resource "aws_apigatewayv2_api" "age_attestation" {
  name                         = "${local.name_prefix}-age-attestation-api"
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = var.disable_execute_api_endpoint

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_headers = var.cors_allow_headers
    allow_methods = var.cors_allow_methods
    max_age       = 300
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "age_attestation_api" {
  name              = "/aws/apigateway/${local.name_prefix}-age-attestation-api"
  retention_in_days = var.age_attestation_log_retention_days

  tags = local.common_tags
}

resource "aws_apigatewayv2_authorizer" "cognito_jwt" {
  api_id           = aws_apigatewayv2_api.age_attestation.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${local.name_prefix}-cognito-jwt"

  jwt_configuration {
    audience = [local.cognito_app_client_id]
    issuer   = local.jwt_issuer
  }
}

resource "aws_apigatewayv2_integration" "age_attestation_lambda" {
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.age_attestation.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

resource "aws_apigatewayv2_route" "age_attestation" {
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = "POST /v1/users/age-attestation"
  target             = "integrations/${aws_apigatewayv2_integration.age_attestation_lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_integration" "analysis_lambda" {
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.analysis.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "analysis" {
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = "POST ${var.analysis_primary_path}"
  target             = "integrations/${aws_apigatewayv2_integration.analysis_lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "analysis_legacy" {
  count              = var.analysis_legacy_path_enabled ? 1 : 0
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = "POST /v1/conversation-analysis"
  target             = "integrations/${aws_apigatewayv2_integration.analysis_lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_integration" "device_registration_lambda" {
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.device_registration.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 15000
}

resource "aws_apigatewayv2_route" "device_registration" {
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = "POST ${var.device_registration_path}"
  target             = "integrations/${aws_apigatewayv2_integration.device_registration_lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_integration" "device_recovery_lambda" {
  count                  = var.enable_device_recovery ? 1 : 0
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.device_recovery[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 15000
}

resource "aws_apigatewayv2_route" "device_recovery" {
  count              = var.enable_device_recovery ? 1 : 0
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = "POST ${var.device_recovery_path}"
  target             = "integrations/${aws_apigatewayv2_integration.device_recovery_lambda[0].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_integration" "purchase_handoff_lambda" {
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.purchase_handoff.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 15000
}

resource "aws_apigatewayv2_route" "purchase_handoff" {
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = "POST ${var.purchase_handoff_path}"
  target             = "integrations/${aws_apigatewayv2_integration.purchase_handoff_lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_integration" "web_risk_communication_lambda" {
  count                  = var.enable_web_risk_communication ? 1 : 0
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.web_risk_communication[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 15000
}

resource "aws_apigatewayv2_route" "web_risk_communication" {
  count              = var.enable_web_risk_communication ? 1 : 0
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = "POST ${var.web_risk_communication_path}"
  target             = "integrations/${aws_apigatewayv2_integration.web_risk_communication_lambda[0].id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_integration" "entitlement_snapshot_lambda" {
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.entitlement_snapshot.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 10000
}

resource "aws_apigatewayv2_route" "entitlement_snapshot" {
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = "GET ${var.entitlement_snapshot_path}"
  target             = "integrations/${aws_apigatewayv2_integration.entitlement_snapshot_lambda.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_stage" "age_attestation" {
  api_id      = aws_apigatewayv2_api.age_attestation.id
  name        = var.api_stage_name
  auto_deploy = true

  default_route_settings {
    detailed_metrics_enabled = true
    throttling_burst_limit   = var.api_throttle_burst_limit
    throttling_rate_limit    = var.api_throttle_rate_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.age_attestation_api.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      sourceIp         = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      authorizerError  = "$context.authorizer.error"
      jwtSubject       = "$context.authorizer.jwt.claims.sub"
    })
  }

  tags = local.common_tags
}

resource "aws_acm_certificate" "api_domain" {
  count             = var.custom_domain_enabled ? 1 : 0
  domain_name       = var.api_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_route53_record" "api_domain_validation" {
  for_each = var.custom_domain_enabled ? {
    for dvo in aws_acm_certificate.api_domain[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.api[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "api_domain" {
  count                   = var.custom_domain_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.api_domain[0].arn
  validation_record_fqdns = [for record in aws_route53_record.api_domain_validation : record.fqdn]
}

resource "aws_apigatewayv2_domain_name" "age_attestation" {
  count       = var.custom_domain_enabled ? 1 : 0
  domain_name = var.api_domain_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api_domain[0].certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  depends_on = [aws_acm_certificate_validation.api_domain]
}

resource "aws_apigatewayv2_api_mapping" "age_attestation" {
  count           = var.custom_domain_enabled ? 1 : 0
  api_id          = aws_apigatewayv2_api.age_attestation.id
  domain_name     = aws_apigatewayv2_domain_name.age_attestation[0].id
  stage           = aws_apigatewayv2_stage.age_attestation.id
  api_mapping_key = var.api_mapping_key
}

resource "aws_route53_record" "api_custom_domain_alias" {
  count   = var.custom_domain_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.api[0].zone_id
  name    = var.api_domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.age_attestation[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.age_attestation[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_age_attestation" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.age_attestation.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_analysis" {
  statement_id  = "AllowExecutionFromApiGatewayAnalysis"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analysis.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_device_registration" {
  statement_id  = "AllowExecutionFromApiGatewayDeviceRegistration"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.device_registration.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_device_recovery" {
  count         = var.enable_device_recovery ? 1 : 0
  statement_id  = "AllowExecutionFromApiGatewayDeviceRecovery"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.device_recovery[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_purchase_handoff" {
  statement_id  = "AllowExecutionFromApiGatewayPurchaseHandoff"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.purchase_handoff.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_entitlement_snapshot" {
  statement_id  = "AllowExecutionFromApiGatewayEntitlementSnapshot"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.entitlement_snapshot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_invoke_web_risk_communication" {
  count         = var.enable_web_risk_communication ? 1 : 0
  statement_id  = "AllowExecutionFromApiGatewayWebRiskCommunication"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.web_risk_communication[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/*"
}
