locals {
  routes = var.enabled && var.api_gateway != null ? {
    prepare   = { key = "POST /v1/message-checks/prepare", permission = "POST/v1/message-checks/prepare" }
    submit    = { key = "POST /v1/message-checks", permission = "POST/v1/message-checks" }
    reconcile = { key = "POST /v1/message-checks/reconcile", permission = "POST/v1/message-checks/reconcile" }
  } : {}
}

resource "aws_apigatewayv2_integration" "message" {
  count                  = length(local.routes) > 0 ? 1 : 0
  api_id                 = var.api_gateway.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.runtime["consumer"].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "message" {
  for_each             = local.routes
  api_id               = var.api_gateway.api_id
  route_key            = each.value.key
  target               = "integrations/${aws_apigatewayv2_integration.message[0].id}"
  authorization_type   = "JWT"
  authorizer_id        = var.api_gateway.authorizer_id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

resource "aws_lambda_permission" "message" {
  for_each       = local.routes
  statement_id   = "AllowMessage-${each.key}"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.runtime["consumer"].function_name
  qualifier      = aws_lambda_alias.runtime["consumer"].name
  principal      = "apigateway.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "${var.api_gateway.execution_arn}/*/${each.value.permission}"
}
