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
      values   = ["repo:${var.github_organization}/${var.github_repository}:environment:${each.key}"]
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
