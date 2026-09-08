mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "disabled_environment_creates_no_workers" {
  command = plan

  variables {
    aws_region                  = "us-east-1"
    project_name                = "trustcheckradar"
    environment                 = "dev"
    state_bucket_name           = "terraform-state-example"
    state_bucket_region         = "us-east-1"
    campaign_processing_enabled = false
    kill_switch_enabled         = true
    log_retention_days          = 14
  }

  override_data {
    target = data.terraform_remote_state.foundation
    values = {
      outputs = {
        downstream_contract = {
          schema_version             = 1
          artifact_bucket_name       = "artifact-example"
          deletion_ledger_stream_arn = null
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_lambda_function.worker) == 0 &&
      length(aws_scheduler_schedule.lifecycle) == 0
    )
    error_message = "A disabled campaign-processing environment must not create workers or schedules."
  }
}

run "enabled_dev_respects_kill_switch_and_runtime_bounds" {
  command = plan

  variables {
    aws_region                  = "us-east-1"
    project_name                = "trustcheckradar"
    environment                 = "dev"
    state_bucket_name           = "terraform-state-example"
    state_bucket_region         = "us-east-1"
    campaign_processing_enabled = true
    kill_switch_enabled         = true
    artifact_release            = "2026.09.06-1"
    log_retention_days          = 14
  }

  override_data {
    target = data.terraform_remote_state.foundation
    values = {
      outputs = {
        downstream_contract = {
          schema_version             = 1
          artifact_bucket_name       = "artifact-example"
          deletion_ledger_stream_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger/stream/1"
          deletion_ledger_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger"
          deletion_ledger_table_name = "deletion-ledger"
          users_table_arn            = "arn:aws:dynamodb:us-east-1:107827791950:table/users"
          users_table_name           = "users"
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
          outbox_table_name       = "campaign-outbox"
          outbox_stream_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-outbox/stream/1"
          pipeline_table_name     = "campaign-pipeline"
          pipeline_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-pipeline"
          expiration_index_name   = "ExpirationIndex"
          intelligence_table_name = "campaign-intelligence"
          intelligence_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-intelligence"
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

  assert {
    condition     = length(aws_lambda_function.worker) == 4
    error_message = "Enabled Dev must create the publisher, cluster, lifecycle, and deletion workers only."
  }

  assert {
    condition = (
      aws_lambda_event_source_mapping.publisher[0].enabled == false &&
      aws_lambda_event_source_mapping.cluster[0].enabled == false &&
      aws_lambda_event_source_mapping.deletion[0].enabled == false
    )
    error_message = "The kill switch must disable every event-source mapping."
  }

  assert {
    condition     = alltrue([for schedule in aws_scheduler_schedule.lifecycle : schedule.state == "DISABLED"])
    error_message = "The kill switch must disable every campaign lifecycle schedule."
  }

  assert {
    condition     = aws_lambda_function.worker["lifecycle"].environment[0].variables["EXPIRATION_INDEX_NAME"] == "ExpirationIndex"
    error_message = "The lifecycle worker must receive the explicit-expiration index contract."
  }

  assert {
    condition = (
      aws_lambda_function.worker["deletion"].environment[0].variables["USERS_TABLE_NAME"] == "users" &&
      aws_lambda_function.worker["deletion"].environment[0].variables["DELETION_LEDGER_TABLE_NAME"] == "deletion-ledger" &&
      aws_lambda_function.worker["deletion"].environment[0].variables["PARTICIPATION_ITEM_SK"] == "CAMPAIGN_PARTICIPATION"
    )
    error_message = "The deletion bridge must be able to complete participation status and its ledger command."
  }
}

run "active_dev_enables_every_event_source_and_schedule" {
  command = plan

  variables {
    aws_region                  = "us-east-1"
    project_name                = "trustcheckradar"
    environment                 = "dev"
    state_bucket_name           = "terraform-state-example"
    state_bucket_region         = "us-east-1"
    campaign_processing_enabled = true
    kill_switch_enabled         = false
    activation_approved         = true
    artifact_release            = "2026.09.08-1"
    log_retention_days          = 14
  }

  override_data {
    target = data.terraform_remote_state.foundation
    values = {
      outputs = {
        downstream_contract = {
          schema_version             = 1
          artifact_bucket_name       = "artifact-example"
          deletion_ledger_stream_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger/stream/1"
          deletion_ledger_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger"
          deletion_ledger_table_name = "deletion-ledger"
          users_table_arn            = "arn:aws:dynamodb:us-east-1:107827791950:table/users"
          users_table_name           = "users"
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
          outbox_table_name       = "campaign-outbox"
          outbox_stream_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-outbox/stream/1"
          pipeline_table_name     = "campaign-pipeline"
          pipeline_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-pipeline"
          expiration_index_name   = "ExpirationIndex"
          intelligence_table_name = "campaign-intelligence"
          intelligence_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-intelligence"
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

  assert {
    condition = (
      aws_lambda_event_source_mapping.publisher[0].enabled == true &&
      aws_lambda_event_source_mapping.cluster[0].enabled == true &&
      aws_lambda_event_source_mapping.deletion[0].enabled == true
    )
    error_message = "Active Dev must enable every campaign event-source mapping."
  }

  assert {
    condition     = alltrue([for schedule in aws_scheduler_schedule.lifecycle : schedule.state == "ENABLED"])
    error_message = "Active Dev must enable every campaign lifecycle schedule."
  }
}

run "kill_switch_release_requires_explicit_approval" {
  command = plan

  variables {
    aws_region                  = "us-east-1"
    project_name                = "trustcheckradar"
    environment                 = "dev"
    state_bucket_name           = "terraform-state-example"
    state_bucket_region         = "us-east-1"
    campaign_processing_enabled = false
    kill_switch_enabled         = false
    activation_approved         = false
    log_retention_days          = 14
  }

  override_data {
    target = data.terraform_remote_state.foundation
    values = {
      outputs = {
        downstream_contract = {
          schema_version             = 1
          artifact_bucket_name       = "artifact-example"
          deletion_ledger_stream_arn = null
        }
      }
    }
  }

  expect_failures = [check.kill_switch_release_gate]
}
