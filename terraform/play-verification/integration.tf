variable "catalog_p1m_verified" {
  description = "Catalog read verified the fixed monthly base plan; does not enable access or prove test purchases."
  type        = bool
  default     = false
}
variable "api_gateway" {
  description = "Optional exact Dev API and stage. Stage throttles are managed by the API root."
  type        = object({ api_id = string, execution_arn = string, stage_name = string })
  default     = null
  validation {
    condition = var.api_gateway == null ? true : (
      var.api_gateway.api_id == "icuak34th9" &&
      var.api_gateway.execution_arn == "arn:aws:execute-api:us-east-1:107827791950:icuak34th9" &&
      var.api_gateway.stage_name == "$default"
    )
    error_message = "Only the verified Dev API/stage is supported."
  }
}
locals {
  route_enabled = var.enabled && var.api_gateway != null
}
resource "aws_apigatewayv2_authorizer" "play" {
  count            = local.route_enabled ? 1 : 0
  api_id           = var.api_gateway.api_id
  name             = "${local.name}-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {
    audience = [var.deployment.cognito_app_client_id]
    issuer   = var.deployment.cognito_issuer
  }
}
resource "aws_apigatewayv2_integration" "play" {
  count                  = local.route_enabled ? 1 : 0
  api_id                 = var.api_gateway.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.runtime[0].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}
resource "aws_apigatewayv2_route" "play" {
  count                = local.route_enabled ? 1 : 0
  api_id               = var.api_gateway.api_id
  route_key            = "POST /v1/purchases/google-play/verify"
  target               = "integrations/${aws_apigatewayv2_integration.play[0].id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.play[0].id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}
resource "aws_lambda_permission" "play" {
  count          = local.route_enabled ? 1 : 0
  statement_id   = "AllowVerifiedPlayRoute"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.runtime[0].function_name
  qualifier      = aws_lambda_alias.runtime[0].name
  principal      = "apigateway.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "${var.api_gateway.execution_arn}/${var.api_gateway.stage_name}/POST/v1/purchases/google-play/verify"
}
