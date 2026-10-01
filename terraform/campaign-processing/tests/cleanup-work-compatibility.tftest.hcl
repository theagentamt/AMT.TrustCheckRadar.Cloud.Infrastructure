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


  campaign_recovery_preparation = { review_reference = "synthetic-recovery" }
  account_privacy_artifacts = {
    release_id         = "1111111111111111111111111111111111111111"
    approval_reference = "synthetic-privacy"
    promotion_approved = false
    workers = {
      publisher = { object_version = "publisher-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      cluster   = { object_version = "cluster-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      deletion  = { object_version = "deletion-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      lifecycle = { object_version = "lifecycle-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
    }
  }
  campaign_completion_artifact = {
    release_id       = "2222222222222222222222222222222222222222"
    object_version   = "patched-deletion-version"
    source_hash      = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    review_reference = "synthetic-completion"
  }
  campaign_period_fence_preparation = { review_reference = "synthetic-period-admission" }
  campaign_period_work_preparation  = { review_reference = "synthetic-work-preparation" }
  campaign_period_work_activation = {
    source_sha                 = "1111111111111111111111111111111111111111"
    generation                 = "11111111-1111-4111-8111-111111111111"
    manifest_sha256            = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    inventory_revision         = 1
    locator_manifest_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    locator_inventory_revision = 1
    intelligence_table_id      = "44444444-4444-4444-8444-444444444444"
    pipeline_table_id          = "22222222-2222-4222-8222-222222222222"
    outbox_table_id            = "33333333-3333-4333-8333-333333333333"
    inventory_reference        = "synthetic-inventory"
    runtime_reference          = "synthetic-runtime"
    iam_reference              = "synthetic-iam"
    lifecycle_enabled          = false
    retirement_enabled         = false
  }
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
  campaign_account_cleanup_preparation = { review_reference = "synthetic-cleanup" }
  campaign_cleanup_work_compatibility  = { work_source_sha = "1111111111111111111111111111111111111111", cleanup_source_sha = "2222222222222222222222222222222222222222", review_reference = "synthetic-review" }
}
run "exact_pair_preserves_producers_and_activates_cleanup" {
  command = plan
  assert {
    condition     = aws_lambda_function.worker["deletion"].s3_key == "releases/2222222222222222222222222222222222222222/campaign_deletion_bridge.zip" && aws_lambda_function.worker["deletion"].s3_object_version == "patched-deletion-version" && aws_lambda_function.worker["deletion"].source_code_hash == "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" && alltrue([for k in ["publisher", "cluster", "lifecycle"] : startswith(aws_lambda_function.worker[k].s3_key, "releases/1111111111111111111111111111111111111111/")]) && aws_lambda_event_source_mapping.deletion[0].enabled && aws_scheduler_schedule.recovery[0].state == "ENABLED" && !local.active
    error_message = "Only the bridge may select the reviewed patch; work producers and research gates remain unchanged."
  }
}
run "missing_pair_rejects_both_activations" {
  command = plan
  variables {
    campaign_cleanup_work_compatibility = null
  }
  expect_failures = [var.campaign_period_fence_preparation]

}
run "stale_work" {
  command = plan
  variables {
    campaign_cleanup_work_compatibility = { work_source_sha = "3333333333333333333333333333333333333333", cleanup_source_sha = "2222222222222222222222222222222222222222", review_reference = "synthetic-review" }
  }
  expect_failures = [var.campaign_cleanup_work_compatibility]

}
run "stale_cleanup" {
  command = plan
  variables {
    campaign_cleanup_work_compatibility = { work_source_sha = "1111111111111111111111111111111111111111", cleanup_source_sha = "3333333333333333333333333333333333333333", review_reference = "synthetic-review" }
  }
  expect_failures = [var.campaign_cleanup_work_compatibility]

}
run "empty_review" {
  command = plan
  variables {
    campaign_cleanup_work_compatibility = { work_source_sha = "1111111111111111111111111111111111111111", cleanup_source_sha = "2222222222222222222222222222222222222222", review_reference = "" }
  }
  expect_failures = [var.campaign_cleanup_work_compatibility]

}
run "missing_work_preparation" {
  command = plan
  variables {
    campaign_period_work_preparation = null
  }
  expect_failures = [var.campaign_period_work_activation]

}
run "quiescence_preserves_closed_runtime" {
  command = plan
  variables {
    campaign_period_work_quiescence = true
  }
  assert {
    condition     = aws_lambda_function.worker["deletion"].reserved_concurrent_executions == 0 && !aws_lambda_event_source_mapping.deletion[0].enabled && aws_scheduler_schedule.recovery[0].state == "DISABLED"
    error_message = "Patch compatibility cannot bypass quiescence."
  }
}

run "equal_source_pair_rejected" {
  command = plan
  variables {
    campaign_cleanup_work_compatibility = { work_source_sha = "1111111111111111111111111111111111111111", cleanup_source_sha = "1111111111111111111111111111111111111111", review_reference = "synthetic-review" }
  }
  expect_failures = [var.campaign_cleanup_work_compatibility]
}
run "non_dev_pair_rejected" {
  command = plan
  variables { environment = "uat" }
  expect_failures = [var.account_privacy_artifacts, check.upstream_contract_versions, check.environment_promotion_gate, check.log_retention_contract]
}
