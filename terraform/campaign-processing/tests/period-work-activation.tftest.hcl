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

run "work_compatibility_keeps_cleanup_schedule_closed" {
  command = plan
  variables {

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
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "deletion-version"
      source_hash      = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
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
  }

  assert {
    condition = (alltrue([for alarm in aws_cloudwatch_metric_alarm.aggregate_expiry : alarm.actions_enabled == false]) &&
      aws_lambda_function.worker["lifecycle"].environment[0].variables.CAMPAIGN_AGGREGATE_TABLE_ID == "44444444-4444-4444-8444-444444444444" &&
      one([for st in data.aws_iam_policy_document.aggregate_expiry[0].statement : st if st.sid == "DiscoverExpiredAnonymousAggregates"]).actions == toset(["dynamodb:Query"]) &&
    one([for st in data.aws_iam_policy_document.aggregate_expiry[0].statement : st if st.sid == "DiscoverExpiredAnonymousAggregates"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-intelligence/index/ExpirationIndex"]))
    error_message = "Compatibility alone cannot activate aggregate alarms; expiry discovery stays on the exact aggregate index."
  }
  assert {
    condition     = alltrue([for fn in aws_lambda_function.worker : fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "true"]) && aws_scheduler_schedule.period_lifecycle[0].state == "DISABLED" && aws_lambda_function.worker["lifecycle"].environment[0].variables.CAMPAIGN_PERIOD_RETIREMENT_ENABLED == "false"
    error_message = "Work-index compatibility alone must not schedule cleanup or permit retirement."
  }
}
run "lifecycle_can_run_without_key_retirement" {
  command = plan
  variables {

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
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "deletion-version"
      source_hash      = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
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
      lifecycle_enabled          = true
      retirement_enabled         = false
    }
  }

  assert {
    condition     = aws_scheduler_schedule.period_lifecycle[0].state == "ENABLED" && alltrue([for a in aws_cloudwatch_metric_alarm.period_lifecycle : a.actions_enabled]) && aws_lambda_function.worker["lifecycle"].environment[0].variables.CAMPAIGN_PERIOD_RETIREMENT_ENABLED == "false" && !aws_lambda_event_source_mapping.publisher[0].enabled && !aws_lambda_event_source_mapping.cluster[0].enabled && alltrue([for s in aws_scheduler_schedule.lifecycle : s.state == "DISABLED"])
    error_message = "New lifecycle scheduling must be independent of key retirement and keep research/legacy schedules closed."
  }
}
run "retirement_needs_lifecycle" {
  command = plan
  variables {

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
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "deletion-version"
      source_hash      = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
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
      retirement_enabled         = true
    }
  }
  expect_failures = [var.campaign_period_work_activation]
}
run "wrong_source_rejected" {
  command = plan
  variables {

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
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "deletion-version"
      source_hash      = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      review_reference = "synthetic-completion"
    }
    campaign_period_fence_preparation = { review_reference = "synthetic-period-admission" }
    campaign_period_work_preparation  = { review_reference = "synthetic-work-preparation" }
    campaign_period_work_activation = {
      source_sha                 = "4444444444444444444444444444444444444444"
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
  }
  expect_failures = [var.campaign_period_work_activation]
}
run "same_resource_identity_rejected" {
  command = plan
  variables {

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
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "deletion-version"
      source_hash      = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
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
      outbox_table_id            = "22222222-2222-4222-8222-222222222222"
      inventory_reference        = "synthetic-inventory"
      runtime_reference          = "synthetic-runtime"
      iam_reference              = "synthetic-iam"
      lifecycle_enabled          = false
      retirement_enabled         = false
    }
  }
  expect_failures = [var.campaign_period_work_activation]
}
run "missing_evidence_rejected" {
  command = plan
  variables {

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
      release_id       = "1111111111111111111111111111111111111111"
      object_version   = "deletion-version"
      source_hash      = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
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
      iam_reference              = ""
      lifecycle_enabled          = false
      retirement_enabled         = false
    }
  }
  expect_failures = [var.campaign_period_work_activation]
}
