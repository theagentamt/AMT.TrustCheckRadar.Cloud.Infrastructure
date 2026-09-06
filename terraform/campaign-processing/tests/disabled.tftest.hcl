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
      length(aws_lambda_function.feature) == 0 &&
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
    feature_image_digest        = "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    model_version               = "test-model-v1"
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
          feature_queue_url       = "https://sqs.us-east-1.amazonaws.com/107827791950/campaign-feature"
          feature_queue_arn       = "arn:aws:sqs:us-east-1:107827791950:campaign-feature"
          feature_dlq_arn         = "arn:aws:sqs:us-east-1:107827791950:campaign-feature-dlq"
          cluster_queue_url       = "https://sqs.us-east-1.amazonaws.com/107827791950/campaign-cluster"
          cluster_queue_arn       = "arn:aws:sqs:us-east-1:107827791950:campaign-cluster"
          cluster_dlq_arn         = "arn:aws:sqs:us-east-1:107827791950:campaign-cluster-dlq"
          transient_kms_key_arn   = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
          persistent_kms_key_arn  = "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-2222-2222-222222222222"
          model_repository_url    = "107827791950.dkr.ecr.us-east-1.amazonaws.com/campaign-model"
          budget_alert_topic_arn  = "arn:aws:sns:us-east-1:107827791950:campaign-alerts"
        }
      }
    }
  }

  assert {
    condition     = length(aws_lambda_function.worker) == 4 && length(aws_lambda_function.feature) == 1
    error_message = "Enabled Dev must create all five campaign workers."
  }

  assert {
    condition = (
      aws_lambda_event_source_mapping.publisher[0].enabled == false &&
      aws_lambda_event_source_mapping.feature[0].enabled == false &&
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
    condition     = aws_lambda_function.feature[0].memory_size <= 3072 && aws_lambda_function.feature[0].package_type == "Image"
    error_message = "The multilingual feature worker must stay within the approved Lambda runtime and packaging bounds."
  }

  assert {
    condition     = aws_lambda_function.worker["lifecycle"].environment[0].variables["EXPIRATION_INDEX_NAME"] == "ExpirationIndex"
    error_message = "The lifecycle worker must receive the explicit-expiration index contract."
  }
}
