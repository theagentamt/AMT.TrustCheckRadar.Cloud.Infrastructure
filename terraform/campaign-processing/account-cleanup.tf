variable "campaign_account_cleanup_preparation" {
  description = "Prepare account-specific publication repair permissions for coordinated Dev workers; does not enable deletion, publication or inventory approval."
  type        = object({ review_reference = string })
  default     = null
  validation {
    condition = var.campaign_account_cleanup_preparation == null ? true : try(
      var.environment == "dev" && local.period_fence_prepared && var.kill_switch_enabled &&
      length(trimspace(var.campaign_account_cleanup_preparation.review_reference)) > 0,
      false
    )
    error_message = "Account cleanup preparation requires coordinated closed Dev period-admission workers and an explicit source review."
  }
}

data "aws_iam_policy_document" "account_cleanup" {
  for_each = var.campaign_account_cleanup_preparation == null ? toset([]) : toset(["deletion", "lifecycle"])
  dynamic "statement" {
    for_each = each.key == "deletion" ? [1] : []
    content {
      sid       = "ReadDeletionPublicationAggregate"
      actions   = ["dynamodb:GetItem"]
      resources = [local.campaign.intelligence_table_arn]
      condition {
        test     = "ForAllValues:StringLike"
        variable = "dynamodb:LeadingKeys"
        values   = ["CAMPAIGN#*"]
      }
    }
  }
  statement {
    sid       = each.key == "deletion" ? "CheckDeletionPublicationAggregate" : "CheckPublicationContributorTombstones"
    actions   = ["dynamodb:ConditionCheckItem"]
    resources = [each.key == "deletion" ? local.campaign.intelligence_table_arn : local.campaign.pipeline_table_arn]
    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = each.key == "deletion" ? ["CAMPAIGN#*"] : ["CONTRIB#*"]
    }
    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE"]
    }
  }
}

resource "aws_iam_role_policy" "account_cleanup" {
  for_each = var.campaign_account_cleanup_preparation == null ? toset([]) : toset(["deletion", "lifecycle"])
  name     = "campaign-account-cleanup"
  role     = aws_iam_role.worker[each.key].id
  policy   = data.aws_iam_policy_document.account_cleanup[each.key].json
}

# DynamoDB decrypts the table key on behalf of the runtime caller. Restrict this
# separately from period-HMAC usage and do not grant key-management operations.
data "aws_iam_policy_document" "account_cleanup_decryption" {
  count = var.campaign_account_cleanup_preparation == null ? 0 : 1
  statement {
    sid       = "DecryptCampaignTablesThroughDynamoDB"
    actions   = ["kms:Decrypt"]
    resources = [local.campaign.transient_kms_key_arn, local.campaign.persistent_kms_key_arn]
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${var.aws_region}.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy" "account_cleanup_decryption" {
  count  = var.campaign_account_cleanup_preparation == null ? 0 : 1
  name   = "campaign-account-cleanup-decryption"
  role   = aws_iam_role.worker["deletion"].id
  policy = data.aws_iam_policy_document.account_cleanup_decryption[0].json
}
