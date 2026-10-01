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

run "recovery_default_is_absent" {
  command = plan
  assert {
    condition = (length(aws_scheduler_schedule.recovery) == 0 && length(aws_iam_role_policy.recovery_runtime) == 0 &&
    length(aws_cloudwatch_metric_alarm.recovery) == 0 && !output.campaign_recovery_preparation_contract.prepared)
    error_message = "An index contract alone must not prepare or enable recovery."
  }
}
run "prepared_recovery_stays_closed_and_content_free" {
  command = plan
  variables { campaign_recovery_preparation = { review_reference = "synthetic-reviewed-candidate" } }
  assert {
    condition = (aws_scheduler_schedule.recovery[0].state == "DISABLED" &&
      jsondecode(aws_scheduler_schedule.recovery[0].target[0].input) == { schemaVersion = 1, operation = "reconcile-campaign-cleanup" } &&
      aws_scheduler_schedule.recovery[0].target[0].retry_policy[0].maximum_event_age_in_seconds == 300 &&
      aws_scheduler_schedule.recovery[0].target[0].retry_policy[0].maximum_retry_attempts == 0 &&
      aws_lambda_function_event_invoke_config.recovery[0].maximum_event_age_in_seconds == 60 &&
    aws_lambda_function_event_invoke_config.recovery[0].maximum_retry_attempts == 0)
    error_message = "Candidate scheduler must stay disabled with only static input and bounded transport retries."
  }
  assert {
    condition = (aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_RECOVERY_ENABLED == "false" &&
      aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_RECOVERY_INVENTORY_REVISION == "0" &&
      aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_RECOVERY_MANIFEST_SHA256 == "" &&
      length(aws_cloudwatch_metric_alarm.recovery) == 8 &&
      aws_cloudwatch_metric_alarm.recovery["budget"].metric_name == "RecoveryBudgetExhausted" &&
      aws_cloudwatch_metric_alarm.recovery["truncated"].metric_name == "RecoveryShardTruncated" &&
    alltrue([for a in aws_cloudwatch_metric_alarm.recovery : !a.actions_enabled && toset(keys(a.dimensions)) == toset(["Environment"]) && a.dimensions.Environment == "dev"]))
    error_message = "Preparation must not enable recovery, approve inventory or send false alerts."
  }
  assert {
    condition = (one([for st in data.aws_iam_policy_document.recovery_runtime[0].statement : st if st.sid == "DiscoverDueCampaignRecoveryKeys"]).actions == toset(["dynamodb:Query"]) &&
      one([for st in data.aws_iam_policy_document.recovery_runtime[0].statement : st if st.sid == "DiscoverDueCampaignRecoveryKeys"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/index/CampaignRecoveryDueIndex"]) &&
      length(local.recovery_shards) == 16 && alltrue([for shard in range(16) : contains(local.recovery_shards, "CAMPAIGN_RECOVERY#dev#${format("%02d", shard)}")]) &&
    !anytrue([for st in data.aws_iam_policy_document.recovery_runtime[0].statement : contains(st.actions, "dynamodb:Scan") || contains(st.actions, "dynamodb:PutItem") || contains(st.actions, "dynamodb:DeleteItem")]))
    error_message = "Runtime recovery must query only the due index, without Scan, new receipt creation or deletion authority."
  }
  assert {
    condition = alltrue([for st in data.aws_iam_policy_document.recovery_runtime[0].statement : !contains(st.actions, "dynamodb:UpdateItem") ||
    anytrue([for c in st.condition : c.variable == "dynamodb:EnclosingOperation" && c.test == "ForAnyValue:StringEquals" && toset(c.values) == toset(["TransactWriteItems"])])])
    error_message = "Retry updates must remain transaction-only."
  }
}
run "reject_foreign_index" {
  command = plan
  variables { campaign_recovery_preparation = { review_reference = "synthetic" } }
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
            index_arn      = "arn:aws:dynamodb:us-east-1:000000000000:table/trustcheckradar-dev-deletion-ledger/index/CampaignRecoveryDueIndex"
            partition_key  = "campaignRecoveryPartition"
            sort_key       = "nextAttemptAtEpoch"
            projection     = "KEYS_ONLY"
            shard_count    = 16
          }

        }
      }
    }
  }

  expect_failures = [var.campaign_recovery_preparation]
}
run "reject_full_projection" {
  command = plan
  variables { campaign_recovery_preparation = { review_reference = "synthetic" } }
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
            projection     = "ALL"
            shard_count    = 16
          }

        }
      }
    }
  }

  expect_failures = [var.campaign_recovery_preparation]
}
