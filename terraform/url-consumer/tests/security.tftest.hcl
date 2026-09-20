mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/candidate" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { version = "1" }
  }
}
variables {
  environment = "dev"
}
run "disabled_creates_no_runtime_or_secret" {
  command = plan
  assert {
    condition     = length(aws_lambda_function.runtime) == 0 && length(aws_iam_role.runtime) == 0 && length(aws_secretsmanager_secret.authority_hmac) == 0 && !output.candidate_contract.consumer_enabled && output.candidate_contract.consumer_endpoint == null
    error_message = "Default configuration must create nothing and advertise no endpoint."
  }
}
run "candidate_is_isolated_and_inactive" {
  command = apply
  variables {
    enabled = true
    deployment = {
      artifacts = {
        consumer = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/url_consumer.zip"
          object_version = "consumer-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
        entitlements = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/v1_entitlements.zip"
          object_version = "entitlements-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
        recovery = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/url_lease_recovery.zip"
          object_version = "recovery-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
      }
      users_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
      devices_table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
      deletion_table_arn    = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      authority_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
      assessment_alias_arn  = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live"
      cognito_issuer        = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
      cognito_app_client_id = "testclient"
    }
  }
  assert {
    condition     = alltrue([for f in aws_lambda_function.runtime : f.runtime == "python3.14" && toset(f.architectures) == toset(["arm64"]) && f.publish]) && aws_lambda_function.runtime["consumer"].timeout == 29 && aws_lambda_function.runtime["consumer"].reserved_concurrent_executions == 2 && aws_lambda_function.runtime["recovery"].reserved_concurrent_executions == 1
    error_message = "Runtime must be pinned and provider/recovery concurrency bounded."
  }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].environment[0].variables.CONSUMER_ENABLED == "false" && aws_lambda_function.runtime["recovery"].environment[0].variables.LEASE_SWEEP_ENABLED == "false" && aws_lambda_function.runtime["entitlements"].environment[0].variables.TRIAL_AUTHORITY_RETENTION_APPROVED == "true" && !output.candidate_contract.recovery_enabled && !output.candidate_contract.consumer_enabled
    error_message = "Provisioning must not silently activate data writes, provider access, or cleanup."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[3].Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"] && jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[4].Resource == aws_secretsmanager_secret.authority_hmac[0].arn && jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[5].Resource == var.deployment.assessment_alias_arn
    error_message = "Consumer must mutate atomically and access only its HMAC secret and private assessment alias."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.recovery[0].policy).Statement[2].Resource == "${var.deployment.authority_table_arn}/index/GSI1" && jsondecode(aws_iam_role_policy.recovery[0].policy).Statement[2].Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"] == ["V1_PENDING", "V1_EXPIRING"] && jsondecode(aws_iam_role_policy.recovery[0].policy).Statement[5].Effect == "Deny" && contains(jsondecode(aws_iam_role_policy.recovery[0].policy).Statement[5].Action, "lambda:InvokeFunction") && !contains(keys(aws_lambda_function.runtime["recovery"].environment[0].variables), "AUTHORITY_HMAC_SECRET_ARN")
    error_message = "Cleanup must use only pending ledger records and cannot invoke providers or retrieve secrets."
  }
  assert {
    condition     = alltrue([for f in aws_lambda_function_event_invoke_config.no_async_retries : f.maximum_retry_attempts == 0]) && !output.candidate_contract.secret_value_in_state
    error_message = "No automatic asynchronous retries or Terraform-managed secret values."
  }
  assert {
    condition     = !contains(jsondecode(aws_iam_role_policy.entitlements[0].policy).Statement[2].Action, "dynamodb:Query") && jsondecode(aws_iam_role_policy.entitlements[0].policy).Statement[5].Effect == "Deny" && contains(jsondecode(aws_iam_role_policy.entitlements[0].policy).Statement[5].Action, "lambda:InvokeFunction") && !contains(keys(aws_lambda_function.runtime["entitlements"].environment[0].variables), "URL_ASSESSMENT_FUNCTION_ARN") && aws_lambda_function.runtime["entitlements"].environment[0].variables.AUTHORITY_ENABLED == "false"
    error_message = "Access and trial handlers cannot enumerate authority, invoke providers, or activate authority implicitly."
  }
}
run "uat_provisioning_rejected" {
  command = plan
  variables {
    environment = "uat"
    enabled     = true
  }
  expect_failures = [var.enabled]
}
run "missing_artifacts_rejected" {
  command = plan
  variables { enabled = true }
  expect_failures = [var.enabled]
}
