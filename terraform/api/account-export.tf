variable "account_export_deployment" {
  description = "Immutable disabled account-export candidate. No route or activation; complete inventory, identity mapping and end-to-end acceptance are required separately."
  type = object({
    release_id                = string
    object_version            = string
    source_hash               = string
    approval_reference        = string
    promotion_approved        = bool
    authority_hmac_secret_arn = string
  })
  default = null
  validation {
    condition = var.account_export_deployment == null ? true : try(
      can(regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", var.account_export_deployment.release_id)) &&
      length(trimspace(var.account_export_deployment.object_version)) > 0 && var.account_export_deployment.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.account_export_deployment.source_hash)) &&
      length(trimspace(var.account_export_deployment.approval_reference)) > 0 &&
      (var.environment == "dev" || var.account_export_deployment.promotion_approved) &&
      can(regex("^arn:aws:secretsmanager:${var.aws_region}:${split(":", local.users_table_arn)[4]}:secret:${var.project_name}/${var.environment}/v1-authority-hmac-[A-Za-z0-9]{6}$", var.account_export_deployment.authority_hmac_secret_arn)), false
    )
    error_message = "Account export requires immutable artifact pins, an approval reference, same-environment authority keyring, and separate UAT/Prod approval."
  }
}

locals {
  account_export_name = "${local.name_prefix}-account-export-api"
  # IAM limits the table and partition families; the handler additionally derives
  # the exact subject/namespace from authenticated identity and verified keyrings.
  account_export_read_tables = var.account_export_deployment == null ? {} : merge({
    Profile      = { arn = local.users_table_arn, keys = ["USER#*"] }
    Devices      = { arn = local.device_bindings_table_arn, keys = ["USER#*"] }
    Deletion     = { arn = local.deletion_ledger_table_arn, keys = ["ACCOUNT#*"] }
    Entitlements = { arn = local.purchase_entitlements_table_arn, keys = ["USER#*", "TOKEN#*", "V1#*"] }
    Analysis     = { arn = local.analysis_abuse_control_table_arn, keys = ["ANALYSIS#REQUEST#*", "ANALYSIS#CONSUMPTION#*"] }
    }, var.history_deployment == null ? {} : {
    HistoryContent = { arn = local.history_data.content_table_arn, keys = ["USER#*"] }
    HistoryControl = { arn = local.history_data.control_table_arn, keys = ["USER#*"] }
    }, local.recovery_storage_valid ? {
    Recovery = { arn = local.recovery_storage.table_arn, keys = ["USER#*"] }
    } : {}, var.campaign_intelligence_enabled ? {
    CampaignOutbox   = { arn = local.campaign.outbox_table_arn, keys = ["ACCOUNT#*", "EVENT#*"] }
    CampaignPipeline = { arn = local.campaign.pipeline_table_arn, keys = ["PERIOD#*", "EVENT#*", "CANDIDATE#*", "CONTRIB#*"] }
  } : {})
}

# Only the container is managed in Terraform. Populate a vetted random AES-256
# keyring outside Terraform at rollout; do not put secret values in plan/state.
resource "aws_secretsmanager_secret" "account_export_cursor" {
  count                   = var.account_export_deployment == null ? 0 : 1
  name                    = "${var.project_name}/${var.environment}/account-export-cursor"
  description             = "Account export authenticated-encryption cursor keyring; no exported payloads"
  recovery_window_in_days = 7
  tags                    = merge(local.common_tags, { DataClass = "account-export-cursor-key" })
}

resource "aws_cloudwatch_log_group" "account_export" {
  count             = var.account_export_deployment == null ? 0 : 1
  name              = "/aws/lambda/${local.account_export_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_iam_role" "account_export" {
  count              = var.account_export_deployment == null ? 0 : 1
  name               = "${local.account_export_name}-role"
  assume_role_policy = data.aws_iam_policy_document.age_attestation_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "account_export" {
  count = var.account_export_deployment == null ? 0 : 1
  dynamic "statement" {
    for_each = local.account_export_read_tables
    content {
      sid       = "ReadOwned${statement.key}"
      actions   = statement.key == "CampaignPipeline" ? ["dynamodb:GetItem"] : ["dynamodb:GetItem", "dynamodb:Query"]
      resources = [statement.value.arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = statement.value.keys
      }
    }
  }
  dynamic "statement" {
    for_each = var.campaign_intelligence_enabled ? [1] : []
    content {
      sid       = "FindOwnCampaignContributions"
      actions   = ["dynamodb:Query"]
      resources = ["${local.campaign.pipeline_table_arn}/index/ContributorPeriodIndex"]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["CONTRIB#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = var.campaign_intelligence_enabled ? [1] : []
    content {
      sid       = "DeriveOwnedCampaignPeriodTokens"
      actions   = ["kms:GenerateMac"]
      resources = ["arn:aws:kms:${var.aws_region}:${split(":", local.users_table_arn)[4]}:key/*"]
      dynamic "condition" {
        for_each = {
          "aws:ResourceTag/Project"     = var.project_name
          "aws:ResourceTag/Environment" = var.environment
          "aws:ResourceTag/Purpose"     = "campaign-contributor-token"
          "kms:MacAlgorithm"            = "HMAC_SHA_256"
        }
        content {
          test     = "StringEquals"
          variable = condition.key
          values   = [condition.value]
        }
      }
    }
  }
  dynamic "statement" {
    for_each = var.campaign_intelligence_enabled ? [1] : []
    content {
      sid       = "DecryptCampaignStorageThroughDynamoDB"
      actions   = ["kms:Decrypt"]
      resources = [local.campaign.transient_kms_key_arn]
      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [split(":", local.users_table_arn)[4]]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["dynamodb.${var.aws_region}.amazonaws.com"]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:EncryptionContext:aws:dynamodb:tableName"
        values   = [local.campaign.outbox_table_name, local.campaign.pipeline_table_name]
      }
    }
  }
  statement {
    sid       = "ReadPurchaseCoverageMarker"
    actions   = ["dynamodb:GetItem"]
    resources = [local.purchase_entitlements_table_arn]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["PURCHASE#CONTROL"]
    }
  }
  statement {
    sid       = "ReadCurrentOwnedIdentity"
    actions   = ["cognito-idp:AdminGetUser"]
    resources = [local.account_data_pool_arn]
  }
  statement {
    sid     = "ReadTwoExactKeyrings"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.account_export_deployment.authority_hmac_secret_arn,
      aws_secretsmanager_secret.account_export_cursor[0].arn,
    ]
    condition {
      test     = "StringEquals"
      variable = "secretsmanager:VersionStage"
      values   = ["AWSCURRENT"]
    }
  }
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.account_export[0].arn}:*"]
  }
  statement {
    sid       = "NoPayloadStorageOrRoleChaining"
    effect    = "Deny"
    actions   = ["s3:*", "ssm:*", "sts:AssumeRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "account_export" {
  count  = var.account_export_deployment == null ? 0 : 1
  name   = "authenticated-read-only-account-export"
  role   = aws_iam_role.account_export[0].id
  policy = data.aws_iam_policy_document.account_export[0].json
}

resource "aws_lambda_function" "account_export" {
  count                          = var.account_export_deployment == null ? 0 : 1
  function_name                  = local.account_export_name
  role                           = aws_iam_role.account_export[0].arn
  runtime                        = "python3.14"
  architectures                  = ["arm64"]
  handler                        = "app.lambda_handler"
  memory_size                    = 256
  timeout                        = 29
  reserved_concurrent_executions = 1
  s3_bucket                      = local.foundation.artifact_bucket_name
  s3_key                         = "releases/${var.account_export_deployment.release_id}/account_export_api.zip"
  s3_object_version              = var.account_export_deployment.object_version
  source_code_hash               = var.account_export_deployment.source_hash
  environment {
    variables = {
      STAGE                              = var.environment
      ACCOUNT_EXPORT_ENABLED             = "false"
      ACCOUNT_EXPORT_POLICY_VERSION      = "account-export-observed-v1"
      ACCOUNT_EXPORT_INVENTORY_STATUS    = "pending"
      ACCOUNT_EXPORT_CURSOR_SECRET_ARN   = aws_secretsmanager_secret.account_export_cursor[0].arn
      AUTHORITY_HMAC_SECRET_ARN          = var.account_export_deployment.authority_hmac_secret_arn
      USERS_TABLE_NAME                   = local.users_table_name
      DEVICE_BINDINGS_TABLE_NAME         = local.device_bindings_table_name
      DELETION_LEDGER_TABLE_NAME         = local.deletion_ledger_table_name
      AUTHORITY_TABLE_NAME               = local.purchase_entitlements_table_name
      ENTITLEMENTS_TABLE_NAME            = local.purchase_entitlements_table_name
      DEVICE_RECOVERY_CONTROL_TABLE_NAME = local.recovery_storage_valid ? local.recovery_storage.table_name : ""
      HISTORY_CONTENT_TABLE_NAME         = var.history_deployment == null ? "" : local.history_data.content_table_name
      HISTORY_CONTROL_TABLE_NAME         = var.history_deployment == null ? "" : local.history_data.control_table_name
      ANALYSIS_ABUSE_TABLE_NAME          = local.analysis_abuse_control_table_name
      CAMPAIGN_OUTBOX_TABLE_NAME         = var.campaign_intelligence_enabled ? local.campaign.outbox_table_name : ""
      CAMPAIGN_PIPELINE_TABLE_NAME       = var.campaign_intelligence_enabled ? local.campaign.pipeline_table_name : ""
      COGNITO_ISSUER                     = local.jwt_issuer
      COGNITO_APP_CLIENT_ID              = local.cognito_app_client_id
      COGNITO_REQUIRED_SCOPE             = "aws.cognito.signin.user.admin"
      COGNITO_USER_POOL_ID               = local.cognito_user_pool_id
      COGNITO_USERNAME_IS_SUB            = "false"
    }
  }
  lifecycle {
    precondition {
      condition = try(
        split(":", local.users_table_arn)[4] == data.aws_caller_identity.account_fence[0].account_id &&
        alltrue([for table in local.account_export_read_tables :
          startswith(table.arn, "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.account_fence[0].account_id}:table/${local.name_prefix}-")
        ]), false
      )
      error_message = "Export readers must use same-account, Region and environment storage."
    }
    precondition {
      condition = try(
        local.cognito_user_pool_id != "" && startswith(local.cognito_user_pool_id, "${var.aws_region}_") &&
        local.cognito_app_client_id != "", false
      )
      error_message = "Account export needs the environment Cognito pool/client; username mapping remains unapproved."
    }
    precondition {
      condition = !var.campaign_intelligence_enabled || try(
        local.campaign.enabled && local.campaign.schema_version == 1 && local.campaign.environment == var.environment &&
        local.campaign.outbox_table_arn == "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.name_prefix}-campaign-outbox" &&
        local.campaign.pipeline_table_arn == "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.name_prefix}-campaign-pipeline" &&
        can(regex("^arn:aws:kms:${var.aws_region}:${split(":", local.users_table_arn)[4]}:key/[0-9a-f-]{36}$", local.campaign.transient_kms_key_arn)), false
      )
      error_message = "Export campaign readers require matching storage and a same-account/Region transient encryption key."
    }
  }
  depends_on = [aws_iam_role_policy.account_export, aws_cloudwatch_log_group.account_export]
  tags       = local.common_tags
}

resource "aws_lambda_function_event_invoke_config" "account_export" {
  count                        = var.account_export_deployment == null ? 0 : 1
  function_name                = aws_lambda_function.account_export[0].function_name
  maximum_event_age_in_seconds = 60
  maximum_retry_attempts       = 0
}

output "account_export_candidate_contract" {
  value = {
    schema_version                = 1
    deployed                      = var.account_export_deployment != null
    enabled                       = false
    inventory_status              = "pending"
    full_account_export_available = false
    routes                        = []
    cursor_secret_arn             = try(aws_secretsmanager_secret.account_export_cursor[0].arn, null)
    payload_storage_created       = false
    observed_data_only            = true
    continuation_seconds          = 900
  }
}
