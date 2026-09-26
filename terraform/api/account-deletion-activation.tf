variable "account_deletion_activation" {
  description = "Reviewed Dev deletion rollout. Null is disabled; workers starts reconciliation before api exposes authenticated admission. Evidence references are operator attestations, not automatically qualified inventory."
  type = object({
    phase                       = string
    source_sha                  = string
    policy_reference            = string
    inventory_reference         = string
    identity_reference          = string
    component_reference         = string
    worker_acceptance_reference = optional(string, "")
    http_subjects               = optional(set(string), [])
  })
  default = null
  validation {
    condition = var.account_deletion_activation == null ? true : try(
      var.environment == "dev" &&
      contains(["workers", "api"], var.account_deletion_activation.phase) &&
      can(regex("^[0-9a-f]{40}$", var.account_deletion_activation.source_sha)) &&
      var.account_deletion_activation.source_sha == var.account_data_deployment.release_id &&
      var.account_data_finalization_candidate != null &&
      var.account_data_monitoring != null &&
      local.recovery_storage_valid && local.account_data_outbox_storage_valid &&
      local.campaign_recovery_preparation_selected && local.campaign_recovery_preparation_valid &&
      alltrue([for ref in [
        var.account_deletion_activation.policy_reference,
        var.account_deletion_activation.inventory_reference,
        var.account_deletion_activation.identity_reference,
        var.account_deletion_activation.component_reference
      ] : length(trimspace(ref)) > 0]) &&
      (var.account_deletion_activation.phase != "api" || (length(trimspace(var.account_deletion_activation.worker_acceptance_reference)) > 0 && length(var.account_deletion_activation.http_subjects) >= 1)) &&
      length(var.account_deletion_activation.http_subjects) <= 10 &&
      (var.account_deletion_activation.phase != "workers" || length(var.account_deletion_activation.http_subjects) == 0) &&
      alltrue([for sub in var.account_deletion_activation.http_subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", sub))]),
      false
    )
    error_message = "Deletion activation requires reviewed Dev source, finalization pins, exact storage/index contracts, monitoring and policy/inventory/identity/component evidence; API admission also requires prior deployed worker acceptance and one to ten explicit canonical Dev subjects; workers-only accepts no HTTP subjects."
  }
}

locals {
  account_deletion_workers_enabled = var.account_deletion_activation != null
  account_deletion_routes_enabled  = try(var.account_deletion_activation.phase == "api", false)
  account_deletion_components = [
    "SESSION_REVOCATION", "DEVICE_BINDINGS", "DEVICE_RECOVERY", "ANALYSIS_ABUSE",
    "HISTORY", "CAMPAIGN", "CAMPAIGN_OUTBOX", "ENTITLEMENTS", "V1_AUTHORITY",
    "PLAY_TOKENS", "USER_PROFILE", "IDENTITY"
  ]
  # Reviewed activation supplies configuration only. The runtime must still
  # verify the independent inventory marker and every account-owned receipt.
  account_deletion_activation_env = local.account_deletion_workers_enabled ? {
    ACCOUNT_DELETION_ENABLED                        = "true"
    ACCOUNT_DELETION_HTTP_SUBJECTS_JSON             = jsonencode(sort(tolist(var.account_deletion_activation.http_subjects)))
    ACCOUNT_IDENTITY_FINALIZER_ENABLED              = "true"
    COGNITO_USERNAME_IS_SUB                         = "true"
    ACCOUNT_DELETION_POLICY_STATUS                  = "approved"
    ACCOUNT_DELETION_COMPLETION_STATUS              = "complete"
    ACCOUNT_DATA_INVENTORY_STATUS                   = "approved"
    ACCOUNT_DELETION_REQUIRED_COMPONENTS_JSON       = jsonencode(local.account_deletion_components)
    USER_PROFILE_DELETION_POLICY_STATUS             = "approved"
    ANALYSIS_REQUEST_DEDUPE_POLICY_STATUS           = "approved"
    ANALYSIS_LEGACY_REQUEST_RETENTION_POLICY_STATUS = "approved"
    ANALYSIS_CONSUMPTION_DELETION_POLICY_STATUS     = "approved"
    CAMPAIGN_OUTBOX_LOCATOR_COVERAGE_STATUS         = "approved"
    CAMPAIGN_RECOVERY_WRITES_ENABLED                = "true"
  } : {}
  account_deletion_routes = local.account_deletion_routes_enabled ? toset(["GET", "POST"]) : toset([])
}

resource "aws_apigatewayv2_integration" "account_deletion" {
  count                  = local.account_deletion_routes_enabled ? 1 : 0
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.account_data[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "account_deletion" {
  for_each             = local.account_deletion_routes
  api_id               = aws_apigatewayv2_api.age_attestation.id
  route_key            = "${each.key} /v1/users/account-deletion"
  target               = "integrations/${aws_apigatewayv2_integration.account_deletion[0].id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito_jwt.id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

resource "aws_lambda_permission" "account_deletion_gateway" {
  for_each       = local.account_deletion_routes
  statement_id   = "AccountDeletionRoute-${each.key}"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.account_data[0].function_name
  principal      = "apigateway.amazonaws.com"
  source_account = split(":", local.users_table_arn)[4]
  source_arn     = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/${each.key}/v1/users/account-deletion"
}
