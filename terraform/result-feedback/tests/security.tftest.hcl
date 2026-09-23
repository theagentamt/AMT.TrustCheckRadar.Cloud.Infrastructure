mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/candidate" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { version = "1" }
  }
  mock_resource "aws_lambda_alias" {
    defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-result-feedback:live" }
  }
}

variables {
  environment = "dev"
  deployment = {
    artifacts = {
      feedback = {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/result_feedback.zip"
        object_version = "consumer-version"
        source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      }
    }
    users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
    authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
    authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
    cognito_app_client_id     = "testclient"
  }
}

run "disabled_creates_nothing" {
  command = plan
  variables { deployment = null }
  assert {
    condition     = length(aws_lambda_function.runtime) == 0 && length(aws_iam_role.runtime) == 0 && length(aws_cloudwatch_metric_alarm.runtime) == 0 && output.candidate_contract.endpoint == null && !output.candidate_contract.feedback_enabled
    error_message = "Default must create no feedback resources or endpoint."
  }
}
run "dev_private_bounded_minimal" {
  command = apply
  variables { enabled = true }
  assert {
    condition     = length(aws_lambda_function.runtime) == 1 && aws_lambda_function.runtime["feedback"].handler == "result_feedback.app.lambda_handler" && aws_lambda_function.runtime["feedback"].runtime == "python3.14" && aws_lambda_function.runtime["feedback"].timeout == 10 && aws_lambda_function.runtime["feedback"].memory_size == 256 && aws_lambda_function.runtime["feedback"].reserved_concurrent_executions == 2 && toset(aws_lambda_function.runtime["feedback"].architectures) == toset(["arm64"]) && aws_lambda_function.runtime["feedback"].publish && aws_lambda_function_event_invoke_config.no_async_retries["feedback"].maximum_retry_attempts == 0
    error_message = "Use only the pinned bounded feedback handler with no asynchronous retry."
  }
  assert {
    condition     = aws_lambda_function.runtime["feedback"].environment[0].variables.RESULT_FEEDBACK_ENABLED == "false" && aws_lambda_function.runtime["feedback"].environment[0].variables.RESULT_FEEDBACK_POLICY_APPROVAL_SHA256 == "9e3485588daeae698b139cb070b4de16bb9298348135271e7d9adafd9968bee6" && output.candidate_contract.endpoint == null && !output.candidate_contract.live_qualified && !output.candidate_contract.backup_inventory_verified
    error_message = "Provisioning must not claim live qualification, backup verification or enable feedback."
  }
  assert {
    condition     = toset(keys(aws_lambda_function.runtime["feedback"].environment[0].variables)) == toset(["STAGE", "RESULT_FEEDBACK_ENABLED", "RESULT_FEEDBACK_POLICY_VERSION", "RESULT_FEEDBACK_POLICY_APPROVAL_SHA256", "AUTHORITY_TABLE_NAME", "USERS_TABLE_NAME", "DEVICE_BINDINGS_TABLE_NAME", "DELETION_LEDGER_TABLE_NAME", "COGNITO_ISSUER", "COGNITO_APP_CLIENT_ID", "COGNITO_REQUIRED_SCOPE", "AUTHORITY_HMAC_SECRET_ARN"])
    error_message = "Do not introduce provider settings, billing gates or implicit attempt limits in inactive candidate."
  }
  assert {
    condition     = length(jsondecode(aws_iam_role_policy.feedback[0].policy).Statement) == 6 && jsondecode(aws_iam_role_policy.feedback[0].policy).Statement[3].Action == ["dynamodb:UpdateItem"] && jsondecode(aws_iam_role_policy.feedback[0].policy).Statement[3].Resource == var.deployment.authority_table_arn && jsondecode(aws_iam_role_policy.feedback[0].policy).Statement[3].Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"] == ["V1#*#*"] && jsondecode(aws_iam_role_policy.feedback[0].policy).Statement[3].Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"] && jsondecode(aws_iam_role_policy.feedback[0].policy).Statement[4].Resource == var.deployment.authority_hmac_secret_arn && jsondecode(aws_iam_role_policy.feedback[0].policy).Statement[4].Condition.StringEquals["secretsmanager:VersionStage"] == "AWSCURRENT"
    error_message = "Only fenced authority transaction updates and exact HMAC secret access are allowed."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.feedback[0].policy).Statement[5].Effect == "Deny" && toset(jsondecode(aws_iam_role_policy.feedback[0].policy).Statement[5].Action) == toset(["s3:*", "ssm:*", "sts:AssumeRole", "lambda:InvokeFunction", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"]) && length(aws_cloudwatch_metric_alarm.runtime) == 3 && alltrue([for alarm in aws_cloudwatch_metric_alarm.runtime : alarm.alarm_actions == toset(["arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"]) && alarm.ok_actions == alarm.alarm_actions && toset(keys(alarm.dimensions)) == toset(["FunctionName"])]) && aws_cloudwatch_metric_alarm.runtime["feedback-duration"].threshold == 7000
    error_message = "No provider calls, enumeration/deletion or new alert destinations; use payload-free native metrics."
  }
}
run "uat_rejected" {
  command = plan
  variables {
    environment = "uat"
    enabled     = true
    deployment  = null
  }
  expect_failures = [var.enabled]
}

run "prod_rejected" {
  command = plan
  variables {
    environment = "prod"
    enabled     = true
    deployment  = null
  }
  expect_failures = [var.enabled]
}

run "missing_artifacts_rejected" {
  command = plan
  variables {
    enabled    = true
    deployment = null
  }
  expect_failures = [var.enabled]
}

run "wrong_region_rejected" {
  command = plan
  variables {
    aws_region = "us-west-2"
    enabled    = true
    deployment = null
  }
  expect_failures = [var.enabled]
}

run "mutable_artifact_rejected" {
  command = plan
  variables {
    deployment = merge(var.deployment, {
      artifacts = merge(var.deployment.artifacts, {
        feedback = merge(var.deployment.artifacts.feedback, { object_version = "null" })
      })
    })
  }
  expect_failures = [var.deployment]
}

run "unrelated_package_rejected" {
  command = plan
  variables {
    deployment = merge(var.deployment, {
      artifacts = merge(var.deployment.artifacts, {
        feedback = merge(var.deployment.artifacts.feedback, {
          key = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_evaluator.zip"
        })
      })
    })
  }
  expect_failures = [var.deployment]
}

run "wrong_secret_environment_rejected" {
  command = plan
  variables {
    deployment = merge(var.deployment, {
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/prod/v1-authority-hmac-ABC123"
    })
  }
  expect_failures = [var.deployment]
}

run "foreign_account_rejected" {
  command = plan
  variables {
    enabled = true
    deployment = merge(var.deployment, {
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:999999999999:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    })
  }
  expect_failures = [aws_iam_role_policy.feedback]
}
