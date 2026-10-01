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
    release_id         = "privacy-candidate"
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
    workers = {
      publisher = { object_version = "publisher-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      cluster   = { object_version = "cluster-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      deletion  = { object_version = "deletion-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      lifecycle = { object_version = "lifecycle-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
    }
  }
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

run "completion_default_absent" {
  command = plan
  assert {
    condition     = length(aws_iam_role_policy.completion_runtime) == 0 && !output.campaign_completion_preparation_contract.prepared
    error_message = "Completion must not be selected implicitly."
  }
}
run "completion_selects_only_deletion_and_keeps_gates_closed" {
  command = plan
  variables {
    campaign_recovery_preparation = { review_reference = "synthetic-recovery" }
    campaign_completion_artifact = {
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "reviewed-deletion-version"
      source_hash      = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
      review_reference = "synthetic-completion"
    }
  }
  assert {
    condition     = aws_lambda_function.worker["deletion"].s3_key == "releases/1111111111111111111111111111111111111111/campaign_deletion_bridge.zip" && aws_lambda_function.worker["deletion"].s3_object_version == "reviewed-deletion-version" && aws_lambda_function.worker["deletion"].source_code_hash == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" && aws_lambda_function.worker["deletion"].runtime == "python3.14"
    error_message = "Completion must select the exact deletion-only source/version/hash."
  }
  assert {
    condition     = alltrue([for worker in ["publisher", "cluster", "lifecycle"] : startswith(aws_lambda_function.worker[worker].s3_key, "releases/privacy-candidate/") && aws_lambda_function.worker[worker].s3_object_version == "${worker}-version"])
    error_message = "Completion selection must preserve other worker artifacts."
  }
  assert {
    condition     = aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_DELETION_STREAM_ENABLED == "false" && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_COMPLETION_ENABLED == "false" && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_COMPLETION_MANIFEST_SHA256 == "" && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_COMPLETION_INVENTORY_REVISION == "0" && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_RECOVERY_ENABLED == "false" && aws_scheduler_schedule.recovery[0].state == "DISABLED" && !local.active
    error_message = "Artifact selection must not activate any path or approve inventory."
  }
  assert {
    condition     = length(data.aws_iam_policy_document.completion_runtime[0].statement) == 4 && alltrue([for statement in data.aws_iam_policy_document.completion_runtime[0].statement : alltrue([for arn in statement.resources : contains(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users", "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"], arn)]) && !contains(statement.actions, "dynamodb:Scan") && !contains(statement.actions, "dynamodb:UpdateItem")])
    error_message = "Completion must add only the reviewed exact-table grants, without scans or duplicate update authority."
  }
  assert {
    condition     = alltrue([for statement in data.aws_iam_policy_document.completion_runtime[0].statement : !contains(statement.actions, "dynamodb:PutItem") || anytrue([for condition in statement.condition : condition.variable == "dynamodb:EnclosingOperation" && condition.test == "ForAnyValue:StringEquals" && toset(condition.values) == toset(["TransactWriteItems"])])])
    error_message = "Completion writes must remain transactional."
  }
}
run "completion_rejects_missing_recovery" {
  command = plan
  variables {
    campaign_completion_artifact = {
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "reviewed-version"
      source_hash      = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
      review_reference = "synthetic"
    }
  }
  expect_failures = [var.campaign_completion_artifact]
}
run "completion_rejects_mutable_artifact" {
  command = plan
  variables {
    campaign_recovery_preparation = { review_reference = "synthetic" }
    campaign_completion_artifact = {
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "null"
      source_hash      = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
      review_reference = "synthetic"
    }
  }
  expect_failures = [var.campaign_completion_artifact]
}
