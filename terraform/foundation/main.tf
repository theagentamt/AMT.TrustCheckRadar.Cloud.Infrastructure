data "aws_caller_identity" "current" {}

locals {
  name_prefix                       = "${var.project_name}-${var.environment}"
  artifact_bucket_name              = coalesce(var.artifact_bucket_name, "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}-artifacts")
  analysis_abuse_control_table_name = coalesce(var.analysis_abuse_control_table_name, "${var.project_name}-${var.environment}-analysis-abuse-control")
  device_bindings_table_name        = coalesce(var.device_bindings_table_name, "${var.project_name}-${var.environment}-device-bindings")
  purchase_entitlements_table_name  = coalesce(var.purchase_entitlements_table_name, "${var.project_name}-${var.environment}-purchase-entitlements")
  web_risk_cache_table_name         = coalesce(var.web_risk_cache_table_name, "${var.project_name}-${var.environment}-web-risk-cache")

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "foundation"
  })

  backend_assume_role_services = [for p in var.backend_assume_role_principals : p if can(regex("amazonaws\\.com$", p))]
  backend_assume_role_aws      = [for p in var.backend_assume_role_principals : p if !can(regex("amazonaws\\.com$", p))]

  deletion_assume_role_services = [for p in var.deletion_assume_role_principals : p if can(regex("amazonaws\\.com$", p))]
  deletion_assume_role_aws      = [for p in var.deletion_assume_role_principals : p if !can(regex("amazonaws\\.com$", p))]
}

resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-user-pool"

  lifecycle {
    # PostConfirmation is managed by the workflows stack via update-user-pool.
    ignore_changes = [lambda_config]
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  password_policy {
    minimum_length                   = var.cognito_password_min_length
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = var.cognito_temporary_password_validity_days
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
  }

  mfa_configuration = "OFF"

  schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    required                 = true
    mutable                  = true

    string_attribute_constraints {
      min_length = 5
      max_length = 2048
    }
  }

  schema {
    name                     = "given_name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    required                 = true
    mutable                  = true

    string_attribute_constraints {
      min_length = 1
      max_length = 2048
    }
  }

  schema {
    name                     = "family_name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    required                 = true
    mutable                  = true

    string_attribute_constraints {
      min_length = 1
      max_length = 2048
    }
  }

  schema {
    name                     = "over_18"
    attribute_data_type      = "Boolean"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
  }

  tags = local.common_tags
}

resource "aws_cognito_user_pool_client" "mobile" {
  name         = "${local.name_prefix}-mobile-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  allowed_oauth_flows_user_pool_client = var.hosted_ui_enabled
  allowed_oauth_flows                  = var.hosted_ui_enabled ? ["code"] : []
  allowed_oauth_scopes                 = var.hosted_ui_enabled ? ["openid", "email", "profile"] : []

  callback_urls = var.hosted_ui_enabled ? var.app_client_callback_urls : []
  logout_urls   = var.hosted_ui_enabled ? var.app_client_logout_urls : []

  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]

  access_token_validity  = var.cognito_access_token_validity_minutes
  id_token_validity      = var.cognito_id_token_validity_minutes
  refresh_token_validity = var.cognito_refresh_token_validity_days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

}

resource "aws_cognito_user_pool_domain" "hosted_ui" {
  count = var.hosted_ui_enabled ? 1 : 0

  domain       = var.hosted_ui_domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.artifact_bucket_name
  force_destroy = var.artifact_bucket_force_destroy

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "users" {
  name         = "${local.name_prefix}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

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

  dynamic "global_secondary_index" {
    for_each = var.users_status_gsi_enabled ? [1] : []

    content {
      name            = "GSI1"
      hash_key        = "GSI1PK"
      range_key       = "GSI1SK"
      projection_type = "ALL"
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "deletion_ledger" {
  name         = "${local.name_prefix}-deletion-ledger"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "analysis_abuse_control" {
  name         = local.analysis_abuse_control_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "device_bindings" {
  name         = local.device_bindings_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

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
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "purchase_entitlements" {
  name         = local.purchase_entitlements_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

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
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "web_risk_cache" {
  name         = local.web_risk_cache_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_iam_role" "backend_service" {
  name               = "${local.name_prefix}-backend-service-role"
  assume_role_policy = data.aws_iam_policy_document.backend_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role" "deletion_workflow" {
  name               = "${local.name_prefix}-deletion-workflow-role"
  assume_role_policy = data.aws_iam_policy_document.deletion_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "backend_assume_role" {
  statement {
    sid     = "AllowAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    dynamic "principals" {
      for_each = length(local.backend_assume_role_services) > 0 ? [1] : []

      content {
        type        = "Service"
        identifiers = local.backend_assume_role_services
      }
    }

    dynamic "principals" {
      for_each = length(local.backend_assume_role_aws) > 0 ? [1] : []

      content {
        type        = "AWS"
        identifiers = local.backend_assume_role_aws
      }
    }
  }
}

data "aws_iam_policy_document" "deletion_assume_role" {
  statement {
    sid     = "AllowAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    dynamic "principals" {
      for_each = length(local.deletion_assume_role_services) > 0 ? [1] : []

      content {
        type        = "Service"
        identifiers = local.deletion_assume_role_services
      }
    }

    dynamic "principals" {
      for_each = length(local.deletion_assume_role_aws) > 0 ? [1] : []

      content {
        type        = "AWS"
        identifiers = local.deletion_assume_role_aws
      }
    }
  }
}

data "aws_iam_policy_document" "backend_permissions" {
  statement {
    sid    = "UsersTableReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query"
    ]

    resources = [
      aws_dynamodb_table.users.arn,
      "${aws_dynamodb_table.users.arn}/index/*"
    ]
  }

  statement {
    sid    = "DeletionLedgerWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem"
    ]

    resources = [aws_dynamodb_table.deletion_ledger.arn]
  }
}

resource "aws_iam_policy" "backend_permissions" {
  name   = "${local.name_prefix}-backend-permissions"
  policy = data.aws_iam_policy_document.backend_permissions.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backend_permissions" {
  role       = aws_iam_role.backend_service.name
  policy_arn = aws_iam_policy.backend_permissions.arn
}

data "aws_iam_policy_document" "deletion_permissions" {
  statement {
    sid    = "CognitoUserDeletion"
    effect = "Allow"
    actions = [
      "cognito-idp:AdminDisableUser",
      "cognito-idp:AdminDeleteUser",
      "cognito-idp:AdminGetUser"
    ]

    resources = [aws_cognito_user_pool.main.arn]
  }

  statement {
    sid    = "UsersTableDelete"
    effect = "Allow"
    actions = [
      "dynamodb:Query",
      "dynamodb:DeleteItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:GetItem"
    ]

    resources = [
      aws_dynamodb_table.users.arn,
      "${aws_dynamodb_table.users.arn}/index/*"
    ]
  }

  statement {
    sid    = "LedgerWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem"
    ]

    resources = [aws_dynamodb_table.deletion_ledger.arn]
  }

  dynamic "statement" {
    for_each = length(var.deletion_s3_bucket_arns) > 0 ? [1] : []

    content {
      sid    = "S3ListBucketsForDeletion"
      effect = "Allow"
      actions = [
        "s3:ListBucket"
      ]

      resources = var.deletion_s3_bucket_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.deletion_s3_bucket_arns) > 0 ? [1] : []

    content {
      sid    = "S3DeleteUserObjects"
      effect = "Allow"
      actions = [
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
      ]

      resources = [for arn in var.deletion_s3_bucket_arns : "${arn}/*"]
    }
  }
}

resource "aws_iam_policy" "deletion_permissions" {
  name   = "${local.name_prefix}-deletion-permissions"
  policy = data.aws_iam_policy_document.deletion_permissions.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "deletion_permissions" {
  role       = aws_iam_role.deletion_workflow.name
  policy_arn = aws_iam_policy.deletion_permissions.arn
}

resource "aws_iam_role_policy_attachment" "backend_basic_execution" {
  count = contains(local.backend_assume_role_services, "lambda.amazonaws.com") ? 1 : 0

  role       = aws_iam_role.backend_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "deletion_basic_execution" {
  count = contains(local.deletion_assume_role_services, "lambda.amazonaws.com") ? 1 : 0

  role       = aws_iam_role.deletion_workflow.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
