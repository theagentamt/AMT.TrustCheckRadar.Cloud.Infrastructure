# The existing deployment role already handles Lambda/IAM/S3/logs. These reads
# let the code-only release workflow refresh the separate existing resolver state.
# No EC2 mutation or broader environment rollout is granted here.
resource "aws_iam_role_policy" "resolver_release_reads" {
  for_each = toset([for environment in var.environments : environment if environment == "dev"])
  name     = "read-existing-url-resolver"
  role     = aws_iam_role.github_deploy[each.key].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "InspectNetwork", Effect = "Allow", Resource = "*",
        Action = [
          "ec2:DescribeAvailabilityZones", "ec2:DescribeVpcs", "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets", "ec2:DescribeInternetGateways", "ec2:DescribeAddresses",
          "ec2:DescribeNatGateways", "ec2:DescribeRouteTables", "ec2:DescribeNetworkAcls",
          "ec2:DescribeSecurityGroups", "ec2:DescribeNetworkInterfaces", "ec2:DescribeTags",
        ],
        Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } }
      },
      {
        Sid      = "InspectResolverNotifications", Effect = "Allow",
        Action   = ["sns:GetTopicAttributes", "sns:GetSubscriptionAttributes", "sns:ListSubscriptionsByTopic", "sns:ListTagsForResource"],
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${each.key}-url-resolver-alerts"
      },
      {
        Sid      = "InspectResolverAlarms", Effect = "Allow",
        Action   = ["cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource"],
        Resource = "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${each.key}-url-resolver-*"
      },
    ]
  })
}
