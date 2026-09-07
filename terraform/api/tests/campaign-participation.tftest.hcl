mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  aws_region          = "us-east-1"
  project_name        = "trustcheckradar"
  environment         = "dev"
  state_bucket_name   = "terraform-state-example"
  state_bucket_region = "us-east-1"
  artifact_release    = "2026.09.07-1"
}

override_data {
  target = data.terraform_remote_state.foundation
  values = {
    outputs = {
      downstream_contract = {
        schema_version                    = 1
        artifact_bucket_name              = "artifact-example"
        cognito_user_pool_id              = "us-east-1_example"
        cognito_app_client_id             = "client-example"
        users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/users"
        users_table_name                  = "users"
        deletion_ledger_stream_arn        = null
        deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger"
        deletion_ledger_table_name        = "deletion-ledger"
        analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/analysis-abuse"
        analysis_abuse_control_table_name = "analysis-abuse"
        purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/entitlements"
        purchase_entitlements_table_name  = "entitlements"
        device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/device-bindings"
        device_bindings_table_name        = "device-bindings"
        web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/web-risk-cache"
        web_risk_cache_table_name         = "web-risk-cache"
      }
    }
  }
}

run "participation_api_is_authenticated_and_environment_scoped" {
  command = plan

  assert {
    condition = (
      aws_apigatewayv2_route.campaign_participation_get.route_key == "GET /v1/users/campaign-participation" &&
      aws_apigatewayv2_route.campaign_participation_put.route_key == "PUT /v1/users/campaign-participation" &&
      aws_apigatewayv2_route.campaign_participation_get.authorization_type == "JWT" &&
      aws_apigatewayv2_route.campaign_participation_put.authorization_type == "JWT"
    )
    error_message = "Campaign participation must expose JWT-protected GET and PUT routes."
  }

  assert {
    condition = (
      aws_lambda_function.campaign_participation.function_name == "trustcheckradar-dev-campaign-participation" &&
      aws_lambda_function.campaign_participation.s3_key == "releases/2026.09.07-1/campaign_participation.zip" &&
      aws_lambda_function.campaign_participation.environment[0].variables["ENVIRONMENT"] == "dev"
    )
    error_message = "The participation Lambda must use the environment name and immutable release artifact."
  }
}

run "participation_contract_keeps_consent_optional_and_quota_bounded" {
  command = plan

  assert {
    condition = (
      aws_lambda_function.campaign_participation.environment[0].variables["CAMPAIGN_PARTICIPATION_NOTICE_VERSION"] == "2026-09-07" &&
      aws_lambda_function.campaign_participation.environment[0].variables["CAMPAIGN_PARTICIPATION_POLICY_VERSION"] == "policy-1" &&
      aws_lambda_function.campaign_participation.environment[0].variables["CAMPAIGN_PARTICIPATION_AUDIT_RETENTION_DAYS"] == "400" &&
      aws_lambda_function.campaign_participation.environment[0].variables["CAMPAIGN_PARTICIPATION_DELETION_SLA_HOURS"] == "24" &&
      aws_lambda_function.campaign_participation.environment[0].variables["FREE_MONTHLY_SCAN_LIMIT"] == "10" &&
      aws_lambda_function.campaign_participation.environment[0].variables["PARTICIPATING_FREE_MONTHLY_SCAN_LIMIT"] == "15"
    )
    error_message = "The participation Lambda must receive the approved notice, retention, deletion, and quota contract."
  }

  assert {
    condition = (
      aws_lambda_function.analysis.environment[0].variables["CAMPAIGN_PARTICIPATION_ITEM_SK"] == "CAMPAIGN_PARTICIPATION" &&
      aws_lambda_function.analysis.environment[0].variables["PARTICIPATING_FREE_MONTHLY_SCAN_LIMIT"] == "15" &&
      aws_lambda_function.entitlement_snapshot.environment[0].variables["CAMPAIGN_PARTICIPATION_ITEM_SK"] == "CAMPAIGN_PARTICIPATION"
    )
    error_message = "Quota and publication readers must use the server-side participation record."
  }
}
