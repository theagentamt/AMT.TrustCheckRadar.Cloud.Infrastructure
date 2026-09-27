variable "account_export_activation" {
  description = "Reviewed, subject-scoped Dev export. Runtime qualifies the private handler; api adds its JWT route. Evidence references record operator review, not Terraform qualification."
  type = object({
    phase               = string
    source_sha          = string
    http_subjects       = set(string)
    policy_reference    = string
    inventory_reference = string
    identity_reference  = string
    contract_reference  = string
    runtime_reference   = optional(string, "")
  })
  default = null
  validation {
    condition = var.account_export_activation == null ? true : try(
      var.environment == "dev" &&
      contains(["runtime", "api"], var.account_export_activation.phase) &&
      can(regex("^[0-9a-f]{40}$", var.account_export_activation.source_sha)) &&
      var.account_export_activation.source_sha == var.account_export_deployment.release_id &&
      var.account_export_monitoring != null && var.account_export_play_token_table_arn != null &&
      var.history_deployment != null && local.recovery_storage_valid &&
      local.account_data_outbox_storage_valid && var.campaign_period_work_activation != null &&
      local.period_work_prepared &&
      length(var.account_export_activation.http_subjects) >= 1 &&
      length(var.account_export_activation.http_subjects) <= 10 &&
      alltrue([for sub in var.account_export_activation.http_subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", sub))]) &&
      alltrue([for ref in [
        var.account_export_activation.policy_reference,
        var.account_export_activation.inventory_reference,
        var.account_export_activation.identity_reference,
        var.account_export_activation.contract_reference
      ] : length(trimspace(ref)) > 0]) &&
      (var.account_export_activation.phase != "api" || length(trimspace(var.account_export_activation.runtime_reference)) > 0), false
    )
    error_message = "Export activation requires reviewed Dev source, all current reader stores/work pins, monitoring, one to ten canonical subjects and policy/inventory/identity/contract evidence. The API phase also requires private runtime acceptance."
  }
}

variable "account_export_work_compatibility" {
  description = "Optional reviewed export-only reader upgrade against the unchanged period-work writer source. Does not qualify inventory or change writer pins."
  type = object({
    work_source_sha   = string
    export_source_sha = string
    review_reference  = string
  })
  default = null
  validation {
    condition = var.account_export_work_compatibility == null ? true : try(
      var.environment == "dev" && local.period_work_prepared &&
      var.account_export_work_compatibility.work_source_sha == var.account_data_deployment.release_id &&
      var.account_export_work_compatibility.export_source_sha == var.account_export_deployment.release_id &&
      alltrue([for sha in [var.account_export_work_compatibility.work_source_sha, var.account_export_work_compatibility.export_source_sha] : can(regex("^[0-9a-f]{40}$", sha))]) &&
      length(trimspace(var.account_export_work_compatibility.review_reference)) > 0, false
    )
    error_message = "Export reader compatibility requires exact reviewed Dev work/writer and exporter source pairs; stale or incomplete overrides are rejected."
  }
}

locals {
  account_export_runtime_enabled = var.account_export_activation != null && !var.campaign_period_work_quiescence
  account_export_route_selected  = try(var.account_export_activation.phase == "api", false)
  account_export_activation_env = local.account_export_runtime_enabled ? {
    ACCOUNT_EXPORT_ENABLED             = "true"
    ACCOUNT_EXPORT_HTTP_SUBJECTS_JSON  = jsonencode(sort(tolist(var.account_export_activation.http_subjects)))
    ACCOUNT_EXPORT_PLAY_TOKENS_ENABLED = "true"
    ACCOUNT_EXPORT_INVENTORY_STATUS    = "verified_complete"
    COGNITO_USERNAME_IS_SUB            = "true"
  } : {}
}

resource "aws_apigatewayv2_integration" "account_export" {
  count                  = local.account_export_route_selected ? 1 : 0
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.account_export[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "account_export" {
  count                = local.account_export_route_selected ? 1 : 0
  api_id               = aws_apigatewayv2_api.age_attestation.id
  route_key            = "POST /v1/users/account-export"
  target               = "integrations/${aws_apigatewayv2_integration.account_export[0].id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito_jwt.id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

resource "aws_lambda_permission" "account_export_gateway" {
  count          = local.account_export_route_selected ? 1 : 0
  statement_id   = "AccountExportRoute-POST"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.account_export[0].function_name
  principal      = "apigateway.amazonaws.com"
  source_account = split(":", local.users_table_arn)[4]
  source_arn     = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/POST/v1/users/account-export"
}
