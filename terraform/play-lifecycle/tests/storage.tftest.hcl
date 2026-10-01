mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_resource "aws_dynamodb_table" { defaults = { arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens" } }
}
variables { environment = "dev" }
run "default_empty" {
  command = plan
  assert {
    condition     = length(aws_dynamodb_table.tokens) == 0 && length(aws_kms_key.tokens) == 0 && !output.candidate_contract.provisioned
    error_message = "Defaults must not provision lifecycle infrastructure."
  }
}
run "no_copy_storage" {
  command = plan
  variables { enabled = true }
  assert {
    condition     = !aws_dynamodb_table.tokens[0].point_in_time_recovery[0].enabled && !aws_dynamodb_table.tokens[0].stream_enabled && aws_dynamodb_table.tokens[0].deletion_protection_enabled && aws_dynamodb_table.tokens[0].ttl[0].enabled && aws_dynamodb_table.tokens[0].ttl[0].attribute_name == "expiresAt"
    error_message = "Token storage must disable backup/streams and retain explicit deletion plus TTL backstop."
  }
  assert {
    condition     = alltrue([for i in aws_dynamodb_table.tokens[0].global_secondary_index : i.name == "GSI1" && i.projection_type == "KEYS_ONLY"])
    error_message = "Scheduling index must not copy ciphertext or identity metadata."
  }
  assert {
    condition     = alltrue([for a in ["dynamodb:CreateBackup", "dynamodb:UpdateContinuousBackups", "dynamodb:ExportTableToPointInTime", "dynamodb:RestoreTableToPointInTime", "dynamodb:EnableKinesisStreamingDestination"] : contains(jsondecode(aws_dynamodb_resource_policy.tokens[0].policy).Statement[0].Action, a)])
    error_message = "All supported copy APIs must be denied on the token table."
  }
  assert {
    condition     = toset(output.candidate_contract.application_context_keys) == toset(["purpose", "environment"]) && !strcontains(aws_kms_key.tokens[0].policy, "accountPartition") && !strcontains(aws_kms_key.tokens[0].policy, "tokenDigest")
    error_message = "CloudTrail-visible encryption context must not contain user or token identifiers."
  }
  assert {
    condition     = !output.candidate_contract.lifecycle_active && !output.candidate_contract.google_transport_provisioned && output.candidate_contract.account_backup_audit_required
    error_message = "Storage creation must not claim activation or complete backup inventory."
  }
}
run "backup_execution_role_boundary" {
  command = plan
  variables {
    enabled           = true
    backup_role_names = ["SyntheticBackupRole"]
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.no_token_backup["SyntheticBackupRole"].policy).Statement[0].Effect == "Deny" && contains(jsondecode(aws_iam_role_policy.no_token_backup["SyntheticBackupRole"].policy).Statement[0].Action, "dynamodb:StartAwsBackupJob") && jsondecode(aws_iam_role_policy.no_token_backup["SyntheticBackupRole"].policy).Statement[0].Resource == "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens"
    error_message = "Advanced Backup must be denied on actual role identities, scoped to the exact token table."
  }
}
run "reject_prod" {
  command = plan
  variables {
    enabled     = true
    environment = "prod"
  }
  expect_failures = [var.enabled]
}
run "reject_region" {
  command = plan
  variables {
    enabled    = true
    aws_region = "us-west-2"
  }
  expect_failures = [var.enabled]
}
run "reject_wildcard_role" {
  command = plan
  variables { backup_role_names = ["*"] }
  expect_failures = [var.backup_role_names]
}
