mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
}

variables {
  analysis_retirement_deployment = {
    release_id         = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
    object_version     = "K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1"
    source_hash        = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4="
    approval_reference = "synthetic-retirement-review"
    promotion_approved = true
  }
  aws_region          = "us-east-1"
  project_name        = "trustcheckradar"
  environment         = "dev"
  state_bucket_name   = "synthetic-state"
  state_bucket_region = "us-east-1"
  artifact_release    = "existing-release"
  support_account_deletion_deployment = {
    release_id         = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    object_version     = "synthetic-version"
    source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference = "synthetic-test-not-user-approval"
  }
}

override_data {
  target = data.terraform_remote_state.foundation
  values = { outputs = { downstream_contract = {
    schema_version                    = 1
    artifact_bucket_name              = "synthetic-artifacts"
    cognito_user_pool_id              = "us-east-1_example"
    cognito_app_client_id             = "synthetic-client"
    users_table_name                  = "trustcheckradar-dev-users"
    users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    deletion_ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
    deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
    deletion_ledger_stream_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-14T00:00:00.000"
    analysis_abuse_control_table_name = "trustcheckradar-dev-analysis-abuse-control"
    analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-analysis-abuse-control"
    purchase_entitlements_table_name  = "trustcheckradar-dev-purchase-entitlements"
    purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
    device_bindings_table_name        = "trustcheckradar-dev-device-bindings"
    device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    web_risk_cache_table_name         = "web-risk-cache"
    web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/web-risk-cache"
    device_recovery_control = {
      schema_version = 1
      enabled        = true
      environment    = "dev"
      table_name     = "trustcheckradar-dev-device-recovery-control"
      table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-recovery-control"
      ttl_attribute  = "expiresAt"
      policy = {
        approved               = true
        approval_reference     = "synthetic-test-not-user-approval"
        audit_retention_days   = 90
        receipt_retention_days = 7
        rate_retention_hours   = 24
        pitr_days              = 7
      }
    }
  } } }
}



run "absent_by_default" {
  command = plan
  variables { support_account_deletion_deployment = null }
  assert {
    condition     = length(aws_lambda_function.support_account_deletion) == 0 && length(aws_iam_role.support_account_deletion) == 0 && length(aws_cloudwatch_log_group.support_account_deletion) == 0 && !output.support_account_deletion_candidate_contract.deployed
    error_message = "Default must create no support-deletion resources."
  }
}
run "pinned_disabled_logs_only_candidate" {
  command = plan
  override_resource {
    target          = aws_cloudwatch_log_group.support_account_deletion[0]
    override_during = plan
    values          = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:/aws/lambda/trustcheckradar-dev-support-account-deletion" }
  }
  assert {
    condition = (
      aws_lambda_function.support_account_deletion[0].runtime == "python3.14" &&
      aws_lambda_function.support_account_deletion[0].architectures == tolist(["arm64"]) &&
      aws_lambda_function.support_account_deletion[0].handler == "app.lambda_handler" &&
      aws_lambda_function.support_account_deletion[0].s3_key == "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/support_account_deletion.zip" &&
      aws_lambda_function.support_account_deletion[0].s3_object_version == "synthetic-version" &&
      aws_lambda_function.support_account_deletion[0].source_code_hash == var.support_account_deletion_deployment.source_hash &&
      aws_lambda_function.support_account_deletion[0].environment[0].variables == tomap({ APP_ENVIRONMENT = "dev", SUPPORT_ACCOUNT_DELETION_ENABLED = "false" }) &&
      aws_lambda_function.support_account_deletion[0].reserved_concurrent_executions == 1 &&
      aws_lambda_function_event_invoke_config.support_account_deletion[0].maximum_retry_attempts == 0 &&
      aws_cloudwatch_log_group.support_account_deletion[0].retention_in_days == 14
    )
    error_message = "Candidate must be exact pinned Python3.14 ARM64, bounded and disabled before SDK access."
  }
  assert {
    condition     = length(data.aws_iam_policy_document.support_account_deletion[0].statement) == 1 && one(data.aws_iam_policy_document.support_account_deletion[0].statement).actions == toset(["logs:CreateLogStream", "logs:PutLogEvents"]) && one(data.aws_iam_policy_document.support_account_deletion[0].statement).resources == toset(["arn:aws:logs:us-east-1:107827791950:log-group:/aws/lambda/trustcheckradar-dev-support-account-deletion:*"])
    error_message = "Candidate may only write its own logs; no KMS, identity or account-data rights."
  }
  assert {
    condition     = !output.support_account_deletion_candidate_contract.enabled && !output.support_account_deletion_candidate_contract.operator_grants && !output.support_account_deletion_candidate_contract.verification_storage && !output.support_account_deletion_candidate_contract.email_deletion_available && length(output.support_account_deletion_candidate_contract.routes) == 0
    error_message = "Candidate preparation cannot advertise an available support path."
  }
}
run "reject_other_environment" {
  command = plan
  variables { environment = "uat" }
  expect_failures = [aws_lambda_function.analysis, var.support_account_deletion_deployment]
}
run "reject_unpinned_version" {
  command = plan
  variables {
    support_account_deletion_deployment = {
      release_id         = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      object_version     = "null"
      source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic"
    }
  }
  expect_failures = [var.support_account_deletion_deployment]
}
run "reject_noncommit_source" {
  command = plan
  variables {
    support_account_deletion_deployment = {
      release_id         = "release-V01"
      object_version     = "synthetic-version"
      source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic"
    }
  }
  expect_failures = [var.support_account_deletion_deployment]
}

run "iam_transport_preserves_disabled_admission" {
  command = plan
  variables {
    support_account_deletion_gateway = {
      api_id             = "abcdefghij"
      stage              = "$default"
      approval_reference = "synthetic-only"
    }
  }
  override_resource {
    target          = aws_apigatewayv2_api.age_attestation
    override_during = plan
    values          = { id = "abcdefghij", execution_arn = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij" }
  }
  override_resource {
    target          = aws_lambda_function.support_account_deletion[0]
    override_during = plan
    values          = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion" }
  }
  assert {
    condition = (
      aws_apigatewayv2_route.support_account_deletion[0].authorization_type == "AWS_IAM" &&
      aws_apigatewayv2_route.support_account_deletion[0].route_key == "POST /support/account-deletion" &&
      aws_apigatewayv2_integration.support_account_deletion[0].integration_uri == "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-support-account-deletion" &&
      aws_apigatewayv2_integration.support_account_deletion[0].payload_format_version == "2.0" &&
      aws_apigatewayv2_integration.support_account_deletion[0].timeout_milliseconds == 15000 &&
      aws_lambda_permission.support_account_deletion_gateway[0].source_account == "107827791950" &&
      aws_lambda_permission.support_account_deletion_gateway[0].source_arn == "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/$default/POST/support/account-deletion" &&
      aws_lambda_permission.support_account_deletion_gateway[0].principal == "apigateway.amazonaws.com"
    )
    error_message = "Only the exact IAM POST/stage may reach the unqualified disabled handler."
  }
  assert {
    condition = (
      aws_lambda_function.support_account_deletion[0].environment[0].variables == tomap({ APP_ENVIRONMENT = "dev", SUPPORT_ACCOUNT_DELETION_ENABLED = "false" }) &&
      length(data.aws_iam_policy_document.support_account_deletion[0].statement) == 1 &&
      !output.support_account_deletion_candidate_contract.enabled &&
      !output.support_account_deletion_candidate_contract.account_data_permissions &&
      !output.support_account_deletion_candidate_contract.email_deletion_available &&
      anytrue([for setting in aws_apigatewayv2_stage.age_attestation.route_settings : setting.route_key == "POST /support/account-deletion" && setting.throttling_burst_limit == 1 && setting.throttling_rate_limit == 1])
    )
    error_message = "Transport must remain throttled and cannot enable or grant account admission."
  }
}
run "reject_gateway_without_candidate" {
  command = plan
  variables {
    support_account_deletion_deployment = null
    support_account_deletion_gateway    = { api_id = "abcdefghij", stage = "$default", approval_reference = "synthetic" }
  }
  expect_failures = [var.support_account_deletion_gateway]
}
run "reject_gateway_wrong_stage" {
  command = plan
  variables {
    support_account_deletion_gateway = { api_id = "abcdefghij", stage = "dev", approval_reference = "synthetic" }
  }
  expect_failures = [var.support_account_deletion_gateway]
}
run "reject_gateway_wrong_api" {
  command = plan
  variables {
    support_account_deletion_gateway = { api_id = "abcdefghij", stage = "$default", approval_reference = "synthetic" }
  }
  override_resource {
    target          = aws_apigatewayv2_api.age_attestation
    override_during = plan
    values          = { id = "wrongapi12", execution_arn = "arn:aws:execute-api:us-east-1:107827791950:wrongapi12" }
  }
  expect_failures = [aws_apigatewayv2_integration.support_account_deletion]
}
