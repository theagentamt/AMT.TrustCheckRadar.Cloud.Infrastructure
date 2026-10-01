# Optional closed integration; qualification/activation remains a separate change.
variable "lifecycle_storage" {
  type    = object({ table_arn = string, kms_key_arn = string })
  default = null
  validation {
    condition = var.lifecycle_storage == null ? true : (
      var.enabled && var.environment == "dev" &&
      var.lifecycle_storage.table_arn == "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens" &&
      can(regex("^arn:aws:kms:us-east-1:107827791950:key/[a-f0-9-]{36}$", var.lifecycle_storage.kms_key_arn))
    )
    error_message = "Use only the reviewed Dev token store and exact application encryption key."
  }
}
resource "aws_iam_role_policy" "lifecycle" {
  count = var.enabled && var.lifecycle_storage != null ? 1 : 0
  name  = "prepare-binding-and-retain-verified-token"
  role  = aws_iam_role.runtime[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "ReadBindingAndTokenFences", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = var.lifecycle_storage.table_arn,
    Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*", "PLAY_BINDING#*"] } } },
    { Sid = "AtomicBindingAndVerifiedToken", Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = var.lifecycle_storage.table_arn,
    Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*", "PLAY_BINDING#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
    { Sid = "NewTokenEnvelopeKeyOnly", Effect = "Allow", Action = ["kms:GenerateDataKey"], Resource = var.lifecycle_storage.kms_key_arn,
    Condition = { StringEquals = { "kms:EncryptionContext:purpose" = "google-play-reconciliation", "kms:EncryptionContext:environment" = "dev", "kms:EncryptionAlgorithm" = "SYMMETRIC_DEFAULT" }, "ForAllValues:StringEquals" = { "kms:EncryptionContextKeys" = ["purpose", "environment"] } } },
    { Sid = "NoTokenDecryption", Effect = "Deny", Action = ["kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*"], Resource = var.lifecycle_storage.kms_key_arn },
    { Sid = "NoTokenCopies", Effect = "Deny", Action = ["dynamodb:CreateBackup", "dynamodb:StartAwsBackupJob", "dynamodb:ExportTableToPointInTime", "dynamodb:UpdateContinuousBackups"], Resource = "*" }
  ] })
}
resource "aws_apigatewayv2_route" "prepare" {
  count                = local.route_enabled && var.lifecycle_storage != null ? 1 : 0
  api_id               = var.api_gateway.api_id
  route_key            = "POST /v1/purchases/google-play/prepare"
  target               = "integrations/${aws_apigatewayv2_integration.play[0].id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.play[0].id
  authorization_scopes = ["aws.cognito.signin.user.admin"]
}
resource "aws_lambda_permission" "prepare" {
  count          = local.route_enabled && var.lifecycle_storage != null ? 1 : 0
  statement_id   = "AllowAuthenticatedPlayPreparation"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.runtime[0].function_name
  qualifier      = aws_lambda_alias.runtime[0].name
  principal      = "apigateway.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = "${var.api_gateway.execution_arn}/${var.api_gateway.stage_name}/POST/v1/purchases/google-play/prepare"
}
