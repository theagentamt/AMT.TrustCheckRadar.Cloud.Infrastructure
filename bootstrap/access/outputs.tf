output "github_deploy_role_arns" {
  description = "Set each value as AWS_ROLE_ARN in its matching GitHub environment"
  value       = { for environment, role in aws_iam_role.github_deploy : environment => role.arn }
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = local.github_oidc_provider_arn
}
