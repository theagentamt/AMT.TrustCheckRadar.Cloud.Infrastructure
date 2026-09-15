data "aws_iam_policy_document" "account_data_deploy" {
  for_each = var.environments
  statement {
    sid    = "ManageAccountDeletionReconciliationRule"
    effect = "Allow"
    actions = [
      "events:DescribeRule", "events:ListTagsForResource", "events:ListTargetsByRule",
      "events:PutRule", "events:PutTargets", "events:RemoveTargets", "events:DeleteRule",
      "events:EnableRule", "events:DisableRule", "events:TagResource", "events:UntagResource",
    ]
    resources = ["arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${var.project_name}-${each.key}-account-deletion-reconcile"]
  }
}

resource "aws_iam_role_policy" "account_data_deploy" {
  for_each = var.environments
  name     = "manage-account-deletion-reconciliation"
  role     = aws_iam_role.github_deploy[each.key].name
  policy   = data.aws_iam_policy_document.account_data_deploy[each.key].json
}
