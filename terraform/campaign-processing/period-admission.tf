variable "campaign_period_fence_preparation" {
  description = "Prepare coordinated period admission candidates with runtime admission and deletion gates closed."
  type        = object({ review_reference = string })
  default     = null
  validation {
    condition = var.campaign_period_fence_preparation == null ? true : try(
      var.environment == "dev" && var.kill_switch_enabled && local.account_privacy_candidate &&
      local.recovery_prepared && local.completion_prepared &&
      var.account_privacy_artifacts.release_id == var.campaign_completion_artifact.release_id &&
      var.account_privacy_artifacts.workers.deletion.object_version == var.campaign_completion_artifact.object_version &&
      var.account_privacy_artifacts.workers.deletion.source_hash == var.campaign_completion_artifact.source_hash &&
      length(trimspace(var.campaign_period_fence_preparation.review_reference)) > 0,
      false
    )
    error_message = "Period admission preparation requires coordinated immutable Dev worker pins, prepared completion/recovery and closed processing gates."
  }
}

locals {
  period_fence_prepared = var.campaign_period_fence_preparation != null
}

data "aws_iam_policy_document" "period_admission" {
  for_each = local.period_fence_prepared ? toset(["publisher", "cluster", "lifecycle"]) : toset([])
  statement {
    sid       = "CheckExactPeriodAdmission"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["PERIOD#*"]
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
      sid       = "ClosePeriodAdmissionTransaction"
      actions   = ["dynamodb:UpdateItem"]
      resources = [local.campaign.pipeline_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["PERIOD#*"]
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

resource "aws_iam_role_policy" "period_admission" {
  for_each = local.period_fence_prepared ? toset(["publisher", "cluster", "lifecycle"]) : toset([])
  name     = "campaign-period-admission"
  role     = aws_iam_role.worker[each.key].id
  policy   = data.aws_iam_policy_document.period_admission[each.key].json
}

output "campaign_period_admission_preparation_contract" {
  value = {
    prepared           = local.period_fence_prepared
    admission_enabled  = false
    generation         = ""
    closure_approved   = false
    retirement_enabled = false
  }
}
