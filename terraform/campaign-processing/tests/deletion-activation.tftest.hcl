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



run "null_preserves_closed_workers" {
  command = plan
  assert {
    condition     = !aws_lambda_event_source_mapping.deletion[0].enabled && aws_scheduler_schedule.recovery[0].state == "DISABLED" && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_COMPLETION_ENABLED == "false" && alltrue([for alarm in aws_cloudwatch_metric_alarm.recovery : !alarm.actions_enabled])
    error_message = "Default must preserve closed workers and alarms."
  }
}
run "only_deletion_can_run_with_research_paused" {
  command = plan
  variables { campaign_deletion_activation = {
    source_sha                    = "1111111111111111111111111111111111111111"
    generation                    = "11111111-1111-4111-8111-111111111111"
    locator_manifest_sha256       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    locator_inventory_revision    = 1
    recovery_manifest_sha256      = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    recovery_inventory_revision   = 1
    completion_manifest_sha256    = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    completion_inventory_revision = 1
    inventory_reference           = "synthetic-inventory-not-approval"
    runtime_reference             = "synthetic-runtime-not-approval"
    encryption_reference          = "synthetic-encryption-not-approval"
  } }
  assert {
    condition     = aws_lambda_event_source_mapping.deletion[0].enabled && aws_scheduler_schedule.recovery[0].state == "ENABLED" && alltrue([for alarm in aws_cloudwatch_metric_alarm.recovery : alarm.actions_enabled]) && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_COMPLETION_ENABLED == "true" && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_PERIOD_ADMISSION_GENERATION == "11111111-1111-4111-8111-111111111111" && aws_lambda_function.worker["deletion"].environment[0].variables.CAMPAIGN_RECOVERY_ENABLED == "true"
    error_message = "Deletion needs durable stream, recovery, completion and alarms."
  }
  assert {
    condition     = !local.active && alltrue([for key in ["publisher", "cluster", "lifecycle"] : aws_lambda_function.worker[key].environment[0].variables.CAMPAIGN_PERIOD_ADMISSION_ENABLED == "false"]) && alltrue([for schedule in aws_scheduler_schedule.lifecycle : schedule.state == "DISABLED"]) && !output.research_consent_migration_contract.consumers_paused && output.research_consent_migration_contract.research_producers_paused && output.research_consent_migration_contract.deletion_workers_enabled
    error_message = "Cleanup may not activate research or misreport all consumers paused."
  }
}

run "reject_bad_source" {
  command = plan
  variables { campaign_deletion_activation = {
    source_sha                    = "2222222222222222222222222222222222222222"
    generation                    = "11111111-1111-4111-8111-111111111111"
    locator_manifest_sha256       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    locator_inventory_revision    = 1
    recovery_manifest_sha256      = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    recovery_inventory_revision   = 1
    completion_manifest_sha256    = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    completion_inventory_revision = 1
    inventory_reference           = "synthetic-inventory-not-approval"
    runtime_reference             = "synthetic-runtime-not-approval"
    encryption_reference          = "synthetic-encryption-not-approval"
  } }
  expect_failures = [var.campaign_deletion_activation]
}

run "reject_bad_generation" {
  command = plan
  variables { campaign_deletion_activation = {
    source_sha                    = "1111111111111111111111111111111111111111"
    generation                    = "11111111-1111-1111-8111-111111111111"
    locator_manifest_sha256       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    locator_inventory_revision    = 1
    recovery_manifest_sha256      = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    recovery_inventory_revision   = 1
    completion_manifest_sha256    = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    completion_inventory_revision = 1
    inventory_reference           = "synthetic-inventory-not-approval"
    runtime_reference             = "synthetic-runtime-not-approval"
    encryption_reference          = "synthetic-encryption-not-approval"
  } }
  expect_failures = [var.campaign_deletion_activation]
}

run "reject_fractional_revision" {
  command = plan
  variables { campaign_deletion_activation = {
    source_sha                    = "1111111111111111111111111111111111111111"
    generation                    = "11111111-1111-4111-8111-111111111111"
    locator_manifest_sha256       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    locator_inventory_revision    = 1.5
    recovery_manifest_sha256      = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    recovery_inventory_revision   = 1
    completion_manifest_sha256    = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    completion_inventory_revision = 1
    inventory_reference           = "synthetic-inventory-not-approval"
    runtime_reference             = "synthetic-runtime-not-approval"
    encryption_reference          = "synthetic-encryption-not-approval"
  } }
  expect_failures = [var.campaign_deletion_activation]
}

run "reject_missing_evidence" {
  command = plan
  variables { campaign_deletion_activation = {
    source_sha                    = "1111111111111111111111111111111111111111"
    generation                    = "11111111-1111-4111-8111-111111111111"
    locator_manifest_sha256       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    locator_inventory_revision    = 1
    recovery_manifest_sha256      = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    recovery_inventory_revision   = 1
    completion_manifest_sha256    = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    completion_inventory_revision = 1
    inventory_reference           = "synthetic-inventory-not-approval"
    runtime_reference             = "synthetic-runtime-not-approval"
    encryption_reference          = ""
  } }
  expect_failures = [var.campaign_deletion_activation]
}

run "reject_without_cleanup_preparation" {
  command = plan
  variables {
    campaign_account_cleanup_preparation = null
    campaign_deletion_activation = {
      source_sha                    = "1111111111111111111111111111111111111111"
      generation                    = "11111111-1111-4111-8111-111111111111"
      locator_manifest_sha256       = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      locator_inventory_revision    = 1
      recovery_manifest_sha256      = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      recovery_inventory_revision   = 1
      completion_manifest_sha256    = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
      completion_inventory_revision = 1
      inventory_reference           = "synthetic-inventory-not-approval"
      runtime_reference             = "synthetic-runtime-not-approval"
      encryption_reference          = "synthetic-encryption-not-approval"
    }
  }
  expect_failures = [var.campaign_deletion_activation]
}

run "regional_stream_discovery_preserves_exact_record_reads" {
  command = plan
  assert {
    condition     = alltrue([for st in data.aws_iam_policy_document.deletion_runtime[0].statement : !contains(st.actions, "dynamodb:ListStreams") || (st.actions == toset(["dynamodb:ListStreams"]) && st.resources == toset(["*"]) && length(st.condition) == 1 && one(st.condition).test == "StringEquals" && one(st.condition).variable == "aws:RequestedRegion" && toset(one(st.condition).values) == toset(["us-east-1"]))]) && length([for st in data.aws_iam_policy_document.deletion_runtime[0].statement : st if contains(st.actions, "dynamodb:ListStreams")]) == 1
    error_message = "ListStreams must be regional resource-less discovery, never an unsupported stream-ARN grant."
  }
  assert {
    condition     = alltrue([for st in data.aws_iam_policy_document.deletion_runtime[0].statement : st.sid != "ReadDeletionLedgerStream" || (st.actions == toset(["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator"]) && st.resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/1"]))])
    error_message = "Actual record reads must remain limited to the exact deletion ledger stream."
  }
}
