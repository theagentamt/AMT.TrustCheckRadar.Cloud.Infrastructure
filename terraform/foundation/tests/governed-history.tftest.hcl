mock_provider "aws" {
  mock_resource "aws_iam_policy" { defaults = { arn = "arn:aws:iam::107827791950:policy/synthetic-test" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
}
variables {
  project_name                    = "trustcheckradar"
  environment                     = "dev"
  aws_region                      = "us-east-1"
  backend_assume_role_principals  = ["lambda.amazonaws.com"]
  deletion_assume_role_principals = ["lambda.amazonaws.com"]
}
run "default_preserves_existing_authority_table" {
  command = plan
  assert {
    condition     = length(aws_dynamodb_table.purchase_entitlements.global_secondary_index) == 1 && aws_dynamodb_table.purchase_entitlements.ttl[0].enabled && aws_dynamodb_table.purchase_entitlements.point_in_time_recovery[0].enabled
    error_message = "History is opt-in and cannot alter the authority TTL or backups."
  }
}
run "sparse_index_contains_only_content_free_history_projection" {
  command = apply
  variables { governed_history_index_enabled = true }
  assert {
    condition     = length(aws_dynamodb_table.purchase_entitlements.global_secondary_index) == 2 && alltrue([for index in aws_dynamodb_table.purchase_entitlements.global_secondary_index : index.name != "GSI2" || (index.hash_key == "GSI2PK" && index.range_key == "GSI2SK" && index.projection_type == "INCLUDE" && index.non_key_attributes == toset(["recordType", "state", "governedHistory", "expiresAt"]))]) && aws_dynamodb_table.purchase_entitlements.ttl[0].attribute_name == "expiresAt"
    error_message = "GSI2 must project only typed result metadata and preserve the original receipt expiry."
  }
}
run "non_dev_index_is_rejected" {
  command = plan
  variables {
    environment                    = "uat"
    governed_history_index_enabled = true
  }
  expect_failures = [var.governed_history_index_enabled]
}
