locals {
  alert_actions = var.enabled ? distinct(concat([aws_sns_topic.operations[0].arn], var.alarm_action_arns)) : []
  resolver_alarm_arns = [for suffix in ["partial", "errors", "throttles"] :
    "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.name}-${suffix}"
  ]
  alarm_arns = concat(local.resolver_alarm_arns, var.assessment_alarm_notifications_enabled ? [
    for suffix in ["errors", "throttles", "dependency-failures"] :
    "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${var.environment}-url-assessment-${suffix}"
    ] : [], var.consumer_alarm_notifications_enabled ? concat(
    flatten([for function in ["url-consumer", "v1-entitlements", "url-lease-recovery", "v1-authority-deletion"] : [
      for suffix in ["errors", "throttles"] : "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${var.environment}-${function}-${suffix}"
    ]]),
    flatten([for function in ["url-lease-recovery", "v1-authority-deletion"] : [
      for suffix in ["failed-items", "heartbeat"] : "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${var.environment}-${function}-${suffix}"
    ]]),
    ["arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${var.environment}-url-lease-recovery-expiry-overdue"],
    [for suffix in ["overdue", "full-pass-age"] : "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${var.environment}-v1-authority-deletion-${suffix}"]
  ) : [])
}

resource "aws_sns_topic" "operations" {
  count = var.enabled ? 1 : 0
  name  = "${local.name}-alerts"
  tags  = local.tags
}

resource "aws_sns_topic_policy" "operations" {
  count = var.enabled ? 1 : 0
  arn   = aws_sns_topic.operations[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AccountAdministration", Effect = "Allow",
        Action = [
          "SNS:GetTopicAttributes", "SNS:SetTopicAttributes", "SNS:AddPermission",
          "SNS:RemovePermission", "SNS:DeleteTopic", "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic", "SNS:Publish",
        ],
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" },
        Resource  = aws_sns_topic.operations[0].arn
      },
      {
        Sid       = "OnlyApprovedSafetyAlarms", Effect = "Allow", Action = "sns:Publish",
        Principal = { Service = "cloudwatch.amazonaws.com" },
        Resource  = aws_sns_topic.operations[0].arn,
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id },
          ArnEquals    = { "aws:SourceArn" = local.alarm_arns }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.enabled && var.notification_email != null ? 1 : 0
  topic_arn = aws_sns_topic.operations[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Standalone acceptance role, not a grant to the analyzer. The calling SSO
# principal must already be able to assume it; this cannot grant broader access.
resource "aws_iam_role" "dev_test" {
  count                = var.enabled && var.dev_test_principal_arn != null ? 1 : 0
  name                 = "${local.name}-dev-test"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { AWS = var.dev_test_principal_arn } }]
  })
  lifecycle {
    precondition {
      condition     = try(split(":", var.dev_test_principal_arn)[4] == data.aws_caller_identity.current.account_id, false)
      error_message = "The Dev smoke principal must belong to the deployment account."
    }
  }
  tags = local.tags
}

resource "aws_iam_role_policy" "dev_test" {
  count = var.enabled && var.dev_test_principal_arn != null ? 1 : 0
  name  = "invoke-only-resolver-alias"
  role  = aws_iam_role.dev_test[0].id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_alias.resolver[0].arn }]
  })
}
