mock_provider "aws" {
  override_during = plan
  mock_resource "aws_cloudwatch_log_group" { defaults = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:fixture" } }
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a"] }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/resolver-execution" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { version = "1" }
  }
  mock_resource "aws_lambda_alias" {
    defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-resolver:live" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts" }
  }
}

variables {
  aws_region   = "us-east-1"
  project_name = "trustcheckradar"
  environment  = "dev"
  enabled      = true
  artifact     = { bucket = "trustcheckradar-dev-107827791950-artifacts", key = "releases/fixture/url_redirect_resolver.zip", object_version = "fixture", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
}

run "explicit_closed_profile_does_not_open_services" {
  command = plan
  variables { url_qualification = {
    table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification"
    manifest_json = jsonencode({ version = 1, runId = "1800000000_fixture", startEpoch = 1800000000, endEpoch = 1800000600, syntheticOnly = true, targets = [{ id = "safe", url = "https://example.com/" }] })

  } }
  assert {
    condition     = aws_lambda_function.resolver[0].environment[0].variables.URL_QUALIFICATION_ENABLED == "false" && aws_lambda_function.resolver[0].environment[0].variables.URL_PROVIDER_ENABLED == "false" && aws_lambda_function.resolver[0].environment[0].variables.URL_RETENTION_APPROVED == "false"
    error_message = "Explicit profile stays closed, with no retention inferred from source selection."
  }
  assert {
    condition     = !contains(keys(aws_lambda_function.resolver[0].environment[0].variables), "URL_SUBJECT_ALLOWLIST_JSON") && !contains(keys(aws_lambda_function.resolver[0].environment[0].variables), "COGNITO_ISSUER")
    error_message = "Private workers must not receive actor identity or authentication configuration."
  }
}
run "environment_limit_counts_utf8_not_characters" {
  command = plan
  variables { url_qualification = {
    table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification"
    manifest_json = jsonencode({ version = 1, runId = "1800000000_fixture", padding = join("", [for n in range(1024) : "ééé"]) })

  } }
  expect_failures = [aws_lambda_function.resolver[0]]
}
run "provider_cannot_open_without_retention_decision" {
  command = plan
  variables { url_qualification = {
    mode_enabled     = true
    provider_enabled = true
    table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification"
    manifest_json    = jsonencode({ version = 1, runId = "1800000000_fixture", startEpoch = 1800000000, endEpoch = 1800000600, syntheticOnly = true, targets = [{ id = "safe", url = "https://example.com/" }] })

  } }
  expect_failures = [var.url_qualification]
}
