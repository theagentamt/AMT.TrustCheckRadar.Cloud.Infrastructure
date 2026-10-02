data "aws_iam_policy_document" "v1_authority_maintenance_deploy" {
  for_each = var.environments

  statement {
    sid    = "ManageV1AuthorityMaintenanceRules"
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
      "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${var.project_name}-${each.key}-url-lease-recovery",
      "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${var.project_name}-${each.key}-v1-authority-deletion",
    ]
  }
}

resource "aws_iam_role_policy" "v1_authority_maintenance_deploy" {
  for_each = var.environments

  name   = "manage-v1-authority-maintenance"
  role   = aws_iam_role.github_deploy[each.key].name
  policy = data.aws_iam_policy_document.v1_authority_maintenance_deploy[each.key].json
}
