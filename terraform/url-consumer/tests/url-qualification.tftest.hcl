mock_provider "aws" {
  override_during = plan
  mock_resource "aws_cloudwatch_log_group" { defaults = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:fixture" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::107827791950:role/candidate" } }
  mock_resource "aws_secretsmanager_secret" { defaults = { arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123" } }
  mock_resource "aws_lambda_function" { defaults = { version = "1" } }
  mock_resource "aws_lambda_alias" { defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:mock:live", invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:107827791950:function:mock:live/invocations" } }
  mock_resource "aws_cloudwatch_event_rule" { defaults = { arn = "arn:aws:events:us-east-1:107827791950:rule/mock" } }
}
variables {
  aws_region   = "us-east-1"
  project_name = "trustcheckradar"
  environment  = "dev"
  enabled      = true
  deployment = {
    "artifacts" : {
      "consumer" : {
        "bucket" : "trustcheckradar-dev-107827791950-artifacts",
        "key" : "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/url_consumer.zip",
        "object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi",
        "source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM="
      },
      "recovery" : {
        "bucket" : "trustcheckradar-dev-107827791950-artifacts",
        "key" : "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/url_lease_recovery.zip",
        "object_version" : "tkwzppvVK_nMdKHgxzFw6DeYsVu3E8X8",
        "source_hash" : "W1nhRs6tjdVEYhreS0NwSSh2ZwNlAzdkw52vGOzWrtE="
      },
      "entitlements" : {
        "bucket" : "trustcheckradar-dev-107827791950-artifacts",
        "key" : "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/v1_entitlements.zip",
        "object_version" : "gR1q8yYMmdsD9.tEZpi8XBwkRLouvsgK",
        "source_hash" : "aIRFixV+H/phUTWYWWQrsz6ruzMaNkptStthsvN5U/8="
      },
      "deletion" : {
        "bucket" : "trustcheckradar-dev-107827791950-artifacts",
        "key" : "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/v1_authority_deletion.zip",
        "object_version" : "test-deletion-version",
        "source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM="
      }
    },
    "users_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users",
    "devices_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings",
    "deletion_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger",
    "authority_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements",
    "assessment_alias_arn" : "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live",
    "cognito_issuer" : "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool",
    "cognito_app_client_id" : "testclient"
  }
  deletion_stream_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-06T23:20:47.091"
  api_gateway = {
    "api_id" : "abcdefghij",
    "execution_arn" : "arn:aws:execute-api:us-east-1:107827791950:abcdefghij"
  }
  alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
  authority_configuration = {
    "operation_validity_seconds" : 300,
    "worker_settlement_seconds" : 60,
    "reconciliation_seconds" : 3600,
    "counter_retention_seconds" : 604800
  }
}

run "explicit_closed_profile_does_not_open_services" {
  command = plan
  variables { url_qualification = {
    table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification"
    manifest_json = jsonencode({ version = 1, runId = "1800000000_fixture", startEpoch = 1800000000, endEpoch = 1800000600, syntheticOnly = true, targets = [{ id = "safe", url = "https://example.com/" }] })
    subject       = "00000000-0000-4000-8000-000000000001"
  } }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].environment[0].variables.URL_QUALIFICATION_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.URL_PROVIDER_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.URL_RETENTION_APPROVED == "false"
    error_message = "Explicit profile stays closed, with no retention inferred from source selection."
  }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].environment[0].variables.URL_NEW_ADMISSION_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.CONSUMER_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.AUTHORITY_ENABLED == "false" && !output.candidate_contract.general_customer_access && !output.candidate_contract.recovery_enabled && !output.candidate_contract.deletion_enabled && !output.candidate_contract.trial_activation_enabled && alltrue([for k in ["recovery", "entitlements", "deletion"] : !contains(keys(aws_lambda_function.runtime[k].environment[0].variables), "URL_QUALIFICATION_ENABLED")])
    error_message = "No other runtime, allowance/trial or selection may inherit the URL profile."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[8].Action == "dynamodb:UpdateItem" && jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[8].Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"]
    error_message = "Admission budget writes must participate in authority's transaction."
  }
}
run "proof_recovery_survives_mode_and_provider_shutdown" {
  command = plan
  variables { url_qualification = {
    table_arn              = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification"
    manifest_json          = jsonencode({ version = 1, runId = "1800000000_fixture", startEpoch = 1800000000, endEpoch = 1800000600, syntheticOnly = true, targets = [{ id = "safe", url = "https://example.com/" }] })
    reconciliation_enabled = true
    subject                = "00000000-0000-4000-8000-000000000001"
  } }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].environment[0].variables.AUTHORITY_ENABLED == "true" && aws_lambda_function.runtime["consumer"].environment[0].variables.URL_RECONCILIATION_ENABLED == "true" && aws_lambda_function.runtime["consumer"].environment[0].variables.URL_QUALIFICATION_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.URL_PROVIDER_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.URL_NEW_ADMISSION_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.CONSUMER_ENABLED == "false" && aws_lambda_function.runtime["entitlements"].environment[0].variables.AUTHORITY_ENABLED == "false"
    error_message = "Rollback keeps existing proof recovery independent, without enabling entitlements or providers."
  }
}
run "environment_limit_counts_utf8_not_characters" {
  command = plan
  variables { url_qualification = {
    table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification"
    manifest_json = jsonencode({ version = 1, runId = "1800000000_fixture", padding = join("", [for n in range(1024) : "ééé"]) })
    subject       = "00000000-0000-4000-8000-000000000001"
  } }
  expect_failures = [aws_lambda_function.runtime["consumer"]]
}
run "provider_cannot_open_without_retention_decision" {
  command = plan
  variables { url_qualification = {
    mode_enabled     = true
    provider_enabled = true
    table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification"
    manifest_json    = jsonencode({ version = 1, runId = "1800000000_fixture", startEpoch = 1800000000, endEpoch = 1800000600, syntheticOnly = true, targets = [{ id = "safe", url = "https://example.com/" }] })
    subject          = "00000000-0000-4000-8000-000000000001"
  } }
  expect_failures = [var.url_qualification]
}
