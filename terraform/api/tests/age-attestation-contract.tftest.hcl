mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  aws_region                         = "us-east-1"
  project_name                       = "trustcheckradar"
  environment                        = "dev"
  state_bucket_name                  = "synthetic-state"
  state_bucket_region                = "us-east-1"
  artifact_release                   = "existing-release"
  age_attestation_lambda_runtime     = "python3.14"
  age_attestation_canonical_base_url = "https://api-dev.andmorethings.net"
  age_attestation_contract = {
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
  }
  age_attestation_monitoring = {
    alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
  }
  profile_fence_deployment = {
    release_id         = "age-candidate"
    object_version     = "synthetic-version"
    source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
  }
}

override_data {
  target = data.terraform_remote_state.foundation
  values = { outputs = { downstream_contract = {
    schema_version                    = 1
    artifact_bucket_name              = "synthetic-artifacts"
    cognito_user_pool_id              = "us-east-1_example"
    cognito_app_client_id             = "synthetic-client"
    age_attestation_authority         = { enabled = true, contract_version = "1.0.0-candidate.1", custom_over_18_client_writable = false }
    users_table_name                  = "trustcheckradar-dev-users"
    users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    deletion_ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
    deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
    deletion_ledger_stream_arn        = null
    analysis_abuse_control_table_name = "trustcheckradar-dev-analysis-abuse-control"
    analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-analysis-abuse-control"
    purchase_entitlements_table_name  = "trustcheckradar-dev-purchase-entitlements"
    purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
    device_bindings_table_name        = "trustcheckradar-dev-device-bindings"
    device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    web_risk_cache_table_name         = "trustcheckradar-dev-web-risk-cache"
    web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-web-risk-cache"
  } } }
}

override_resource {
  target          = aws_apigatewayv2_api.age_attestation
  override_during = plan
  values = {
    id            = "abcdefghij"
    execution_arn = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij"
  }
}

run "access_token_route_and_exact_invoke_boundary" {
  command = plan

  assert {
    condition = (
      aws_apigatewayv2_route.age_attestation.route_key == "POST /v1/users/age-attestation" &&
      aws_apigatewayv2_route.age_attestation.authorization_type == "JWT" &&
      aws_apigatewayv2_route.age_attestation.authorization_scopes == toset(["aws.cognito.signin.user.admin"]) &&
      aws_lambda_permission.allow_api_gateway_invoke_age_attestation.source_account == "107827791950" &&
      aws_lambda_permission.allow_api_gateway_invoke_age_attestation.source_arn == "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/*/POST/v1/users/age-attestation"
    )
    error_message = "Age attestation must require a Cognito access-token scope and grant API Gateway only the exact POST route."
  }

  assert {
    condition = one([
      for settings in aws_apigatewayv2_stage.age_attestation.route_settings : settings
      if settings.route_key == "POST /v1/users/age-attestation"
      ]).throttling_burst_limit == 4 && one([
      for settings in aws_apigatewayv2_stage.age_attestation.route_settings : settings
      if settings.route_key == "POST /v1/users/age-attestation"
    ]).throttling_rate_limit == 2
    error_message = "The low-frequency attestation mutation requires a dedicated bounded route throttle."
  }
}

run "lambda_contract_is_pinned_scoped_and_observable" {
  command = plan

  assert {
    condition = (
      aws_lambda_function.age_attestation.runtime == "python3.14" &&
      aws_lambda_function.age_attestation.architectures == tolist(["arm64"]) &&
      aws_lambda_function.age_attestation.s3_key == "releases/age-candidate/age_attestation.zip" &&
      aws_lambda_function.age_attestation.s3_object_version == "synthetic-version" &&
      aws_lambda_function.age_attestation.source_code_hash == "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" &&
      aws_lambda_function.age_attestation.reserved_concurrent_executions == 5 &&
      aws_lambda_function.age_attestation.environment[0].variables.AGE_ATTESTATION_USER_POOL_ID == "us-east-1_example" &&
      aws_lambda_function.age_attestation.environment[0].variables.AGE_ATTESTATION_ALLOWED_REGION_CODES == "AS,GU,MP,PR,US,VI" &&
      !contains(keys(aws_lambda_function.age_attestation.environment[0].variables), "TABLE_NAME")
    )
    error_message = "The candidate must stay immutable, bounded and receive only the exact authoritative eligibility configuration."
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.age_attestation_lambda.retention_in_days == 14 &&
      aws_cloudwatch_log_group.age_attestation_api.retention_in_days == 14 &&
      length(aws_cloudwatch_metric_alarm.age_attestation_lambda) == 2 &&
      toset([for alarm in aws_cloudwatch_metric_alarm.age_attestation_lambda : alarm.metric_name]) == toset(["Errors", "Throttles"]) &&
      aws_cloudwatch_metric_alarm.age_attestation_api_5xx[0].metric_name == "5xx" &&
      aws_cloudwatch_metric_alarm.age_attestation_api_5xx[0].dimensions.Route == "POST /v1/users/age-attestation" &&
      alltrue([for alarm in aws_cloudwatch_metric_alarm.age_attestation_lambda : alarm.alarm_actions == toset(["arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"])])
    )
    error_message = "Age-attestation runtime/API logs and alarms must use bounded retention and the established support topic."
  }
}

run "iam_allows_only_owned_receipts_profile_updates_and_user_readback" {
  command = plan

  assert {
    condition = (
      one([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement : statement if statement.sid == "ReadAgeProfileAndReceipt"]).actions == toset(["dynamodb:GetItem"]) &&
      one([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement : statement if statement.sid == "WriteAgeProfileAndReceiptTransaction"]).actions == toset(["dynamodb:PutItem", "dynamodb:UpdateItem"]) &&
      one([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement : statement if statement.sid == "CheckAgeProfileAndReceiptTransaction"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
      one([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement : statement if statement.sid == "PreventDeletedProfileReactivation"]).actions == toset(["dynamodb:ConditionCheckItem"])
    )
    error_message = "The role must be limited to owned profile/receipt reads, transaction writes/checks and the deletion fence."
  }

  assert {
    condition = (
      anytrue([for condition in one([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement : statement if statement.sid == "WriteAgeProfileAndReceiptTransaction"]).condition : condition.variable == "dynamodb:EnclosingOperation" && condition.values == tolist(["TransactWriteItems"])]) &&
      alltrue([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement : statement.resources == toset([local.users_table_arn]) || statement.resources == toset([local.deletion_ledger_table_arn])]) &&
      data.aws_iam_policy_document.age_attestation_cognito[0].statement[0].actions == toset(["cognito-idp:AdminGetUser"]) &&
      data.aws_iam_policy_document.age_attestation_cognito[0].statement[0].resources == toset(["arn:aws:cognito-idp:us-east-1:107827791950:userpool/us-east-1_example"])
    )
    error_message = "Writes must be transaction-only and Cognito access must be read-only on the exact user pool."
  }
}

run "backend_output_is_the_versioned_cross_component_contract" {
  command = plan

  assert {
    condition = (
      output.age_attestation_backend_settings.enabled &&
      output.age_attestation_backend_settings.canonicalEndpointUrl == "https://api-dev.andmorethings.net/v1/users/age-attestation" &&
      output.age_attestation_backend_settings.executeApiEndpointEnabled &&
      output.age_attestation_backend_settings.method == "POST" &&
      output.age_attestation_backend_settings.tokenType == "access" &&
      output.age_attestation_backend_settings.contractPath == "contracts/age-attestation/1.0.0-candidate.1" &&
      output.age_attestation_backend_settings.schemaVersion == 1 &&
      output.age_attestation_backend_settings.agePolicyVersion == "v1.0" &&
      output.age_attestation_backend_settings.allowedRegionCodes == tolist(["AS", "GU", "MP", "PR", "US", "VI"]) &&
      output.age_attestation_backend_settings.idempotency.receiptTtlSeconds == 604800 &&
      output.age_attestation_backend_settings.idempotency.ttlAttribute == "expiresAt" &&
      output.age_attestation_backend_settings.idempotency.sortKey == "AGE_ATTESTATION#<operationId>"
    )
    error_message = "The output must hand Android, Lambda and operations one exact access-token, eligibility and idempotency contract."
  }
}

run "production_requires_separate_promotion_approval" {
  command = plan
  variables {
    environment = "prod"
  }
  expect_failures = [var.age_attestation_contract, var.profile_fence_deployment]
}
