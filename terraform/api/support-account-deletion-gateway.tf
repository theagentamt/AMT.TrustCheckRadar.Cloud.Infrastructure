# SEC333 transport qualification only: the handler remains disabled and logs-only.
variable "support_account_deletion_gateway" {
  description = "Optional reviewed Dev IAM route for the disabled candidate. Does not enable admission."
  type = object({
    api_id             = string
    stage              = string
    approval_reference = string
  })
  default = null
  validation {
    condition = var.support_account_deletion_gateway == null ? true : try(
      var.environment == "dev" && var.support_account_deletion_deployment != null &&
      can(regex("^[a-z0-9]{10}$", var.support_account_deletion_gateway.api_id)) &&
      contains(["dev", "$default"], var.support_account_deletion_gateway.stage) &&
      var.support_account_deletion_gateway.stage == var.api_stage_name &&
      length(trimspace(var.support_account_deletion_gateway.approval_reference)) > 0,
      false
    )
    error_message = "Support transport requires the reviewed disabled Dev candidate, exact API/stage and an approval reference."
  }
}

locals {
  support_account_deletion_gateway_selected = var.support_account_deletion_gateway != null
  support_account_deletion_route_key        = "POST /support/account-deletion"
}

resource "aws_apigatewayv2_integration" "support_account_deletion" {
  count                  = local.support_account_deletion_gateway_selected ? 1 : 0
  api_id                 = aws_apigatewayv2_api.age_attestation.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.support_account_deletion[0].arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 15000
  lifecycle {
    precondition {
      condition     = var.support_account_deletion_gateway.api_id == aws_apigatewayv2_api.age_attestation.id
      error_message = "Reviewed support API identity must match the actual managed API."
    }
  }
}

resource "aws_apigatewayv2_route" "support_account_deletion" {
  count              = local.support_account_deletion_gateway_selected ? 1 : 0
  api_id             = aws_apigatewayv2_api.age_attestation.id
  route_key          = local.support_account_deletion_route_key
  target             = "integrations/${aws_apigatewayv2_integration.support_account_deletion[0].id}"
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_permission" "support_account_deletion_gateway" {
  count          = local.support_account_deletion_gateway_selected ? 1 : 0
  statement_id   = "SupportDeletionExactIamRoute"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.support_account_deletion[0].function_name
  principal      = "apigateway.amazonaws.com"
  source_account = "107827791950"
  source_arn     = "${aws_apigatewayv2_api.age_attestation.execution_arn}/${var.support_account_deletion_gateway.stage}/POST/support/account-deletion"
}
