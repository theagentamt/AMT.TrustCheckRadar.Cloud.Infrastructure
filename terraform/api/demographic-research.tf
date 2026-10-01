variable "demographic_research_deployment" {
  description = "Immutable optional-demographic-research candidate. Provisioning alone exposes no route and accepts no values."
  type = object({
    release_id         = string
    object_version     = string
    source_hash        = string
    approval_reference = string
    promotion_approved = bool
  })
  default = null
  validation {
    condition = var.demographic_research_deployment == null ? true : try(
      can(regex("^[0-9a-f]{40}$", var.demographic_research_deployment.release_id)) &&
      length(trimspace(var.demographic_research_deployment.object_version)) > 0 &&
      var.demographic_research_deployment.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.demographic_research_deployment.source_hash)) &&
      length(trimspace(var.demographic_research_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.demographic_research_deployment.promotion_approved), false
    )
    error_message = "Demographic research requires a full immutable source SHA, object version/hash, approval reference and separate UAT/Production promotion approval."
  }
}

variable "demographic_research_lifecycle_compatibility" {
  description = "Exact source/inventory review proving demographic state is included in export and USER_PROFILE deletion. It does not expose the demographic API."
  type = object({
    source_sha          = string
    contract_reference  = string
    inventory_reference = string
    export_reference    = string
    deletion_reference  = string
  })
  default = null
  validation {
    condition = var.demographic_research_lifecycle_compatibility == null ? true : try(
      can(regex("^[0-9a-f]{40}$", var.demographic_research_lifecycle_compatibility.source_sha)) &&
      var.demographic_research_deployment != null &&
      var.account_data_deployment != null &&
      var.account_export_deployment != null &&
      var.account_data_finalization_candidate != null &&
      var.demographic_research_lifecycle_compatibility.source_sha == var.demographic_research_deployment.release_id &&
      var.demographic_research_lifecycle_compatibility.source_sha == var.account_data_deployment.release_id &&
      var.demographic_research_lifecycle_compatibility.source_sha == var.account_export_deployment.release_id &&
      alltrue([for reference in [
        var.demographic_research_lifecycle_compatibility.contract_reference,
        var.demographic_research_lifecycle_compatibility.inventory_reference,
        var.demographic_research_lifecycle_compatibility.export_reference,
        var.demographic_research_lifecycle_compatibility.deletion_reference,
      ] : length(trimspace(reference)) > 0]), false
    )
    error_message = "Demographic lifecycle compatibility requires one exact Lambda source across the profile, export and deletion packages plus reviewed contract, inventory, export and deletion evidence."
  }
}

variable "demographic_research_activation" {
  description = "Reviewed subject-scoped Dev activation. read_withdraw keeps new enrollment/correction closed; enrollment additionally requires published-policy evidence."
  type = object({
    phase                        = string
    source_sha                   = string
    http_subjects                = set(string)
    contract_reference           = string
    lifecycle_reference          = string
    runtime_reference            = string
    policy_publication_reference = optional(string, "")
  })
  default = null
  validation {
    condition = var.demographic_research_activation == null ? true : try(
      var.environment == "dev" &&
      contains(["read_withdraw", "enrollment"], var.demographic_research_activation.phase) &&
      var.demographic_research_deployment != null &&
      var.demographic_research_lifecycle_compatibility != null &&
      var.demographic_research_monitoring != null &&
      var.demographic_research_activation.source_sha == var.demographic_research_deployment.release_id &&
      var.demographic_research_activation.source_sha == var.demographic_research_lifecycle_compatibility.source_sha &&
      length(var.demographic_research_activation.http_subjects) >= 1 &&
      length(var.demographic_research_activation.http_subjects) <= 10 &&
      alltrue([for sub in var.demographic_research_activation.http_subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", sub))]) &&
      alltrue([for reference in [
        var.demographic_research_activation.contract_reference,
        var.demographic_research_activation.lifecycle_reference,
        var.demographic_research_activation.runtime_reference,
      ] : length(trimspace(reference)) > 0]) &&
      (var.demographic_research_activation.phase != "enrollment" || length(trimspace(var.demographic_research_activation.policy_publication_reference)) > 0), false
    )
    error_message = "Activation requires reviewed Dev source/lifecycle/runtime evidence, monitoring, one to ten exact subjects, and published-policy evidence before enrollment."
  }
}

locals {
  demographic_research_name               = "${local.name_prefix}-demographic-research"
  demographic_research_path               = "/v1/users/demographic-research-profile"
  demographic_research_runtime_enabled    = var.demographic_research_activation != null
  demographic_research_enrollment_enabled = try(var.demographic_research_activation.phase == "enrollment", false)
  demographic_research_routes             = local.demographic_research_runtime_enabled ? toset(["GET", "PUT"]) : toset([])
  demographic_research_lifecycle_selected = var.demographic_research_lifecycle_compatibility != null
  demographic_research_activation_env = local.demographic_research_runtime_enabled ? {
    DEMOGRAPHIC_RESEARCH_SERVICE_ENABLED    = "true"
    DEMOGRAPHIC_RESEARCH_ENROLLMENT_ENABLED = tostring(local.demographic_research_enrollment_enabled)
    DEMOGRAPHIC_RESEARCH_HTTP_SUBJECTS_JSON = jsonencode(sort(tolist(var.demographic_research_activation.http_subjects)))
  } : {}
}

resource "aws_cloudwatch_log_group" "demographic_research" {
  count             = var.demographic_research_deployment == null ? 0 : 1
  name              = "/aws/lambda/${local.demographic_research_name}"
  retention_in_days = 14
  tags              = merge(local.common_tags, { DataClass = "content-free-demographic-operations" })
}

resource "aws_iam_role" "demographic_research" {
  count              = var.demographic_research_deployment == null ? 0 : 1
  name               = "${local.demographic_research_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "demographic_research" {
  count = var.demographic_research_deployment == null ? 0 : 1

  statement {
    sid       = "ReadOwnedProfileAndDemographicState"
    actions   = ["dynamodb:GetItem"]
    resources = [local.users_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }

  statement {
    sid       = "WriteOwnedDemographicTransaction"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]
    resources = [local.users_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
  }

  statement {
    sid       = "CheckOwnedDemographicTransaction"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [local.users_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
  }

  statement {
    sid       = "ReadOwnDeletionFence"
    actions   = ["dynamodb:GetItem"]
    resources = [local.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCOUNT#*"]
    }
  }

  statement {
    sid       = "WriteOwnDemographicAuthorityTransaction"
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem"]
    resources = [local.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCOUNT#*"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
  }

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.demographic_research[0].arn}:*"]
  }

  statement {
    sid       = "DenyPayloadStorageAndRoleChaining"
    effect    = "Deny"
    actions   = ["s3:*", "ssm:*", "secretsmanager:*", "sts:AssumeRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "demographic_research" {
  count  = var.demographic_research_deployment == null ? 0 : 1
  name   = "authenticated-demographic-research"
  role   = aws_iam_role.demographic_research[0].id
  policy = data.aws_iam_policy_document.demographic_research[0].json
}

resource "aws_lambda_function" "demographic_research" {
  count                          = var.demographic_research_deployment == null ? 0 : 1
  function_name                  = local.demographic_research_name
  role                           = aws_iam_role.demographic_research[0].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = "app.lambda_handler"
  memory_size                    = 256
  timeout                        = 15
  reserved_concurrent_executions = local.demographic_research_runtime_enabled ? 1 : 0
  s3_bucket                      = local.foundation.artifact_bucket_name
  s3_key                         = "releases/${var.demographic_research_deployment.release_id}/demographic_research.zip"
  s3_object_version              = var.demographic_research_deployment.object_version
  source_code_hash               = var.demographic_research_deployment.source_hash
  environment {
    variables = merge({
      DEMOGRAPHIC_RESEARCH_SERVICE_ENABLED            = "false"
      DEMOGRAPHIC_RESEARCH_ENROLLMENT_ENABLED         = "false"
      DEMOGRAPHIC_RESEARCH_HTTP_SUBJECTS_JSON         = "[]"
      DEMOGRAPHIC_RESEARCH_ENVIRONMENT                = var.environment
      DEMOGRAPHIC_RESEARCH_USERS_TABLE_NAME           = local.users_table_name
      DEMOGRAPHIC_RESEARCH_DELETION_LEDGER_TABLE_NAME = local.deletion_ledger_table_name
      COGNITO_ISSUER                                  = local.jwt_issuer
      COGNITO_APP_CLIENT_ID                           = local.cognito_app_client_id
      COGNITO_REQUIRED_SCOPE                          = "aws.cognito.signin.user.admin"
    }, local.demographic_research_activation_env)
  }
  lifecycle {
    precondition {
      condition = try(
        local.users_table_name == "${local.name_prefix}-users" &&
        local.users_table_arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.account_fence[0].account_id}:table/${local.name_prefix}-users" &&
        local.deletion_ledger_table_name == "${local.name_prefix}-deletion-ledger" &&
        local.deletion_ledger_table_arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.account_fence[0].account_id}:table/${local.name_prefix}-deletion-ledger" &&
        startswith(local.cognito_user_pool_id, "${var.aws_region}_") &&
        local.cognito_app_client_id != "", false
      )
      error_message = "Demographic research requires exact same-account/Region/environment user, deletion and Cognito resources."
    }
  }
  depends_on = [aws_iam_role_policy.demographic_research, aws_cloudwatch_log_group.demographic_research]
  tags       = local.common_tags
}

resource "aws_lambda_function_event_invoke_config" "demographic_research" {
  count                        = var.demographic_research_deployment == null ? 0 : 1
  function_name                = aws_lambda_function.demographic_research[0].function_name
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 0
}

resource "aws_apigatewayv2_integration" "demographic_research" {
  count                  = local.demographic_research_runtime_enabled ? 1 : 0
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.demographic_research[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 15000
}

resource "aws_apigatewayv2_route" "demographic_research" {
  for_each             = local.demographic_research_routes
  api_id               = aws_apigatewayv2_api.age_attestation.id
  route_key            = "${each.key} ${local.demographic_research_path}"
  target               = "integrations/${aws_apigatewayv2_integration.demographic_research[0].id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito_jwt.id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

resource "aws_lambda_permission" "demographic_research_gateway" {
  for_each       = local.demographic_research_routes
  statement_id   = "DemographicResearchRoute-${each.key}"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.demographic_research[0].function_name
  principal      = "apigateway.amazonaws.com"
  source_account = split(":", local.users_table_arn)[4]
  source_arn     = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/${each.key}${local.demographic_research_path}"
}

output "demographic_research_candidate_contract" {
  value = {
    schema_version           = 1
    deployed                 = var.demographic_research_deployment != null
    service_enabled          = local.demographic_research_runtime_enabled
    enrollment_enabled       = local.demographic_research_enrollment_enabled
    lifecycle_selected       = local.demographic_research_lifecycle_selected
    routes                   = [for route in aws_apigatewayv2_route.demographic_research : route.route_key]
    endpoint_path            = local.demographic_research_path
    transport_version        = "1.0.0-candidate.1"
    notice_version           = "demographic-research-2026-09-30-v1"
    policy_version           = "optional-demographic-research-v1"
    purpose_version          = "consumer-protection-research-v1"
    profile_retention_days   = 400
    operation_retention_days = 7
    consent_audit_days       = 400
    cleanup_sla_hours        = 24
    public_policy_required   = true
    campaign_enrichment      = false
    commercial_use           = false
  }
}
