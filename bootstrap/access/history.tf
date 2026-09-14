data "aws_iam_policy_document" "history_lifecycle_deploy" {
  for_each = var.environments

  statement {
    sid    = "ManageHistoryLifecycleRule"
    effect = "Allow"
    actions = [
      "events:DescribeRule",
      "events:ListTagsForResource",
      "events:ListTargetsByRule",
      "events:PutRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:DeleteRule",
      "events:EnableRule",
      "events:DisableRule",
      "events:TagResource",
      "events:UntagResource",
    ]
    resources = [
      "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${var.project_name}-${each.key}-history-lifecycle-sweep"
    ]
  }
}

resource "aws_iam_role_policy" "history_lifecycle_deploy" {
  for_each = var.environments

  name   = "manage-history-lifecycle-rule"
  role   = aws_iam_role.github_deploy[each.key].name
  policy = data.aws_iam_policy_document.history_lifecycle_deploy[each.key].json
}
