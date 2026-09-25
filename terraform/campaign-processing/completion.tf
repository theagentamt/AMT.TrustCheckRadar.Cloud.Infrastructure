variable "campaign_completion_artifact" {
  description = "Immutable deletion-worker completion integration candidate; all runtime gates remain disabled."
  type = object({
    release_id       = string
    object_version   = string
    source_hash      = string
    review_reference = string
  })
  default = null
  validation {
    condition = var.campaign_completion_artifact == null ? true : try(
      local.account_privacy_candidate && local.recovery_prepared && var.kill_switch_enabled &&
      var.environment == "dev" &&
      can(regex("^[0-9a-f]{40}$", var.campaign_completion_artifact.release_id)) &&
      length(trimspace(var.campaign_completion_artifact.object_version)) > 0 &&
      var.campaign_completion_artifact.object_version != "null" &&
      can(regex("^[A-Za-z0-9+/]{43}=$", var.campaign_completion_artifact.source_hash)) &&
      length(trimspace(var.campaign_completion_artifact.review_reference)) > 0,
      false
    )
    error_message = "Completion candidate requires reviewed immutable pins, disabled Dev workers and prepared recovery; this is not activation."
  }
}

locals {
  completion_prepared = var.campaign_completion_artifact != null
}

data "aws_iam_policy_document" "completion_runtime" {
  count = local.completion_prepared ? 1 : 0
  statement {
    sid       = "QueryOwnedRecoveryJobs"
    actions   = ["dynamodb:Query"]
    resources = [local.foundation.deletion_ledger_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCOUNT#*"]
    }
  }
  dynamic "statement" {
    for_each = {
      CompleteOwnedCampaignLedger = { arn = local.foundation.deletion_ledger_table_arn, actions = ["dynamodb:PutItem", "dynamodb:DeleteItem"], keys = ["ACCOUNT#*"] }
      CompleteOwnedParticipation  = { arn = local.foundation.users_table_arn, actions = ["dynamodb:PutItem"], keys = ["USER#*"] }
    }
    content {
      sid       = statement.key
      actions   = statement.value.actions
      resources = [statement.value.arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = statement.value.keys
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
  statement {
    sid       = "CheckOwnedCompletionProfile"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [local.foundation.users_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["USER#*"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
}
resource "aws_iam_role_policy" "completion_runtime" {
  count  = local.completion_prepared ? 1 : 0
  name   = "campaign-completion-candidate"
  role   = aws_iam_role.worker["deletion"].id
  policy = data.aws_iam_policy_document.completion_runtime[0].json
}
output "campaign_completion_preparation_contract" {
  value = {
    prepared           = local.completion_prepared
    stream_enabled     = false
    recovery_enabled   = false
    completion_enabled = false
    inventory_approved = false
    selected_release   = try(var.campaign_completion_artifact.release_id, null)
  }
}
