mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "107827791950"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "disabled_environment_is_empty" {
  command = plan

  variables {
    aws_region                    = "us-east-1"
    project_name                  = "trustcheckradar"
    environment                   = "dev"
    campaign_intelligence_enabled = false
    campaign_budget_limit_usd     = 25
    budget_notification_emails    = []
  }

  assert {
    condition     = length(aws_kms_key.transient) == 0 && length(aws_dynamodb_table.pipeline) == 0
    error_message = "A disabled environment must not create campaign data resources."
  }
}

run "enabled_dev_contract" {
  command = plan

  variables {
    aws_region                    = "us-east-1"
    project_name                  = "trustcheckradar"
    environment                   = "dev"
    campaign_intelligence_enabled = true
    campaign_budget_limit_usd     = 25
    budget_notification_emails    = ["owner@example.com"]
  }

  assert {
    condition     = length(aws_kms_key.transient) == 1 && length(aws_kms_key.persistent) == 1
    error_message = "An enabled environment must create exactly two long-lived campaign KMS keys."
  }

  assert {
    condition = (
      length(aws_dynamodb_table.outbox) == 1 &&
      length(aws_dynamodb_table.pipeline) == 1 &&
      length(aws_dynamodb_table.intelligence) == 1
    )
    error_message = "An enabled environment must create the outbox, transient pipeline, and persistent intelligence tables."
  }

  assert {
    condition = (
      aws_dynamodb_table.pipeline[0].point_in_time_recovery[0].enabled == false &&
      aws_dynamodb_table.intelligence[0].point_in_time_recovery[0].enabled == true
    )
    error_message = "Only persistent aggregate data may use DynamoDB point-in-time recovery."
  }

  assert {
    condition = contains(
      aws_dynamodb_table.pipeline[0].global_secondary_index[*].name,
      "ExpirationIndex",
    )
    error_message = "The transient pipeline requires a sparse expiration index for explicit lifecycle deletion."
  }

  assert {
    condition = (
      aws_sqs_queue.feature[0].message_retention_seconds == 345600 &&
      aws_sqs_queue.feature_dlq[0].message_retention_seconds == 1209600
    )
    error_message = "Feature queue retention or redrive does not match the V1 contract."
  }

  assert {
    condition     = aws_ecr_repository.model[0].image_tag_mutability == "IMMUTABLE"
    error_message = "The campaign model repository must reject mutable tags."
  }

  assert {
    condition     = aws_budgets_budget.campaign[0].limit_amount == "25"
    error_message = "The Dev campaign budget must be $25 per month."
  }
}

run "uat_requires_promotion" {
  command = plan

  variables {
    aws_region                    = "us-east-1"
    project_name                  = "trustcheckradar"
    environment                   = "uat"
    campaign_intelligence_enabled = true
    promotion_approved            = false
    campaign_budget_limit_usd     = 25
    budget_notification_emails    = ["owner@example.com"]
  }

  expect_failures = [check.environment_promotion_gate]
}

run "production_budget_is_fixed" {
  command = plan

  variables {
    aws_region                             = "us-east-1"
    project_name                           = "trustcheckradar"
    environment                            = "prod"
    campaign_intelligence_enabled          = true
    promotion_approved                     = true
    campaign_budget_limit_usd              = 51
    budget_notification_emails             = ["owner@example.com"]
    persistent_deletion_protection_enabled = true
  }

  expect_failures = [check.approved_budget]
}

run "throughput_overrides_are_bounded" {
  command = plan

  variables {
    aws_region                          = "us-east-1"
    project_name                        = "trustcheckradar"
    environment                         = "dev"
    campaign_intelligence_enabled       = false
    campaign_budget_limit_usd           = 25
    pipeline_max_write_request_units    = 51
    intelligence_max_read_request_units = 101
  }

  expect_failures = [check.throughput_bounds]
}
