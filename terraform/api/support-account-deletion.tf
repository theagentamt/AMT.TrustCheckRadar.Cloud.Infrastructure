# SECUR4ALL-333 candidate; explicit scoped activation is defined separately.
variable "support_account_deletion_deployment" {
  description = "Optional immutable disabled support-deletion candidate; no route, verifier key, operator grant or account-data permission."
  type = object({
    release_id         = string
    object_version     = string
    source_hash        = string
    approval_reference = string
  })
  default = null
  validation {
    condition = var.support_account_deletion_deployment == null ? true : try(
      var.environment == "dev" &&
      can(regex("^[0-9a-f]{40}$", var.support_account_deletion_deployment.release_id)) &&
      length(trimspace(var.support_account_deletion_deployment.object_version)) > 0 &&
      var.support_account_deletion_deployment.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.support_account_deletion_deployment.source_hash)) &&
      length(trimspace(var.support_account_deletion_deployment.approval_reference)) > 0,
      false
    )
    error_message = "Support-deletion preparation requires Dev, a full source SHA, immutable object version/hash and reviewed approval reference."
  }
}

locals {
  support_account_deletion_name = "${local.name_prefix}-support-account-deletion"
}

resource "aws_cloudwatch_log_group" "support_account_deletion" {
  count             = var.support_account_deletion_deployment == null ? 0 : 1
  name              = "/aws/lambda/${local.support_account_deletion_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_iam_role" "support_account_deletion" {
  count              = var.support_account_deletion_deployment == null ? 0 : 1
  name               = "${local.support_account_deletion_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "support_account_deletion" {
  count                   = var.support_account_deletion_deployment == null ? 0 : 1
  source_policy_documents = local.support_admission_enabled ? [jsonencode({ Version = "2012-10-17", Statement = local.support_admission_statements })] : []
  statement {
    sid       = "WriteOwnLogsOnly"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.support_account_deletion[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "support_account_deletion" {
  count  = var.support_account_deletion_deployment == null ? 0 : 1
  name   = "disabled-support-deletion"
  role   = aws_iam_role.support_account_deletion[0].id
  policy = data.aws_iam_policy_document.support_account_deletion[0].json
}

resource "aws_lambda_function" "support_account_deletion" {
  count                          = var.support_account_deletion_deployment == null ? 0 : 1
  function_name                  = local.support_account_deletion_name
  role                           = aws_iam_role.support_account_deletion[0].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = "app.lambda_handler"
  memory_size                    = 256
  timeout                        = 15
  reserved_concurrent_executions = 1
  s3_bucket                      = local.foundation.artifact_bucket_name
  s3_key                         = "releases/${var.support_account_deletion_deployment.release_id}/support_account_deletion.zip"
  s3_object_version              = var.support_account_deletion_deployment.object_version
  source_code_hash               = var.support_account_deletion_deployment.source_hash
  publish                        = true
  environment {
    variables = merge({
      APP_ENVIRONMENT                  = var.environment
      SUPPORT_ACCOUNT_DELETION_ENABLED = tostring(local.support_admission_enabled)
    }, local.support_admission_enabled ? { SUPPORT_ACCOUNT_DELETION_CONFIG_JSON = var.support_account_deletion_activation.config_json } : {})
  }
  depends_on = [aws_iam_role_policy.support_account_deletion]
  tags       = local.common_tags
}

resource "aws_lambda_alias" "support_account_deletion" {
  count            = var.support_account_deletion_deployment == null ? 0 : 1
  name             = "candidate"
  function_name    = aws_lambda_function.support_account_deletion[0].function_name
  function_version = aws_lambda_function.support_account_deletion[0].version
}

resource "aws_lambda_function_event_invoke_config" "support_account_deletion" {
  count                        = var.support_account_deletion_deployment == null ? 0 : 1
  function_name                = aws_lambda_function.support_account_deletion[0].function_name
  qualifier                    = aws_lambda_alias.support_account_deletion[0].name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}

output "support_account_deletion_candidate_contract" {
  precondition {
    condition     = var.support_account_deletion_activation == null || local.support_account_deletion_activation_valid
    error_message = "Support admission requires reviewed Dev source, protected route, active cleanup workers, exact config/resource/operator/inventory pins and 1-10 explicit subjects."
  }
  description = "Candidate capability only. A deployed disabled archive does not fulfill a privacy email request."
  value = {
    schema_version           = 1
    deployed                 = var.support_account_deletion_deployment != null
    enabled                  = local.support_admission_enabled
    routes                   = [for route in aws_apigatewayv2_route.support_account_deletion : route.route_key]
    verification_writer      = false
    verification_storage     = false
    operator_grants          = false
    account_data_permissions = local.support_admission_enabled
    email_deletion_available = false
    activation_story         = "SECUR4ALL-333"
    artifact_release         = try(var.support_account_deletion_deployment.release_id, null)
  }
}
