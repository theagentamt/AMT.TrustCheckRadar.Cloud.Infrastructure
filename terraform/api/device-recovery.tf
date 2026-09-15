variable "device_recovery_allowed_principal_arns" {
  description = "Exact same-account IAM user or STS assumed-role session ARNs accepted by the corrected operator recovery handler. Empty denies all operators; never populate from mobile input."
  type        = set(string)
  default     = []
  nullable    = false
  validation {
    condition = alltrue([for arn in var.device_recovery_allowed_principal_arns :
      can(regex("^arn:aws:(iam::[0-9]{12}:user/[A-Za-z0-9+=,.@_/-]+|sts::[0-9]{12}:assumed-role/[A-Za-z0-9+=,.@_-]+/[A-Za-z0-9+=,.@_-]+)$", arn)) &&
      try(split(":", arn)[4] == split(":", local.users_table_arn)[4], false)
    ])
    error_message = "Operator recovery requires exact same-account IAM user or assumed-role session ARNs, without wildcards."
  }
}

variable "device_recovery_deployment" {
  description = "Coordinated immutable recovery and registration candidate. Null preserves existing packages."
  type = object({
    release_id         = string
    approval_reference = string
    promotion_approved = bool
    artifacts          = map(object({ object_version = string, source_hash = string }))
  })
  default = null
  validation {
    condition = var.device_recovery_deployment == null ? true : try(
      var.enable_device_recovery &&
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.device_recovery_deployment.release_id)) &&
      length(trimspace(var.device_recovery_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.device_recovery_deployment.promotion_approved) &&
      toset(keys(var.device_recovery_deployment.artifacts)) == toset(["recovery", "registration"]) &&
      alltrue([for artifact in var.device_recovery_deployment.artifacts :
        length(trimspace(artifact.object_version)) > 0 && artifact.object_version != "null" &&
        can(regex("^[A-Za-z0-9+/]{43}=$", artifact.source_hash))
      ]), false
    )
    error_message = "Recovery requires both version/hash-pinned packages, an approval reference, and separate UAT/Prod promotion approval."
  }
}

variable "device_self_recovery_enabled" {
  description = "Expose consumer recovery only after coordinated backend and security acceptance."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition = !var.device_self_recovery_enabled || try(
      var.device_recovery_deployment.release_id == var.history_deployment.release_id && local.recovery_storage_valid, false
    )
    error_message = "Consumer recovery requires the same pinned release for recovery, registration and all three History/analysis readers, plus approved same-account/environment recovery storage."
  }
}

locals {
  recovery_storage = try(local.foundation.device_recovery_control, null)
  recovery_storage_valid = try(
    local.recovery_storage.schema_version == 1 && local.recovery_storage.enabled &&
    local.recovery_storage.environment == var.environment &&
    local.recovery_storage.table_name == "${local.name_prefix}-device-recovery-control" &&
    local.recovery_storage.table_arn == "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.name_prefix}-device-recovery-control" &&
    local.recovery_storage.ttl_attribute == "expiresAt" &&
    local.recovery_storage.policy.approved && length(trimspace(local.recovery_storage.policy.approval_reference)) > 0 &&
    local.recovery_storage.policy.audit_retention_days == 90 &&
    local.recovery_storage.policy.receipt_retention_days == 7 &&
    local.recovery_storage.policy.rate_retention_hours == 24 &&
    local.recovery_storage.policy.pitr_days == 7,
    false
  )
  device_identity_env = var.device_recovery_deployment == null ? {} : {
    APP_ENVIRONMENT            = var.environment
    USERS_TABLE_NAME           = local.users_table_name
    DELETION_LEDGER_TABLE_NAME = local.deletion_ledger_table_name
    COGNITO_ISSUER             = local.jwt_issuer
    COGNITO_APP_CLIENT_ID      = local.cognito_app_client_id
    COGNITO_REQUIRED_SCOPE     = "aws.cognito.signin.user.admin"
  }
  device_consumer_recovery_env = {
    DEVICE_SELF_RECOVERY_ENABLED           = tostring(var.device_self_recovery_enabled)
    DEVICE_RECOVERY_CONTROL_TABLE_NAME     = local.recovery_storage_valid ? local.recovery_storage.table_name : ""
    DEVICE_RECOVERY_POLICY_STATUS          = local.recovery_storage_valid ? "approved" : "pending"
    DEVICE_RECOVERY_MAX_REAUTH_AGE_SECONDS = "300"
    DEVICE_RECOVERY_RATE_WINDOW_SECONDS    = "3600"
    DEVICE_RECOVERY_RATE_MAX_REQUESTS      = "3"
    DEVICE_RECOVERY_RATE_STATE_TTL_SECONDS = "86400"
    DEVICE_RECOVERY_RECEIPT_RETENTION_DAYS = "7"
    DEVICE_RECOVERY_AUDIT_RETENTION_DAYS   = local.recovery_storage_valid ? tostring(local.recovery_storage.policy.audit_retention_days) : "0"
  }
}

data "aws_iam_policy_document" "device_identity" {
  count = var.device_recovery_deployment != null ? 1 : 0
  statement {
    sid       = "AuthoritativeProfileFence"
    actions   = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"]
    resources = [local.users_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }
  statement {
    sid       = "AuthoritativeDeletionFence"
    actions   = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"]
    resources = [local.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCOUNT#*"]
    }
  }
  statement {
    sid       = "SerializeExistingActivePointer"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [local.device_bindings_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }
}

resource "aws_iam_role_policy" "device_identity" {
  for_each = var.device_recovery_deployment == null ? toset([]) : toset(["recovery", "registration"])
  name     = "device-identity-fences"
  role     = each.key == "recovery" ? aws_iam_role.device_recovery[0].id : aws_iam_role.device_registration.id
  policy   = data.aws_iam_policy_document.device_identity[0].json
}

data "aws_iam_policy_document" "device_recovery_control" {
  count = var.device_recovery_deployment != null && local.recovery_storage_valid ? 1 : 0
  statement {
    sid       = "RecoveryReceiptsAuditAndRateState"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [local.recovery_storage.table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
  }
}

resource "aws_iam_role_policy" "device_recovery_control" {
  count  = var.device_recovery_deployment != null && local.recovery_storage_valid ? 1 : 0
  name   = "device-recovery-control"
  role   = aws_iam_role.device_recovery[0].id
  policy = data.aws_iam_policy_document.device_recovery_control[0].json
}

resource "aws_apigatewayv2_route" "device_self_recovery" {
  count                = var.device_self_recovery_enabled ? 1 : 0
  api_id               = aws_apigatewayv2_api.age_attestation.id
  route_key            = "POST /v1/users/device-recovery"
  target               = "integrations/${aws_apigatewayv2_integration.device_recovery_lambda[0].id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito_jwt.id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}

resource "aws_lambda_permission" "device_self_recovery" {
  count         = var.device_self_recovery_enabled ? 1 : 0
  statement_id  = "AllowConsumerDeviceRecoveryRoute"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.device_recovery[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.age_attestation.execution_arn}/*/POST/v1/users/device-recovery"
}

output "device_self_recovery_contract" {
  value = {
    schema_version                   = 1
    environment                      = var.environment
    enabled                          = var.device_self_recovery_enabled
    route                            = var.device_self_recovery_enabled ? "POST /v1/users/device-recovery" : null
    identity                         = "Cognito access-token sub only; request body cannot select an account"
    reauthentication_max_age_seconds = 300
    previous_device_binding_required = false
  }
}
