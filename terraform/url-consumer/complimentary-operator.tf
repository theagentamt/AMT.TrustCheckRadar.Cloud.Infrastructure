variable "complimentary_operator" {
  description = "Optional Dev-only complimentary-access operator. Provisioning and activation are explicit; the operator can invoke one AWS_IAM route only."
  type = object({
    active              = bool
    trusted_assumer_arn = string
    api_stage_name      = string
    approval_reference  = string
  })
  default = null
  validation {
    condition = var.complimentary_operator == null ? true : try(
      var.enabled && var.environment == "dev" && var.aws_region == "us-east-1" &&
      var.project_name == "trustcheckradar" && var.api_gateway != null &&
      var.authority_configuration != null &&
      can(regex("^arn:aws:iam::107827791950:role/[A-Za-z0-9_+=,.@/-]+$", var.complimentary_operator.trusted_assumer_arn)) &&
      !strcontains(var.complimentary_operator.trusted_assumer_arn, "*") &&
      var.complimentary_operator.api_stage_name == "$default" &&
    can(regex("^SECUR4ALL-232[: ][A-Za-z0-9_./ -]{1,400}$", var.complimentary_operator.approval_reference)), false)
    error_message = "Complimentary operator requires the exact same-account Dev assumer role, $default API stage, explicit authority policy and a SECUR4ALL-232 approval reference."
  }
}

locals {
  complimentary_operator_provisioned = var.enabled && var.complimentary_operator != null
  complimentary_operator_active      = local.complimentary_operator_provisioned && var.complimentary_operator.active
  complimentary_operator_path        = "v1/operator/complimentary-access"
  complimentary_operator_role_arn    = local.complimentary_operator_provisioned ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-complimentary-operator" : null
}

resource "aws_iam_role" "complimentary_operator" {
  count = local.complimentary_operator_provisioned ? 1 : 0
  name  = "${local.prefix}-complimentary-operator"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ExactReviewedAdministrator"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = var.complimentary_operator.trusted_assumer_arn }
    }]
  })
  max_session_duration = 3600
  tags                 = var.tags
}

resource "aws_iam_role_policy" "complimentary_operator" {
  count = local.complimentary_operator_provisioned ? 1 : 0
  name  = "invoke-one-complimentary-access-route"
  role  = aws_iam_role.complimentary_operator[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeExactOperatorRoute"
      Effect   = "Allow"
      Action   = "execute-api:Invoke"
      Resource = "${var.api_gateway.execution_arn}/${var.complimentary_operator.api_stage_name}/POST/${local.complimentary_operator_path}"
    }]
  })
}

resource "aws_apigatewayv2_route" "complimentary_operator" {
  count              = local.complimentary_operator_provisioned ? 1 : 0
  api_id             = var.api_gateway.api_id
  route_key          = "POST /${local.complimentary_operator_path}"
  target             = "integrations/${aws_apigatewayv2_integration.v1["entitlements"].id}"
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_permission" "complimentary_operator" {
  count          = local.complimentary_operator_provisioned ? 1 : 0
  statement_id   = "AllowV1-ComplimentaryOperator"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.runtime["entitlements"].function_name
  qualifier      = aws_lambda_alias.runtime["entitlements"].name
  principal      = "apigateway.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "${var.api_gateway.execution_arn}/${var.complimentary_operator.api_stage_name}/POST/${local.complimentary_operator_path}"
}
