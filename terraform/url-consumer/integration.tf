variable "engineering_subjects" {
  description = "Exact synthetic Dev Cognito subjects allowed in engineering tests. Empty never means public access."
  type        = set(string)
  default     = []
  validation {
    condition     = length(var.engineering_subjects) <= 3 && alltrue([for subject in var.engineering_subjects : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", subject))])
    error_message = "Supply at most three exact synthetic Cognito UUID subjects."
  }
}
variable "authority_configuration" {
  description = "Explicit engineering horizons; result retention is owner-approved at seven days."
  type = object({
    operation_validity_seconds = number
    worker_settlement_seconds  = number
    reconciliation_seconds     = number
    counter_retention_seconds  = number
  })
  default = null
  validation {
    condition = var.authority_configuration == null ? true : (
      alltrue([for value in values(var.authority_configuration) : value > 0 && value == floor(value)]) &&
      var.authority_configuration.operation_validity_seconds + var.authority_configuration.worker_settlement_seconds + var.authority_configuration.reconciliation_seconds <= 604800 &&
      var.authority_configuration.counter_retention_seconds == 604800
    )
    error_message = "Horizons must be integral, bounded by seven-day receipts; attempt counter retention must be seven days."
  }
}
variable "deletion_stream_arn" {
  type    = string
  default = ""
  validation {
    condition     = var.deletion_stream_arn == "" || can(regex("^arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/[0-9T:.-]+$", var.deletion_stream_arn))
    error_message = "Use the exact Dev deletion-ledger stream."
  }
}
variable "api_gateway" {
  description = "Existing Dev HTTP API; this root owns only the new V1 routes and authorizer."
  type        = object({ api_id = string, execution_arn = string })
  default     = null
  validation {
    condition = var.api_gateway == null ? true : (
      can(regex("^[a-z0-9]{10}$", var.api_gateway.api_id)) &&
      var.api_gateway.execution_arn == "arn:aws:execute-api:us-east-1:107827791950:${var.api_gateway.api_id}"
    )
    error_message = "Gateway must be the verified same-account Dev API."
  }
}
variable "alert_topic_arn" {
  type    = string
  default = null
  validation {
    condition     = var.alert_topic_arn == null || var.alert_topic_arn == "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
    error_message = "Use the existing confirmed support alert topic."
  }
}
variable "activate_engineering" {
  description = "Restricted synthetic-account Dev qualification only; never general customer activation."
  type        = bool
  default     = false
  validation {
    condition = !var.activate_engineering || (
      var.enabled && var.environment == "dev" && length(var.engineering_subjects) > 0 &&
      var.authority_configuration != null && var.api_gateway != null && var.alert_topic_arn != null &&
      var.deletion_stream_arn != "" && try(contains(keys(var.deployment.artifacts), "deletion"), false)
    )
    error_message = "Engineering activation requires synthetic subjects, explicit policy, authenticated routing, monitoring and deletion worker/stream."
  }
}
variable "activate_access_engineering" {
  description = "Restricted Dev access snapshots and cleanup only; URL execution and trial activation remain disabled."
  type        = bool
  default     = false
  validation {
    condition = !var.activate_access_engineering || (
      !var.activate_engineering && var.enabled && var.environment == "dev" &&
      length(var.engineering_subjects) > 0 && var.authority_configuration != null &&
      var.api_gateway != null && var.alert_topic_arn != null && var.deletion_stream_arn != "" &&
      try(contains(keys(var.deployment.artifacts), "deletion"), false) &&
      length(trimspace(var.access_qualification_reference)) > 0
    )
    error_message = "Access-only qualification requires exact subjects, policy, authenticated routing, alerts, deletion/expiry cleanup, a recorded readiness reference and full engineering mode off."
  }
}
variable "access_qualification_reference" {
  description = "Reference to independently reviewed whole-table cleanup/key inventory and scoped account-test readiness; a reference alone does not establish that evidence."
  type        = string
  default     = ""
  validation {
    condition     = length(var.access_qualification_reference) <= 512
    error_message = "Use a bounded evidence reference, not account identifiers or credentials."
  }
}
locals {
  authority_engineering_active = var.activate_engineering || var.activate_access_engineering
}
locals {
  routes = var.enabled && var.api_gateway != null ? {
    prepare   = { key = "POST /v1/url-checks/prepare", function = "consumer", permission = "POST/v1/url-checks/prepare" }
    submit    = { key = "POST /v1/url-checks", function = "consumer", permission = "POST/v1/url-checks" }
    reconcile = { key = "POST /v1/url-checks/reconcile", function = "consumer", permission = "POST/v1/url-checks/reconcile" }
    access    = { key = "GET /v1/access", function = "entitlements", permission = "GET/v1/access" }
    trial     = { key = "POST /v1/access/trial", function = "entitlements", permission = "POST/v1/access/trial" }
  } : {}
  integrations         = length(local.routes) > 0 ? toset(["consumer", "entitlements"]) : toset([])
  deletion_provisioned = contains(keys(local.functions), "deletion")
}
resource "aws_apigatewayv2_authorizer" "v1" {
  count            = length(local.routes) > 0 ? 1 : 0
  api_id           = var.api_gateway.api_id
  name             = "${local.prefix}-v1-checks-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {
    audience = [var.deployment.cognito_app_client_id]
    issuer   = var.deployment.cognito_issuer
  }
}
resource "aws_apigatewayv2_integration" "v1" {
  for_each               = local.integrations
  api_id                 = var.api_gateway.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.runtime[each.key].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = each.key == "consumer" ? 29000 : 15000
}
resource "aws_apigatewayv2_route" "v1" {
  for_each             = local.routes
  api_id               = var.api_gateway.api_id
  route_key            = each.value.key
  target               = "integrations/${aws_apigatewayv2_integration.v1[each.value.function].id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.v1[0].id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}
resource "aws_lambda_permission" "v1" {
  for_each       = local.routes
  statement_id   = "AllowV1-${each.key}"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.runtime[each.value.function].function_name
  qualifier      = aws_lambda_alias.runtime[each.value.function].name
  principal      = "apigateway.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "${var.api_gateway.execution_arn}/*/${each.value.permission}"
}
