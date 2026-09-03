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
  foundation           = data.terraform_remote_state.foundation.outputs.downstream_contract
  artifact_prefix      = "releases/${var.artifact_release}"
  name_prefix          = "${var.project_name}-${var.environment}"
  lambda_name          = coalesce(var.post_confirmation_lambda_name, "${local.name_prefix}-post-confirmation")
  artifact_bucket_name = coalesce(var.post_confirmation_lambda_s3_bucket, local.foundation.artifact_bucket_name)
  artifact_key         = coalesce(var.post_confirmation_lambda_s3_key, "${local.artifact_prefix}/post_confirmation.zip")
  user_pool_lambda_config = merge(
    var.user_pool_lambda_config_overrides,
    { PostConfirmation = aws_lambda_function.post_confirmation.arn }
  )

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "workflows"
  })
}

check "foundation_contract_version" {
  assert {
    condition     = local.foundation.schema_version == 1
    error_message = "The foundation state contract is incompatible with this identity-workflows stack."
  }
}

data "aws_iam_policy_document" "post_confirmation_assume_role" {
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

resource "aws_iam_role" "post_confirmation" {
  name               = "${local.lambda_name}-role"
  assume_role_policy = data.aws_iam_policy_document.post_confirmation_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "post_confirmation_basic_execution" {
  role       = aws_iam_role.post_confirmation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "post_confirmation_dynamodb" {
  statement {
    sid    = "UsersTableWrite"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]

    resources = [local.foundation.users_table_arn]
  }
}

resource "aws_iam_policy" "post_confirmation_dynamodb" {
  name   = "${local.lambda_name}-dynamodb"
  policy = data.aws_iam_policy_document.post_confirmation_dynamodb.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "post_confirmation_dynamodb" {
  role       = aws_iam_role.post_confirmation.name
  policy_arn = aws_iam_policy.post_confirmation_dynamodb.arn
}

resource "aws_lambda_function" "post_confirmation" {
  function_name = local.lambda_name
  role          = aws_iam_role.post_confirmation.arn
  runtime       = var.post_confirmation_lambda_runtime
  handler       = var.post_confirmation_lambda_handler

  timeout       = var.post_confirmation_lambda_timeout_seconds
  memory_size   = var.post_confirmation_lambda_memory_mb
  architectures = var.post_confirmation_lambda_architectures

  s3_bucket         = local.artifact_bucket_name
  s3_key            = local.artifact_key
  s3_object_version = var.post_confirmation_lambda_s3_object_version

  environment {
    variables = merge(var.post_confirmation_lambda_env, {
      USERS_TABLE_ARN = local.foundation.users_table_arn
    })
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_cognito_invoke_post_confirmation" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${local.foundation.cognito_user_pool_id}"
}

data "aws_caller_identity" "current" {}

resource "terraform_data" "configure_user_pool_post_confirmation" {
  triggers_replace = {
    user_pool_id   = local.foundation.cognito_user_pool_id
    lambda_config  = jsonencode(local.user_pool_lambda_config)
    lambda_arn     = aws_lambda_function.post_confirmation.arn
    source_arn     = aws_lambda_permission.allow_cognito_invoke_post_confirmation.source_arn
    source_version = coalesce(var.post_confirmation_lambda_s3_object_version, "unversioned")
    aws_region     = var.aws_region
    aws_profile    = var.aws_cli_profile != null ? var.aws_cli_profile : ""
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/update_user_pool_lambda_config.py --user-pool-id \"$USER_POOL_ID\" --post-confirmation-arn \"$LAMBDA_ARN\" --region \"$AWS_REGION\" --overrides-json \"$OVERRIDES_JSON\" $PROFILE_ARGUMENT"

    environment = {
      USER_POOL_ID     = local.foundation.cognito_user_pool_id
      LAMBDA_ARN       = aws_lambda_function.post_confirmation.arn
      AWS_REGION       = var.aws_region
      OVERRIDES_JSON   = jsonencode(var.user_pool_lambda_config_overrides)
      PROFILE_ARGUMENT = var.aws_cli_profile != null ? "--profile ${var.aws_cli_profile}" : ""
    }
  }

  depends_on = [aws_lambda_permission.allow_cognito_invoke_post_confirmation]
}
