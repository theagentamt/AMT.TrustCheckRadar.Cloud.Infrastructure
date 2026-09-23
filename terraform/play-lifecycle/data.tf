data "aws_caller_identity" "current" {}
locals {
  name         = "${var.project_name}-${var.environment}-play-tokens"
  table_arn    = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${local.name}"
  context_keys = ["purpose", "environment"]
}
resource "aws_kms_key" "tokens" {
  count                   = var.enabled ? 1 : 0
  description             = "Application encryption of purpose-limited Dev Google Play purchase tokens"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "EnableAccountIAM", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }, Action = "kms:*", Resource = "*" },
      { Sid = "DenyWrongPurpose", Effect = "Deny", Principal = "*", Action = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*"], Resource = "*",
      Condition = { StringNotEquals = { "kms:EncryptionContext:purpose" = "google-play-reconciliation" } } },
      { Sid = "DenyWrongEnvironment", Effect = "Deny", Principal = "*", Action = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*"], Resource = "*",
      Condition = { StringNotEquals = { "kms:EncryptionContext:environment" = "dev" } } },
      { Sid = "DenyUnusedCryptoPaths", Effect = "Deny", Principal = "*", Action = ["kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKeyWithoutPlaintext"], Resource = "*" },
      { Sid = "DenyExtraContext", Effect = "Deny", Principal = "*", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = "*",
      Condition = { "ForAnyValue:StringNotEquals" = { "kms:EncryptionContextKeys" = ["purpose", "environment"] } } }
    ]
  })
  tags = merge(var.tags, { Purpose = "google-play-reconciliation", Backup = "excluded" })
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = data.aws_caller_identity.current.account_id == "107827791950"
      error_message = "Only the reviewed Dev AWS account can provision lifecycle resources."
    }
  }
}
resource "aws_dynamodb_table" "tokens" {
  count                       = var.enabled ? 1 : 0
  name                        = local.name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "PK"
  range_key                   = "SK"
  deletion_protection_enabled = true
  stream_enabled              = false
  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "GSI1PK"
    type = "S"
  }
  attribute {
    name = "GSI1SK"
    type = "S"
  }
  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "KEYS_ONLY"
  }
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
  point_in_time_recovery { enabled = false }
  # Table encryption uses DynamoDB's managed key; the distinct application key
  # requires token-specific context and must never be used as the table SSE key.
  server_side_encryption { enabled = true }
  tags = merge(var.tags, { Backup = "excluded", DataClass = "recoverable-purchase-token", Retention = "latest-verified-access-end-plus-7-days-or-account-deletion" })
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = data.aws_caller_identity.current.account_id == "107827791950"
      error_message = "Only the reviewed Dev AWS account can provision lifecycle resources."
    }
  }
}
resource "aws_dynamodb_resource_policy" "tokens" {
  count        = var.enabled ? 1 : 0
  resource_arn = aws_dynamodb_table.tokens[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "NoTokenCopies", Effect = "Deny", Principal = "*", Action = ["dynamodb:CreateBackup", "dynamodb:UpdateContinuousBackups", "dynamodb:RestoreTableToPointInTime", "dynamodb:ExportTableToPointInTime", "dynamodb:EnableKinesisStreamingDestination"], Resource = local.table_arn },
      { Sid = "NoCrossAccount", Effect = "Deny", Principal = "*", Action = "dynamodb:*", Resource = [local.table_arn, "${local.table_arn}/index/*"],
      Condition = { StringNotEquals = { "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id }, Bool = { "aws:PrincipalIsAWSService" = "false" } } }
    ]
  })
}
# StartAwsBackupJob is not a supported table-resource-policy action. Attach the
# explicit deny to actual backup execution roles; exclusions also require audit.
resource "aws_iam_role_policy" "no_token_backup" {
  for_each = var.enabled ? var.backup_role_names : toset([])
  name     = "${local.name}-no-backup"
  role     = each.value
  policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Deny", Action = ["dynamodb:StartAwsBackupJob", "dynamodb:CreateBackup", "dynamodb:ExportTableToPointInTime"], Resource = local.table_arn }] })
}
