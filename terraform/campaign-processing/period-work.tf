variable "campaign_period_work_preparation" {
  description = "Prepare authoritative period-work permissions and disabled reconciliation. Does not create approval markers, seed work controls, or enable any writer."
  type        = object({ review_reference = string })
  default     = null
  validation {
    condition = var.campaign_period_work_preparation == null ? true : try(
      var.environment == "dev" && local.period_fence_prepared && local.account_privacy_candidate &&
      var.kill_switch_enabled && length(trimspace(var.campaign_period_work_preparation.review_reference)) > 0 &&
      local.campaign.outbox_table_name == "${var.project_name}-${var.environment}-campaign-outbox" &&
      local.campaign.outbox_table_arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-${var.environment}-campaign-outbox" &&
      local.campaign.pipeline_table_name == "${var.project_name}-${var.environment}-campaign-pipeline" &&
      local.campaign.pipeline_table_arn == "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-${var.environment}-campaign-pipeline",
      false
    )
    error_message = "Period-work preparation requires a reviewed, closed, coordinated Dev period-admission candidate."
  }
}

locals {
  period_work_prepared = var.campaign_period_work_preparation != null
  period_work_closed_env = local.period_work_prepared ? {
    CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_NAME = local.campaign.pipeline_table_name
    CAMPAIGN_PERIOD_WORK_OUTBOX_TABLE_NAME   = local.campaign.outbox_table_name
    CAMPAIGN_AGGREGATE_TABLE_ID              = ""
    CAMPAIGN_PERIOD_WORK_ENABLED             = "false"
    CAMPAIGN_PERIOD_WORK_MANIFEST_SHA256     = ""
    CAMPAIGN_PERIOD_WORK_INVENTORY_REVISION  = "0"
    CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_ID   = ""
    CAMPAIGN_PERIOD_WORK_OUTBOX_TABLE_ID     = ""
  } : {}
}

# Work records deliberately do not share PERIOD# registry partitions. LeadingKeys
# cannot restrict sort keys, so ordinary paired deletion must not reach HMAC_KEY.
data "aws_iam_policy_document" "period_work" {
  for_each = local.period_work_prepared ? toset(["publisher", "cluster", "deletion", "lifecycle"]) : toset([])
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
      values   = ["PERIOD_WORK#*", "PERIOD_WORK_CONTROL#*", "WORK_LOOKUP#*", "INVENTORY#${var.environment}", "PERIOD_RETIRED_PREFIX#${var.environment}"]
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
      values   = concat(["PERIOD_WORK#*", "PERIOD_WORK_CONTROL#*", "WORK_LOOKUP#*"], each.key == "lifecycle" ? ["PERIOD_SWEEP#${var.environment}"] : [])
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
  dynamic "statement" {
    for_each = each.key == "lifecycle" ? [1] : []
    content {
      sid       = "ReadRegisteredOutboxTargets"
      actions   = ["dynamodb:GetItem"]
      resources = [local.campaign.outbox_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["ACCOUNT#*", "EVENT#*"]
      }
    }
  }
  dynamic "statement" {
    for_each = each.key == "lifecycle" ? [1] : []
    content {
      sid       = "EraseRegisteredOutboxTargetsTransactionally"
      actions   = ["dynamodb:DeleteItem"]
      resources = [local.campaign.outbox_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["ACCOUNT#*", "EVENT#*"]
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
  }
  dynamic "statement" {
    for_each = each.key == "lifecycle" ? [1] : []
    content {
      sid       = "PersistPeriodProgressTransactionally"
      actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
      resources = [local.campaign.pipeline_table_arn]
      condition {
        test     = "ForAllValues:StringEquals"
        variable = "dynamodb:LeadingKeys"
        values   = ["PERIOD_SWEEP#${var.environment}", "PERIOD_RETIRED_PREFIX#${var.environment}"]
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
  }
}

# A separate managed policy avoids the deletion role's aggregate inline limit.
resource "aws_iam_policy" "period_work" {
  for_each = data.aws_iam_policy_document.period_work
  name     = "${local.name_prefix}-${each.key}-period-work"
  policy   = each.value.json
  tags     = local.common_tags
}
resource "aws_iam_role_policy_attachment" "period_work" {
  for_each   = data.aws_iam_policy_document.period_work
  role       = aws_iam_role.worker[each.key].id
  policy_arn = aws_iam_policy.period_work[each.key].arn
}

# Existing lifecycle read grants already cover strong base-table WORK queries.
# No Scan, queue receive/redrive, runtime marker writer, or control bootstrap grant.
output "campaign_period_work_preparation_contract" {
  value = {
    prepared           = local.period_work_prepared
    work_enabled       = local.period_work_active
    lifecycle_enabled  = local.period_lifecycle_active
    retirement_enabled = local.period_retirement_active
    coverage_qualified = false
  }
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
