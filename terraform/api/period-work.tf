variable "campaign_period_work_preparation" {
  description = "Prepare closed analysis/account-data period-work integration; does not qualify inventories or enable campaign collection."
  type        = object({ review_reference = string })
  default     = null
  validation {
    condition = var.campaign_period_work_preparation == null ? true : try(
      var.environment == "dev" && length(trimspace(var.campaign_period_work_preparation.review_reference)) > 0 &&
      var.campaign_intelligence_enabled && var.account_data_deployment != null && local.research_migration_selected &&
      local.campaign.environment == var.environment && local.campaign.enabled &&
      local.campaign.pipeline_table_name == "${local.name_prefix}-campaign-pipeline" &&
      local.campaign.pipeline_table_arn == "arn:aws:dynamodb:${var.aws_region}:${split(":", local.users_table_arn)[4]}:table/${local.name_prefix}-campaign-pipeline" &&
      local.account_data_outbox_storage_valid,
      false
    )
    error_message = "Period-work preparation requires exact same-environment Dev campaign resources and immutable research/account-data candidate selections."
  }
}
locals {
  period_work_prepared = var.campaign_period_work_preparation != null
  period_work_closed_env = local.period_work_prepared ? {
    CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_NAME = local.campaign.pipeline_table_name
    CAMPAIGN_PERIOD_WORK_OUTBOX_TABLE_NAME   = local.campaign.outbox_table_name
    CAMPAIGN_PERIOD_WORK_ENABLED             = "false"
    CAMPAIGN_PERIOD_WORK_MANIFEST_SHA256     = ""
    CAMPAIGN_PERIOD_WORK_INVENTORY_REVISION  = "0"
    CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_ID   = ""
    CAMPAIGN_PERIOD_WORK_OUTBOX_TABLE_ID     = ""
    CAMPAIGN_PERIOD_ADMISSION_ENABLED        = "false"
    CAMPAIGN_PERIOD_ADMISSION_GENERATION     = ""
    CAMPAIGN_PERIOD_ADMISSION_ACCOUNT_ID     = split(":", local.users_table_arn)[4]
  } : {}
}
data "aws_iam_policy_document" "period_work" {
  for_each = local.period_work_prepared ? toset(["analysis", "account_data"]) : toset([])
  statement {
    sid       = "VerifyPeriodWorkResourceIdentity"
    actions   = ["dynamodb:DescribeTable"]
    resources = [local.campaign.pipeline_table_arn, local.campaign.outbox_table_arn]
  }
  statement {
    sid       = "ReadPeriodWorkAndControls"
    actions   = ["dynamodb:GetItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["PERIOD_WORK#*", "PERIOD_WORK_CONTROL#*", "WORK_LOOKUP#*", "PERIOD#*", "INVENTORY#${var.environment}", "PERIOD_RETIRED_PREFIX#${var.environment}"]
    }
  }
  statement {
    sid       = "MutatePairedWorkRecordsTransactionally"
    actions   = ["dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["PERIOD_WORK#*", "WORK_LOOKUP#*"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
  statement {
    sid       = "AdvanceExistingWorkControlTransactionally"
    actions   = ["dynamodb:UpdateItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["PERIOD_WORK_CONTROL#*"]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values   = ["TransactWriteItems"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
  statement {
    sid       = "CheckPeriodWorkApproval"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["INVENTORY#${var.environment}", "PERIOD_RETIRED_PREFIX#${var.environment}"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
  statement {
    sid       = "CheckExactPeriodWorkRecords"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["PERIOD_WORK#*", "PERIOD_WORK_CONTROL#*", "WORK_LOOKUP#*", "PERIOD#*"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
  statement {
    sid       = "UsePeriodWorkEncryptionThroughDynamoDB"
    actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
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
  }
}
resource "aws_iam_policy" "period_work" {
  for_each = data.aws_iam_policy_document.period_work
  name     = "${local.name_prefix}-${replace(each.key, "_", "-")}-period-work"
  policy   = each.value.json
  tags     = local.common_tags
}
resource "aws_iam_role_policy_attachment" "period_work" {
  for_each   = data.aws_iam_policy_document.period_work
  role       = each.key == "analysis" ? aws_iam_role.analysis.id : aws_iam_role.account_data[0].id
  policy_arn = aws_iam_policy.period_work[each.key].arn
}
output "campaign_period_work_preparation_contract" {
  value = {
    prepared                          = local.period_work_prepared
    work_enabled                      = local.period_work_active
    admission_enabled                 = local.period_work_active
    legacy_analysis_admission_enabled = false
    coverage_qualified                = false
  }
}

# Export validates the same v2 locator resource binding without gaining writer access.
data "aws_iam_policy_document" "period_work_export" {
  count = local.period_work_prepared && var.account_export_deployment != null ? 1 : 0
  statement {
    sid       = "VerifyPeriodWorkExportResourceIdentity"
    actions   = ["dynamodb:DescribeTable"]
    resources = [local.campaign.pipeline_table_arn, local.campaign.outbox_table_arn]
  }
  statement {
    sid       = "ReadPeriodWorkExportApproval"
    actions   = ["dynamodb:GetItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values   = ["INVENTORY#${var.environment}"]
    }
  }
}
resource "aws_iam_policy" "period_work_export" {
  count  = length(data.aws_iam_policy_document.period_work_export)
  name   = "${local.name_prefix}-account-export-period-work"
  policy = data.aws_iam_policy_document.period_work_export[0].json
  tags   = local.common_tags
}
resource "aws_iam_role_policy_attachment" "period_work_export" {
  count      = length(data.aws_iam_policy_document.period_work_export)
  role       = aws_iam_role.account_export[0].id
  policy_arn = aws_iam_policy.period_work_export[0].arn
}

variable "campaign_period_work_quiescence" {
  description = "Reviewed Dev migration window: stop involved invocations and close work/deletion gates while preserving activation configuration for restoration."
  type        = bool
  default     = false
  validation {
    condition     = !var.campaign_period_work_quiescence || (var.environment == "dev" && local.period_work_prepared)
    error_message = "Work migration quiescence requires the prepared Dev configuration."
  }
}
