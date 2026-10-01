mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  aws_region                  = "us-east-1"
  project_name                = "trustcheckradar"
  environment                 = "dev"
  state_bucket_name           = "synthetic-state"
  state_bucket_region         = "us-east-1"
  campaign_processing_enabled = true
  kill_switch_enabled         = true
  artifact_release            = "existing-release"
  log_retention_days          = 14
  account_privacy_artifacts = {
    release_id         = "1111111111111111111111111111111111111111"
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
    workers = {
      publisher = { object_version = "publisher-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      cluster   = { object_version = "cluster-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      deletion  = { object_version = "deletion-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      lifecycle = { object_version = "lifecycle-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
    }
  }
  campaign_recovery_preparation        = { review_reference = "synthetic-recovery" }
  campaign_completion_artifact         = { release_id = "1111111111111111111111111111111111111111", object_version = "deletion-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", review_reference = "synthetic-completion" }
  campaign_period_fence_preparation    = { review_reference = "synthetic-period" }
  campaign_account_cleanup_preparation = { review_reference = "synthetic-cleanup" }

}
override_data {
  target = data.terraform_remote_state.foundation
  values = {
    outputs = {
      downstream_contract = {
        schema_version             = 1
        artifact_bucket_name       = "artifact-example"
        deletion_ledger_stream_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/1"
        deletion_ledger_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
        deletion_ledger_table_name = "trustcheckradar-dev-deletion-ledger"
        users_table_arn            = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
        users_table_name           = "trustcheckradar-dev-users"
        campaign_recovery = {
          schema_version = 1
          enabled        = true
          environment    = "dev"
          table_name     = "trustcheckradar-dev-deletion-ledger"
          table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
          index_name     = "CampaignRecoveryDueIndex"
          index_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/index/CampaignRecoveryDueIndex"
          partition_key  = "campaignRecoveryPartition"
          sort_key       = "nextAttemptAtEpoch"
          projection     = "KEYS_ONLY"
          shard_count    = 16
        }

      }
    }
  }
}
override_data {
  target = data.terraform_remote_state.campaign_data[0]
  values = {
    outputs = {
      downstream_contract = {
        schema_version          = 1
        environment             = "dev"
        enabled                 = true
        outbox_table_name       = "trustcheckradar-dev-campaign-outbox"
        outbox_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"
        outbox_stream_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox/stream/1"
        pipeline_table_name     = "trustcheckradar-dev-campaign-pipeline"
        pipeline_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-pipeline"
        expiration_index_name   = "ExpirationIndex"
        intelligence_table_name = "trustcheckradar-dev-campaign-intelligence"
        intelligence_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-intelligence"
        cluster_queue_url       = "https://sqs.us-east-1.amazonaws.com/107827791950/campaign-cluster"
        cluster_queue_arn       = "arn:aws:sqs:us-east-1:107827791950:campaign-cluster"
        cluster_dlq_arn         = "arn:aws:sqs:us-east-1:107827791950:campaign-cluster-dlq"
        transient_kms_key_arn   = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
        persistent_kms_key_arn  = "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-2222-2222-222222222222"
        budget_alert_topic_arn  = "arn:aws:sns:us-east-1:107827791950:campaign-alerts"
      }
    }
  }
}


run "cleanup_grants_only_aggregate_read_and_exact_checks" {
  command = plan
  assert {
    condition     = length(aws_iam_role_policy.account_cleanup) == 2 && length(data.aws_iam_policy_document.account_cleanup["deletion"].statement) == 2 && length(data.aws_iam_policy_document.account_cleanup["lifecycle"].statement) == 1 && alltrue([for st in data.aws_iam_policy_document.account_cleanup["deletion"].statement : st.resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-intelligence"]) && alltrue([for a in st.actions : contains(["dynamodb:GetItem", "dynamodb:ConditionCheckItem"], a)])]) && one(data.aws_iam_policy_document.account_cleanup["lifecycle"].statement).actions == toset(["dynamodb:ConditionCheckItem"]) && one(data.aws_iam_policy_document.account_cleanup["lifecycle"].statement).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-pipeline"])
    error_message = "Cleanup preparation may not grant aggregate writes or scans."
  }
  assert {
    condition     = alltrue([for st in concat(tolist(data.aws_iam_policy_document.account_cleanup["deletion"].statement), tolist(data.aws_iam_policy_document.account_cleanup["lifecycle"].statement)) : !contains(st.actions, "dynamodb:ConditionCheckItem") || (alltrue([for c in st.condition : c.variable != "dynamodb:EnclosingOperation"]) && anytrue([for c in st.condition : c.variable == "dynamodb:ReturnValues" && c.test == "StringEqualsIfExists" && toset(c.values) == toset(["NONE"])]))]) && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_DELETION_STREAM_ENABLED == "false"
    error_message = "Transactional checks need supported NONE restrictions; preparation must keep deletion closed."
  }
}
run "null_has_no_cleanup_policy" {
  command = plan
  variables { campaign_account_cleanup_preparation = null }
  assert {
    condition     = length(aws_iam_role_policy.account_cleanup) == 0
    error_message = "Cleanup grants remain opt-in."
  }
}
run "reject_uncoordinated_source" {
  command = plan
  variables { campaign_period_fence_preparation = null }
  expect_failures = [var.campaign_account_cleanup_preparation]
}

run "decrypt_only_exact_campaign_keys_via_dynamodb" {
  command = plan
  assert {
    condition     = one(data.aws_iam_policy_document.account_cleanup_decryption[0].statement).actions == toset(["kms:Decrypt"]) && one(data.aws_iam_policy_document.account_cleanup_decryption[0].statement).resources == toset(["arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111", "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-2222-2222-222222222222"]) && length(one(data.aws_iam_policy_document.account_cleanup_decryption[0].statement).condition) == 2 && alltrue([for c in one(data.aws_iam_policy_document.account_cleanup_decryption[0].statement).condition : c.test == "StringEquals" && ((c.variable == "kms:CallerAccount" && toset(c.values) == toset(["107827791950"])) || (c.variable == "kms:ViaService" && toset(c.values) == toset(["dynamodb.us-east-1.amazonaws.com"])))])
    error_message = "Only exact campaign-key decrypt through same-account regional DynamoDB is allowed."
  }
}
