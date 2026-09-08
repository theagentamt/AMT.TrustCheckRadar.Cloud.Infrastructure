mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "disabled_environment_creates_no_routes" {
  command = plan

  variables {
    aws_region                  = "us-east-1"
    project_name                = "trustcheckradar"
    environment                 = "dev"
    state_bucket_name           = "terraform-state-example"
    state_bucket_region         = "us-east-1"
    campaign_api_enabled        = false
    campaign_review_api_enabled = false
    log_retention_days          = 14
  }

  override_data {
    target = data.terraform_remote_state.foundation
    values = {
      outputs = {
        downstream_contract = {
          schema_version       = 1
          artifact_bucket_name = "artifact-example"
          cognito_user_pool_id = "us-east-1_example"
          users_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/users"
        }
      }
    }
  }

  override_data {
    target = data.terraform_remote_state.api
    values = {
      outputs = {
        campaign_route_contract = {
          schema_version                = 1
          environment                   = "dev"
          campaign_intelligence_enabled = false
          api_id                        = "api-example"
          execution_arn                 = "arn:aws:execute-api:us-east-1:107827791950:api-example"
          authorizer_id                 = "authorizer-example"
          stage_name                    = "$default"
        }
      }
    }
  }

  assert {
    condition = (
      length(aws_lambda_function.trends) == 0 &&
      length(aws_lambda_function.review) == 0 &&
      length(random_password.pagination_token) == 0 &&
      length(aws_apigatewayv2_route.trends) == 0 &&
      length(aws_apigatewayv2_route.review) == 0
    )
    error_message = "A disabled campaign API environment must not create functions or routes."
  }
}

run "enabled_dev_uses_existing_authenticated_api" {
  command = plan

  variables {
    aws_region                  = "us-east-1"
    project_name                = "trustcheckradar"
    environment                 = "dev"
    state_bucket_name           = "terraform-state-example"
    state_bucket_region         = "us-east-1"
    campaign_api_enabled        = true
    campaign_review_api_enabled = true
    artifact_release            = "2026.09.06-1"
    campaign_reviewer_username  = "reviewer@example.com"
    log_retention_days          = 14
  }

  override_data {
    target = data.terraform_remote_state.foundation
    values = {
      outputs = {
        downstream_contract = {
          schema_version       = 1
          artifact_bucket_name = "artifact-example"
          cognito_user_pool_id = "us-east-1_example"
          users_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/users"
        }
      }
    }
  }

  override_data {
    target = data.terraform_remote_state.api
    values = {
      outputs = {
        campaign_route_contract = {
          schema_version                = 1
          environment                   = "dev"
          campaign_intelligence_enabled = true
          api_id                        = "api-example"
          execution_arn                 = "arn:aws:execute-api:us-east-1:107827791950:api-example"
          authorizer_id                 = "authorizer-example"
          stage_name                    = "$default"
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
          outbox_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-outbox"
          pipeline_table_name     = "campaign-pipeline"
          pipeline_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-pipeline"
          intelligence_table_name = "campaign-intelligence"
          intelligence_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/campaign-intelligence"
          publication_index_name  = "PublicationIndex"
          persistent_kms_key_arn  = "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-2222-2222-222222222222"
          budget_alert_topic_arn  = "arn:aws:sns:us-east-1:107827791950:campaign-alerts"
        }
      }
    }
  }

  assert {
    condition = (
      aws_apigatewayv2_route.trends[0].route_key == "GET /v1/scam-trends" &&
      aws_apigatewayv2_route.trends[0].authorization_type == "JWT" &&
      aws_apigatewayv2_route.review[0].authorization_type == "JWT"
    )
    error_message = "Campaign routes must use the approved paths and existing JWT authorizer."
  }

  assert {
    condition     = aws_lambda_function.trends[0].reserved_concurrent_executions <= 10
    error_message = "Campaign API concurrency must remain bounded."
  }

  assert {
    condition = (
      length(random_password.pagination_token) == 1 &&
      random_password.pagination_token[0].length == 64 &&
      random_password.pagination_token[0].special == false
    )
    error_message = "Campaign pagination must use a 64-character generated environment-scoped signing secret."
  }
}
