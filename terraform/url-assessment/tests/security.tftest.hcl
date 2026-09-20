mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/assessment" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { version = "1" }
  }
  mock_resource "aws_lambda_alias" {
    defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
}
variables {
  aws_region   = "us-east-1"
  project_name = "trustcheckradar"
  environment  = "dev"
}
run "disabled_has_no_managed_resources" {
  command = plan
  assert {
    condition     = length(aws_lambda_function.assessment) == 0 && length(aws_iam_role.assessment) == 0 && length(aws_iam_role.dev_test) == 0 && !output.operator_contract.consumer_activation && output.operator_contract.consumer_endpoint == null
    error_message = "Disabled configuration must not provision or advertise consumer activation."
  }
}
run "private_runtime_has_only_exact_dependencies" {
  command = apply
  variables {
    enabled         = true
    alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
    artifact = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/test/url_assessment.zip"
      object_version = "immutable-test"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
    secret_arn             = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/web-risk-api-key-ABC123"
    resolver_alias_arn     = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-resolver:live"
    dev_test_principal_arn = "arn:aws:iam::107827791950:role/operator"
  }
  assert {
    condition     = aws_lambda_function.assessment[0].runtime == "python3.14" && aws_lambda_function.assessment[0].timeout == 35 && aws_lambda_function.assessment[0].reserved_concurrent_executions == 2 && aws_lambda_function.assessment[0].publish && aws_lambda_alias.assessment[0].name == "live" && aws_cloudwatch_log_group.assessment[0].retention_in_days == 14
    error_message = "Operator function must keep its pinned runtime, capacity, version and retention bounds."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.runtime[0].policy).Statement[1].Action == "secretsmanager:GetSecretValue" && jsondecode(aws_iam_role_policy.runtime[0].policy).Statement[1].Resource == var.secret_arn && jsondecode(aws_iam_role_policy.runtime[0].policy).Statement[2].Resource == var.resolver_alias_arn && jsondecode(aws_iam_role_policy.runtime[0].policy).Statement[3].Effect == "Deny"
    error_message = "Provider and resolver permissions must be exact and consumer storage denied."
  }
  assert {
    condition     = aws_lambda_function.assessment[0].environment[0].variables == tomap({ STAGE = "dev", WEB_RISK_SECRET_ARN = var.secret_arn, URL_RESOLVER_FUNCTION_ARN = var.resolver_alias_arn }) && jsondecode(aws_iam_role.dev_test[0].assume_role_policy).Statement[0].Principal.AWS == var.dev_test_principal_arn && jsondecode(aws_iam_role_policy.dev_test[0].policy).Statement[0].Resource == aws_lambda_alias.assessment[0].arn && aws_lambda_function_event_invoke_config.no_async_retries[0].maximum_retry_attempts == 0
    error_message = "Runtime configuration must contain references only, and operator access must target just the alias."
  }
}
run "uat_activation_is_rejected" {
  command = plan
  variables {
    environment     = "uat"
    alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-uat-url-resolver-alerts"
    enabled         = true
  }
  expect_failures = [var.enabled]
}
run "unqualified_resolver_is_rejected" {
  command = plan
  variables {
    resolver_alias_arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-resolver"
  }
  expect_failures = [var.resolver_alias_arn]
}
run "wildcard_secret_is_rejected" {
  command = plan
  variables {
    secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:*"
  }
  expect_failures = [var.secret_arn]
}
