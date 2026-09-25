mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}
variables {
  project_name                    = "trustcheckradar"
  environment                     = "dev"
  aws_region                      = "us-east-1"
  backend_assume_role_principals  = ["lambda.amazonaws.com"]
  deletion_assume_role_principals = ["lambda.amazonaws.com"]
}
run "default_does_not_add_recovery_index" {
  command = plan
  assert {
    condition     = length(aws_dynamodb_table.deletion_ledger.global_secondary_index) == 0 && !output.campaign_recovery_contract.enabled
    error_message = "Default source must not introduce recovery storage or imply coverage."
  }
}
run "index_requires_campaign_contract" {
  command = plan
  variables { campaign_recovery_index_enabled = true }
  expect_failures = [var.campaign_recovery_index_enabled]
}
run "sparse_index_preserves_existing_ledger_and_closed_gates" {
  command = plan
  variables {
    campaign_recovery_index_enabled = true
    campaign_intelligence_enabled   = true
  }
  assert {
    condition = length([for index in aws_dynamodb_table.deletion_ledger.global_secondary_index : index if
      index.name == "CampaignRecoveryDueIndex" && index.hash_key == "campaignRecoveryPartition" &&
      index.range_key == "nextAttemptAtEpoch" && index.projection_type == "KEYS_ONLY" && try(length(index.non_key_attributes), 0) == 0
    ]) == 1
    error_message = "Recovery index must carry only index and primary keys, never command contents."
  }
  assert {
    condition = (aws_dynamodb_table.deletion_ledger.hash_key == "PK" && aws_dynamodb_table.deletion_ledger.range_key == "SK" &&
      aws_dynamodb_table.deletion_ledger.billing_mode == "PAY_PER_REQUEST" &&
      length([for a in aws_dynamodb_table.deletion_ledger.attribute : a if a.name == "nextAttemptAtEpoch" && a.type == "N"]) == 1 &&
    length([for a in aws_dynamodb_table.deletion_ledger.attribute : a if a.name == "campaignRecoveryPartition" && a.type == "S"]) == 1)
    error_message = "Existing ownership keys and billing mode must remain unchanged."
  }
  assert {
    condition = (output.campaign_recovery_contract.enabled && !output.campaign_recovery_contract.writes_enabled &&
    !output.campaign_recovery_contract.coverage_qualified && output.campaign_recovery_contract.shard_count == 16)
    error_message = "An index must not authorize producers or mark historical coverage complete."
  }
}
