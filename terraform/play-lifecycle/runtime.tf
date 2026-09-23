locals {
  functions = var.enabled && var.deployment != null ? {
    ingress  = { suffix = "play-lifecycle-ingress", timeout = 29, concurrency = 2 }
    worker   = { suffix = "play-lifecycle-worker", timeout = 60, concurrency = 1 }
    deletion = { suffix = "play-token-deletion", timeout = 60, concurrency = 1 }
  } : {}
  prefix                = "${var.project_name}-${var.environment}"
  authority_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/${local.prefix}-purchase-entitlements"
  users_arn             = "arn:aws:dynamodb:us-east-1:107827791950:table/${local.prefix}-users"
  devices_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/${local.prefix}-device-bindings"
  deletion_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/${local.prefix}-deletion-ledger"
  transaction_condition = { "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } }
}
resource "aws_cloudwatch_log_group" "runtime" {
  for_each          = local.functions
  name              = "/aws/lambda/${local.prefix}-${each.value.suffix}"
  retention_in_days = 14
  tags              = var.tags
}
resource "aws_iam_role" "runtime" {
  for_each           = local.functions
  name               = "${local.prefix}-${each.value.suffix}-execution"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }] })
  tags               = var.tags
}
resource "aws_iam_role_policy" "runtime" {
  for_each = local.functions
  name     = "purpose-limited-lifecycle"
  role     = aws_iam_role.runtime[each.key].id
  policy = jsonencode({ Version = "2012-10-17", Statement = concat([
    { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.runtime[each.key].arn}:*" },
    { Sid = "ReadIdentityFences", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = [local.users_arn, local.devices_arn, local.deletion_arn] },
    { Sid = "TokenReads", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem", "dynamodb:Query"], Resource = local.table_arn,
    Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*", "PLAY_BINDING#*"] } } },
    { Sid = "TokenTransactions", Effect = "Allow", Action = each.key == "deletion" ? ["dynamodb:DeleteItem"] : ["dynamodb:PutItem", "dynamodb:DeleteItem"], Resource = local.table_arn,
    Condition = merge(local.transaction_condition, { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*", "PLAY_BINDING#*"] } }) },
    { Sid = "AuthorityObservations", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = local.authority_arn,
    Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*", "PURCHASE#CONTROL", "TOKEN#*", "USER#*"] } } },
    { Sid = "CurrentHmac", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.deployment.authority_hmac_secret_arn,
    Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } },
    { Sid = "NoOtherServicesOrCopies", Effect = "Deny", Action = ["lambda:InvokeFunction", "s3:*", "ssm:*", "sts:AssumeRole", "dynamodb:CreateBackup", "dynamodb:StartAwsBackupJob", "dynamodb:ExportTableToPointInTime", "dynamodb:RestoreTableToPointInTime", "dynamodb:UpdateContinuousBackups", "dynamodb:BatchWriteItem"], Resource = "*" }
    ], [for statement in [
      { Sid = "NoDecryptOrProvider", Effect = "Deny", Action = "kms:*", Resource = "*" },
      { Sid = "DeletionCommands", Effect = "Allow", Action = ["dynamodb:Scan"], Resource = local.deletion_arn },
      { Sid = "DeletionReceipts", Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = local.deletion_arn,
      Condition = merge(local.transaction_condition, { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["ACCOUNT#*"] }, "ForAllValues:StringEquals" = { "dynamodb:Attributes" = ["PK", "SK", "schemaVersion", "recordVersion", "environment", "eventType", "component", "status", "operationId", "requestOccurredAtEpoch", "occurredAtEpoch", "retainUntilEpoch"] } }) },
      { Sid = "TokenDeletionCheckpointRead", Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = local.deletion_arn,
      Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["PLAY#CONTROL"] } } },
      { Sid = "TokenDeletionCheckpointWrite", Effect = "Allow", Action = ["dynamodb:UpdateItem"], Resource = local.deletion_arn,
      Condition = merge(local.transaction_condition, { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["PLAY#CONTROL"], "dynamodb:Attributes" = ["PK", "SK", "revision", "cursor", "scanStartedAtEpoch", "lastFullPassAtEpoch"] } }) },
      { Sid = "RegionalStreamDiscovery", Effect = "Allow", Action = ["dynamodb:ListStreams"], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = "us-east-1" } } },
      { Sid = "ExactDeletionStream", Effect = "Allow", Action = ["dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:DescribeStream"], Resource = var.deployment.deletion_stream_arn }
      ] : statement if each.key == "deletion"], [for statement in [
      { Sid = "CurrentPlayCredential", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.deployment.google_play_secret_arn,
      Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } },
      { Sid = "TokenDataKey", Effect = "Allow", Action = ["kms:GenerateDataKey"], Resource = aws_kms_key.tokens[0].arn,
      Condition = { StringEquals = { "kms:EncryptionContext:purpose" = "google-play-reconciliation", "kms:EncryptionContext:environment" = "dev", "kms:DataKeySpec" = "AES_256" }, "ForAllValues:StringEquals" = { "kms:EncryptionContextKeys" = local.context_keys } } },
      { Sid = "TokenDecrypt", Effect = "Allow", Action = ["kms:Decrypt"], Resource = aws_kms_key.tokens[0].arn,
      Condition = { StringEquals = { "kms:EncryptionContext:purpose" = "google-play-reconciliation", "kms:EncryptionContext:environment" = "dev", "kms:EncryptionAlgorithm" = "SYMMETRIC_DEFAULT" }, "ForAllValues:StringEquals" = { "kms:EncryptionContextKeys" = local.context_keys } } },
      { Sid = "AuthorityAccountQueries", Effect = "Allow", Action = "dynamodb:Query", Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*"] } } },
      { Sid = "AuthorityTransactions", Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"], Resource = local.authority_arn,
      Condition = merge(local.transaction_condition, { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*#*", "TOKEN#*", "USER#*"] } }) }
      ] : statement if each.key != "deletion"], [for statement in [
      { Sid = "DueTokenKeys", Effect = "Allow", Action = "dynamodb:Query", Resource = "${local.table_arn}/index/GSI1",
      Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["V1_PLAY_RECONCILE"] } } }
      ] : statement if each.key == "worker"], [for statement in [
      { Sid = "LifecycleCheckpointRead", Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = local.table_arn,
      Condition = { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["PLAY#CONTROL"] } } },
      { Sid = "LifecycleCheckpointWrite", Effect = "Allow", Action = each.key == "worker" ? ["dynamodb:PutItem"] : ["dynamodb:DeleteItem"], Resource = local.table_arn,
      Condition = merge(local.transaction_condition, { "ForAllValues:StringEquals" = { "dynamodb:LeadingKeys" = ["PLAY#CONTROL"], "dynamodb:Attributes" = ["PK", "SK", "schemaVersion", "revision", "cursor", "expiresAt", "scanStartedAtEpoch", "lastFullPassAtEpoch"] } }) }
  ] : statement if contains(["worker", "deletion"], each.key)]) })
}
resource "aws_lambda_function" "runtime" {
  for_each                       = local.functions
  function_name                  = "${local.prefix}-${each.value.suffix}"
  role                           = aws_iam_role.runtime[each.key].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = "app.lambda_handler"
  timeout                        = each.value.timeout
  memory_size                    = 256
  reserved_concurrent_executions = each.value.concurrency
  s3_bucket                      = var.deployment.artifacts[each.key].bucket
  s3_key                         = var.deployment.artifacts[each.key].key
  s3_object_version              = var.deployment.artifacts[each.key].object_version
  source_code_hash               = var.deployment.artifacts[each.key].source_hash
  publish                        = true
  environment {
    variables = merge({
      STAGE                           = var.environment
      PLAY_LIFECYCLE_ENABLED          = "false"
      PLAY_TOKEN_CLEANUP_ENABLED      = "false"
      PLAY_CHECKPOINT_POLICY_APPROVED = "false"
      PLAY_PREPARATION_ENABLED        = "false"
      AUTHORITY_ENABLED               = "false"
      DEV_SUBJECT_ALLOWLIST_JSON      = "[]"
      PLAY_TOKEN_TABLE_NAME           = aws_dynamodb_table.tokens[0].name
      AUTHORITY_TABLE_NAME            = split("/", local.authority_arn)[1]
      PURCHASE_OWNERSHIP_TABLE_NAME   = split("/", local.authority_arn)[1]
      USERS_TABLE_NAME                = split("/", local.users_arn)[1]
      DEVICE_BINDINGS_TABLE_NAME      = split("/", local.devices_arn)[1]
      DELETION_LEDGER_TABLE_NAME      = split("/", local.deletion_arn)[1]
      AUTHORITY_HMAC_SECRET_ARN       = var.deployment.authority_hmac_secret_arn
      AUTHORITY_POLICY_VERSION        = "owner-2026-09-20-v1"
      COGNITO_ISSUER                  = var.deployment.cognito_issuer
      COGNITO_APP_CLIENT_ID           = var.deployment.cognito_app_client_id
      COGNITO_REQUIRED_SCOPE          = "aws.cognito.signin.user.admin"
      OPERATION_VALIDITY_SECONDS      = "300"
      WORKER_SETTLEMENT_SECONDS       = "60"
      RECONCILIATION_SECONDS          = "3600"
      RECEIPT_RETENTION_SECONDS       = "604800"
      COUNTER_RETENTION_SECONDS       = "604800"
      ATTEMPT_WINDOW_SECONDS          = "60"
      ATTEMPTS_PER_WINDOW             = "20"
      MAX_INFLIGHT                    = "2"
      }, each.key == "deletion" ? {
      DELETION_LEDGER_STREAM_ARN         = var.deployment.deletion_stream_arn
      DELETION_RECEIPT_RETENTION_SECONDS = "10368000"
      } : {
      PLAY_TOKEN_KMS_KEY_ARN                 = aws_kms_key.tokens[0].arn
      PLAY_TOKEN_READABLE_KMS_KEYS_JSON      = jsonencode([aws_kms_key.tokens[0].arn])
      PLAY_LIFECYCLE_WORKER_PRINCIPAL_ARN    = aws_iam_role.runtime[each.key].arn
      GOOGLE_PLAY_SERVICE_ACCOUNT_SECRET_ARN = var.deployment.google_play_secret_arn
      GOOGLE_PLAY_PACKAGE_NAME               = "com.andmorethings.trustcheckradar"
      GOOGLE_PLAY_PRODUCT_ID                 = "trustcheck_radar_pro_monthly"
      GOOGLE_PLAY_BASE_PLAN_ID               = "pro-monthly"
      GOOGLE_PLAY_BILLING_PERIOD             = "P1M"
      PLAY_CATALOG_P1M_VERIFIED              = "true"
      PLAY_REQUIRE_TEST_PURCHASES            = "true"
      }, each.key == "ingress" && var.pubsub_identity != null ? {
      PLAY_PUBSUB_AUDIENCE                = var.pubsub_identity.audience
      PLAY_PUBSUB_SUBSCRIPTION            = var.pubsub_identity.subscription
      PLAY_PUBSUB_SERVICE_ACCOUNT_EMAIL   = var.pubsub_identity.service_account_email
      PLAY_PUBSUB_SERVICE_ACCOUNT_SUBJECT = var.pubsub_identity.service_account_subject
    } : {})
  }
  depends_on = [aws_iam_role_policy.runtime, aws_dynamodb_resource_policy.tokens]
  tags       = var.tags
}
resource "aws_lambda_alias" "runtime" {
  for_each         = local.functions
  name             = "live"
  function_name    = aws_lambda_function.runtime[each.key].function_name
  function_version = aws_lambda_function.runtime[each.key].version
}
resource "aws_lambda_function_event_invoke_config" "runtime" {
  for_each                     = local.functions
  function_name                = aws_lambda_function.runtime[each.key].function_name
  qualifier                    = aws_lambda_alias.runtime[each.key].name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}
