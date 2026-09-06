data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.existing_github_oidc_provider_arn == null ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_oidc_thumbprints

  tags = merge(var.tags, {
    ManagedBy = "terraform-bootstrap"
    Purpose   = "github-actions-oidc"
  })
}

locals {
  github_oidc_provider_arn = var.existing_github_oidc_provider_arn != null ? var.existing_github_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "github_assume_role" {
  for_each = var.environments

  statement {
    sid     = "GitHubEnvironment"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_organization}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}:environment:${each.key}"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:ref"
      values   = ["refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  for_each = var.environments

  name                 = "${var.project_name}-${each.key}-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role[each.key].json
  max_session_duration = 3600

  tags = merge(var.tags, {
    Environment = each.key
    ManagedBy   = "terraform-bootstrap"
    Purpose     = "github-actions-deployment"
  })
}

data "aws_iam_policy_document" "github_deploy" {
  for_each = var.environments

  statement {
    sid       = "ReadStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.state_key_prefix}/${each.key}/*"]
    }
  }

  statement {
    sid    = "ManageEnvironmentState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::${var.state_bucket_name}/${var.state_key_prefix}/${each.key}/*"]
  }

  statement {
    sid     = "ManageEnvironmentStateLocks"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}/${var.state_key_prefix}/${each.key}/*.tflock"
    ]
  }

  statement {
    sid    = "ManageApplicationServices"
    effect = "Allow"
    actions = [
      "acm:*",
      "apigateway:*",
      "cognito-idp:*",
      "dynamodb:*",
      "lambda:*",
      "logs:*",
      "route53:*",
      "secretsmanager:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CreateTaggedCampaignKeys"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = [each.key]
    }
  }

  statement {
    sid    = "ManageTaggedCampaignKeys"
    effect = "Allow"
    actions = [
      "kms:CancelKeyDeletion",
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:DisableKey",
      "kms:EnableKey",
      "kms:EnableKeyRotation",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:Encrypt",
      "kms:ListGrants",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:RetireGrant",
      "kms:RevokeGrant",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateKeyDescription",
    ]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [each.key]
    }
  }

  statement {
    sid    = "ManageCampaignKeyAliases"
    effect = "Allow"
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:UpdateAlias",
    ]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/${var.project_name}-${each.key}-campaign-*"]
  }

  statement {
    sid    = "UseTaggedCampaignKeysForAliases"
    effect = "Allow"
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:UpdateAlias",
    ]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [each.key]
    }
  }

  statement {
    sid    = "ReadKmsAliases"
    effect = "Allow"
    actions = [
      "kms:ListAliases",
      "kms:ListKeys",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageCampaignMessagingAndArtifacts"
    effect = "Allow"
    actions = [
      "ecr:BatchDeleteImage",
      "ecr:CreateRepository",
      "ecr:DeleteLifecyclePolicy",
      "ecr:DeleteRepository",
      "ecr:DeleteRepositoryPolicy",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
      "ecr:ListTagsForResource",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:PutLifecyclePolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
      "scheduler:CreateSchedule",
      "scheduler:CreateScheduleGroup",
      "scheduler:DeleteSchedule",
      "scheduler:DeleteScheduleGroup",
      "scheduler:GetSchedule",
      "scheduler:GetScheduleGroup",
      "scheduler:ListTagsForResource",
      "scheduler:TagResource",
      "scheduler:UntagResource",
      "scheduler:UpdateSchedule",
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:GetSubscriptionAttributes",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTagsForResource",
      "sns:SetSubscriptionAttributes",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:TagResource",
      "sns:Unsubscribe",
      "sns:UntagResource",
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListDeadLetterSourceQueues",
      "sqs:ListQueueTags",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:UntagQueue",
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-${each.key}-campaign-*",
      "arn:aws:scheduler:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schedule-group/${var.project_name}-${each.key}-campaign*",
      "arn:aws:scheduler:${var.aws_region}:${data.aws_caller_identity.current.account_id}:schedule/${var.project_name}-${each.key}-campaign*/*",
      "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${each.key}-campaign-*",
      "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${each.key}-campaign-*",
    ]
  }

  statement {
    sid       = "CampaignServiceDiscovery"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ManageCampaignObservability"
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
      "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.project_name}-${each.key}-campaign-*",
      "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/${var.project_name}-${each.key}-campaign-*",
    ]
  }

  statement {
    sid    = "ReadCampaignObservability"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:ListDashboards",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageCampaignBudgets"
    effect = "Allow"
    actions = [
      "budgets:ListTagsForResource",
      "budgets:ModifyBudget",
      "budgets:TagResource",
      "budgets:UntagResource",
      "budgets:ViewBudget",
    ]
    resources = ["arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/${var.project_name}-${each.key}-campaign-*"]
  }

  statement {
    sid    = "ManageEnvironmentArtifactBuckets"
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${each.key}-${data.aws_caller_identity.current.account_id}-artifacts",
      "arn:aws:s3:::${var.project_name}-${each.key}-${data.aws_caller_identity.current.account_id}-artifacts/*"
    ]
  }

  statement {
    sid    = "ManageEnvironmentIam"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:PutRolePolicy",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${each.key}-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.project_name}-${each.key}-*",
      "arn:aws:iam::aws:policy/*"
    ]
  }

  statement {
    sid     = "PassEnvironmentRoles"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-${each.key}-*"
    ]
  }

  statement {
    sid       = "ReadCallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_deploy" {
  for_each = var.environments

  name   = "${var.project_name}-${each.key}-github-deploy"
  policy = data.aws_iam_policy_document.github_deploy[each.key].json

  tags = merge(var.tags, {
    Environment = each.key
    ManagedBy   = "terraform-bootstrap"
  })
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  for_each = var.environments

  role       = aws_iam_role.github_deploy[each.key].name
  policy_arn = aws_iam_policy.github_deploy[each.key].arn
}

data "aws_iam_policy_document" "lambda_publish_assume_role" {
  for_each = var.environments

  statement {
    sid     = "GitHubLambdaEnvironment"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_organization}@${var.github_owner_id}/${var.lambda_repository}@${var.lambda_repository_id}:environment:${each.key}"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:ref"
      values   = ["refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "lambda_publisher" {
  for_each = var.environments

  name                 = "${var.project_name}-${each.key}-lambda-publisher"
  description          = "GitHub Actions publisher for TrustCheckRadar ${each.key} Lambda artifacts"
  assume_role_policy   = data.aws_iam_policy_document.lambda_publish_assume_role[each.key].json
  max_session_duration = 3600

  tags = merge(var.tags, {
    Environment = each.key
    ManagedBy   = "terraform-bootstrap"
    Project     = var.project_name
    Purpose     = "lambda-artifact-publishing"
  })
}

data "aws_iam_policy_document" "lambda_publish" {
  for_each = var.environments

  statement {
    sid    = "InspectArtifactBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = ["arn:aws:s3:::${var.project_name}-${each.key}-${data.aws_caller_identity.current.account_id}-artifacts"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["releases/*"]
    }
  }

  statement {
    sid    = "PublishImmutableLambdaArtifacts"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["arn:aws:s3:::${var.project_name}-${each.key}-${data.aws_caller_identity.current.account_id}-artifacts/releases/*"]
  }

  statement {
    sid       = "AuthenticateToEcr"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PublishCampaignFeatureImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = ["arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-${each.key}-campaign-model"]
  }

  statement {
    sid       = "ReadCallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_publish" {
  for_each = var.environments

  name   = "publish-${each.key}-lambda-artifacts"
  role   = aws_iam_role.lambda_publisher[each.key].name
  policy = data.aws_iam_policy_document.lambda_publish[each.key].json
}
