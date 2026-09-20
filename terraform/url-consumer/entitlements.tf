# Account access and explicit trial activation have no provider invocation grant.
resource "aws_iam_role_policy" "entitlements" {
  count = var.enabled ? 1 : 0
  name  = "fenced-access-and-explicit-trial"
  role  = aws_iam_role.runtime["entitlements"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "OwnLogs", Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.runtime["entitlements"].arn}:*" },
      { Sid = "ReadIdentityFences", Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], Resource = local.identity_arns },
      { Sid = "ReadAuthority", Effect = "Allow", Action = ["dynamodb:GetItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*"] } } },
      { Sid = "AtomicAuthorityMutations", Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:ConditionCheckItem"], Resource = local.authority_arn,
      Condition = { "ForAllValues:StringLike" = { "dynamodb:LeadingKeys" = ["V1#*"] }, "ForAnyValue:StringEquals" = { "dynamodb:EnclosingOperation" = ["TransactWriteItems"] } } },
      { Sid = "OneHmacKeyRing", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = aws_secretsmanager_secret.authority_hmac[0].arn,
      Condition = { StringEquals = { "secretsmanager:VersionStage" = "AWSCURRENT" } } },
      { Sid = "NoProviderOrRoleChaining", Effect = "Deny", Action = ["lambda:InvokeFunction", "s3:*", "ssm:*", "sts:AssumeRole"], Resource = "*" }
    ]
  })
}
