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

run "period_admission_default_absent" {
  command = plan
  assert {
    condition = length(aws_iam_role_policy.period_admission) == 0 && !output.campaign_period_admission_preparation_contract.prepared
    error_message = "Period admission must not be prepared implicitly."
  }
}
run "period_admission_closed_coordinated_workers" {
  command = plan
  variables {

    campaign_recovery_preparation = { review_reference = "synthetic-recovery" }
    account_privacy_artifacts = {
      release_id = "1111111111111111111111111111111111111111"
      approval_reference = "synthetic-privacy"
      promotion_approved = false
      workers = {
        publisher = { object_version = "publisher-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        cluster = { object_version = "cluster-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        deletion = { object_version = "deletion-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        lifecycle = { object_version = "lifecycle-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      }
    }
    campaign_completion_artifact = {
      release_id = "1111111111111111111111111111111111111111"
      object_version = "deletion-version"
      source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      review_reference = "synthetic-completion"
    }
    campaign_period_fence_preparation = { review_reference = "synthetic-period-admission" }
  }
  assert {
    condition = alltrue([for worker in ["publisher", "cluster", "deletion", "lifecycle"] :
      aws_lambda_function.worker[worker].environment[0].variables.CAMPAIGN_PERIOD_ADMISSION_ENABLED == "false" &&
      aws_lambda_function.worker[worker].environment[0].variables.CAMPAIGN_PERIOD_ADMISSION_GENERATION == "" &&
      aws_lambda_function.worker[worker].environment[0].variables.CAMPAIGN_PERIOD_ADMISSION_ACCOUNT_ID == "107827791950" &&
      startswith(aws_lambda_function.worker[worker].s3_key, "releases/1111111111111111111111111111111111111111/")
    ])
    error_message = "All four selected workers must have closed admission and one reviewed source."
  }
  assert {
    condition = toset(keys(aws_iam_role_policy.period_admission)) == toset(["publisher", "cluster", "lifecycle"]) && alltrue([for p in data.aws_iam_policy_document.period_admission : contains([for s in p.statement : s.sid], "CheckExactPeriodAdmission")])
    error_message = "Only the three missing PERIOD check grants may be added."
  }
  assert {
    condition = !contains(one([for s in data.aws_iam_policy_document.lifecycle_runtime[0].statement : one([for c in s.condition : c.values if c.variable == "dynamodb:LeadingKeys"]) if s.sid == "WriteMutableLifecyclePipeline"]), "PERIOD#*")
    error_message = "The broad lifecycle write grant must no longer include PERIOD keys."
  }
  assert {
    condition = toset(one([for s in data.aws_iam_policy_document.period_admission["lifecycle"].statement : s.actions if s.sid == "ClosePeriodAdmissionTransaction"])) == toset(["dynamodb:UpdateItem"])
    error_message = "Closure grants UpdateItem only; PutItem and DeleteItem are excluded."
  }
  assert {
    condition = alltrue([for s in aws_scheduler_schedule.lifecycle : s.state == "DISABLED"]) && !output.campaign_period_admission_preparation_contract.retirement_enabled && !output.campaign_period_admission_preparation_contract.closure_approved
    error_message = "Preparation cannot activate closure, retirement or lifecycle scheduling."
  }
}
run "period_admission_rejects_mixed_source" {
  command = plan
  variables {

    campaign_recovery_preparation = { review_reference = "synthetic-recovery" }
    account_privacy_artifacts = {
      release_id = "2222222222222222222222222222222222222222"
      approval_reference = "synthetic-privacy"
      promotion_approved = false
      workers = {
        publisher = { object_version = "publisher-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        cluster = { object_version = "cluster-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        deletion = { object_version = "deletion-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        lifecycle = { object_version = "lifecycle-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      }
    }
    campaign_completion_artifact = {
      release_id = "1111111111111111111111111111111111111111"
      object_version = "deletion-version"
      source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      review_reference = "synthetic-completion"
    }
    campaign_period_fence_preparation = { review_reference = "synthetic-period-admission" }
  }
  expect_failures = [var.campaign_period_fence_preparation]
}
run "period_admission_rejects_missing_completion" {
  command = plan
  variables {
    campaign_period_fence_preparation = { review_reference = "synthetic-period-admission" }
  }
  expect_failures = [var.campaign_period_fence_preparation]
}
