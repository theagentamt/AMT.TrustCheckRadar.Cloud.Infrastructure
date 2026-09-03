output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_app_client_id" {
  description = "Cognito mobile app client ID"
  value       = aws_cognito_user_pool_client.mobile.id
}

output "cognito_hosted_ui_domain" {
  description = "Cognito hosted UI domain (if enabled)"
  value       = var.hosted_ui_enabled ? aws_cognito_user_pool_domain.hosted_ui[0].domain : null
}

output "users_table_name" {
  description = "Users table name"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "Users table ARN"
  value       = aws_dynamodb_table.users.arn
}

output "deletion_ledger_table_name" {
  description = "Deletion ledger table name"
  value       = aws_dynamodb_table.deletion_ledger.name
}

output "deletion_ledger_table_arn" {
  description = "Deletion ledger table ARN"
  value       = aws_dynamodb_table.deletion_ledger.arn
}

output "backend_service_role_arn" {
  description = "Backend service IAM role ARN"
  value       = aws_iam_role.backend_service.arn
}

output "deletion_workflow_role_arn" {
  description = "Deletion workflow IAM role ARN"
  value       = aws_iam_role.deletion_workflow.arn
}

output "artifact_bucket_name" {
  description = "Shared S3 artifact bucket name for workflow Lambda packages"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifact_bucket_arn" {
  description = "Shared S3 artifact bucket ARN"
  value       = aws_s3_bucket.artifacts.arn
}

output "analysis_abuse_control_table_name" {
  description = "Conversation analysis abuse-control table name"
  value       = aws_dynamodb_table.analysis_abuse_control.name
}

output "analysis_abuse_control_table_arn" {
  description = "Conversation analysis abuse-control table ARN"
  value       = aws_dynamodb_table.analysis_abuse_control.arn
}

output "device_bindings_table_name" {
  description = "Device bindings table name"
  value       = aws_dynamodb_table.device_bindings.name
}

output "device_bindings_table_arn" {
  description = "Device bindings table ARN"
  value       = aws_dynamodb_table.device_bindings.arn
}

output "purchase_entitlements_table_name" {
  description = "Purchase entitlements table name"
  value       = aws_dynamodb_table.purchase_entitlements.name
}

output "purchase_entitlements_table_arn" {
  description = "Purchase entitlements table ARN"
  value       = aws_dynamodb_table.purchase_entitlements.arn
}

output "web_risk_cache_table_name" {
  description = "Web-risk cache table name"
  value       = aws_dynamodb_table.web_risk_cache.name
}

output "web_risk_cache_table_arn" {
  description = "Web-risk cache table ARN"
  value       = aws_dynamodb_table.web_risk_cache.arn
}

output "downstream_contract" {
  description = "Versioned values consumed by downstream Terraform stacks"
  value = {
    schema_version                    = 1
    artifact_bucket_name              = aws_s3_bucket.artifacts.id
    cognito_user_pool_id              = aws_cognito_user_pool.main.id
    cognito_app_client_id             = aws_cognito_user_pool_client.mobile.id
    users_table_arn                   = aws_dynamodb_table.users.arn
    users_table_name                  = aws_dynamodb_table.users.name
    analysis_abuse_control_table_arn  = aws_dynamodb_table.analysis_abuse_control.arn
    analysis_abuse_control_table_name = aws_dynamodb_table.analysis_abuse_control.name
    purchase_entitlements_table_arn   = aws_dynamodb_table.purchase_entitlements.arn
    purchase_entitlements_table_name  = aws_dynamodb_table.purchase_entitlements.name
    device_bindings_table_arn         = aws_dynamodb_table.device_bindings.arn
    device_bindings_table_name        = aws_dynamodb_table.device_bindings.name
    web_risk_cache_table_arn          = aws_dynamodb_table.web_risk_cache.arn
    web_risk_cache_table_name         = aws_dynamodb_table.web_risk_cache.name
  }
}
