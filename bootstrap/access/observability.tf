data "aws_iam_policy_document" "environment_observability_deploy" {
  for_each = var.environments

  statement {
    sid    = "ManageEnvironmentObservability"
    effect = "Allow"
    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DeleteDashboards",
      "cloudwatch:GetDashboard",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:PutDashboard",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = [
      "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${each.key}-*",
      "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/${var.project_name}-${each.key}-*",
    ]
  }
}

resource "aws_iam_role_policy" "environment_observability_deploy" {
  for_each = var.environments

  name   = "manage-${each.key}-environment-observability"
  role   = aws_iam_role.github_deploy[each.key].name
  policy = data.aws_iam_policy_document.environment_observability_deploy[each.key].json
}
