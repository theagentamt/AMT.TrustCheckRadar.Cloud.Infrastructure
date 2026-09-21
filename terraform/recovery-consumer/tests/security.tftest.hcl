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
    defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-recovery-evaluator:live" }
  }
}

variables {
  environment = "dev"
  deployment = {
    artifacts = {
      consumer = {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/recovery_consumer.zip"
        object_version = "consumer-version"
        source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      }
      evaluator = {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/recovery_evaluator.zip"
        object_version = "evaluator-version"
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
    condition = (
      length(aws_lambda_function.runtime) == 0 && length(aws_iam_role.runtime) == 0 &&
      length(aws_iam_role_policy.consumer) == 0 && length(aws_iam_role_policy.evaluator) == 0 &&
      length(aws_lambda_alias.runtime) == 0 && length(aws_cloudwatch_log_group.runtime) == 0 &&
      length(aws_cloudwatch_metric_alarm.runtime) == 0 && !output.candidate_contract.provisioned &&
      output.candidate_contract.consumer_endpoint == null
    )
    error_message = "Default recovery root must create no resources or endpoint."
  }
}

run "dev_is_private_inactive_and_bounded" {
  command = apply
  variables { enabled = true }
  assert {
    condition = (
      length(aws_lambda_function.runtime) == 2 &&
      alltrue([for f in aws_lambda_function.runtime : f.runtime == "python3.14" && toset(f.architectures) == toset(["arm64"]) && f.publish && f.reserved_concurrent_executions == 2]) &&
      aws_lambda_function.runtime["consumer"].handler == "recovery_consumer.app.lambda_handler" &&
      aws_lambda_function.runtime["evaluator"].handler == "recovery_evaluator.app.lambda_handler" &&
      aws_lambda_function.runtime["consumer"].timeout == 29 && aws_lambda_function.runtime["evaluator"].timeout == 23 &&
      alltrue([for c in aws_lambda_function_event_invoke_config.no_async_retries : c.maximum_retry_attempts == 0])
    )
    error_message = "Recovery packages must use exact bounded handlers, versions and no async retries."
  }
  assert {
    condition = (
      aws_lambda_function.runtime["consumer"].environment[0].variables.RECOVERY_CONSUMER_ENABLED == "false" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.AUTHORITY_ENABLED == "false" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.RECOVERY_PROVIDER_CIRCUIT_OPEN == "true" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.RECOVERY_EVALUATOR_ENABLED == "false" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.RECOVERY_AI_ENABLED == "false" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.RECOVERY_AI_QUALIFIED == "false" &&
      alltrue([for f in aws_lambda_function.runtime :
        f.environment[0].variables.RECOVERY_POLICY_VERSION == "recovery-clarification-2026-09-21-v1" &&
        f.environment[0].variables.RECOVERY_POLICY_APPROVAL_SHA256 == "173132b8d5a16d3d5a8ccdbc7355a631f8384634945772993200a3559c89da72" &&
        f.environment[0].variables.RECOVERY_PLAYBOOK_VERSION == "recovery-playbook-1.0"
      ])
    )
    error_message = "Policy approval must not activate runtime, provider, authority writes or qualification."
  }
  assert {
    condition = alltrue(flatten([for f in aws_lambda_function.runtime : [for key in [
      "RECOVERY_AI_MODEL", "RECOVERY_AI_SECRET_ARN", "RECOVERY_AI_QUALIFICATION_ID",
      "RECOVERY_AI_MAX_OUTPUT_TOKENS", "RECOVERY_AI_TIMEOUT_MS", "URL_ASSESSMENT_FUNCTION_ARN",
      "MESSAGE_EVALUATOR_FUNCTION_ARN", "RECOVERY_PROVIDER_WINDOW_SECONDS",
      "RECOVERY_PROVIDER_ATTEMPTS_PER_WINDOW", "RECOVERY_PROVIDER_FAILURES_PER_WINDOW"
    ] : !contains(keys(f.environment[0].variables), key)]]))
    error_message = "Disabled bootstrap must not invent provider budgets/model credentials or message/URL dependencies."
  }
  assert {
    condition = (
      jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[2].Resource == var.deployment.authority_table_arn &&
      toset(jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[2].Action) == toset(["dynamodb:GetItem", "dynamodb:ConditionCheckItem"]) &&
      jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[2].Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"] == ["V1#*"] &&
      toset(jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[3].Action) == toset(["dynamodb:PutItem", "dynamodb:UpdateItem"]) &&
      jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[3].Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"] &&
      jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[3].Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"] == ["V1#*"] &&
      jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[4].Resource == var.deployment.authority_hmac_secret_arn &&
      jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[4].Condition.StringEquals["secretsmanager:VersionStage"] == "AWSCURRENT" &&
      jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[5].Resource == aws_lambda_alias.runtime["evaluator"].arn
    )
    error_message = "Consumer must use existing fenced transactional authority and only its private evaluator."
  }
  assert {
    condition = (
      length(jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement) == 2 &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[0].Resource == "${aws_cloudwatch_log_group.runtime["evaluator"].arn}:*" &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[1].Effect == "Deny" &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[1].Resource == "*" &&
      toset(jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[1].Action) == toset(["dynamodb:*", "secretsmanager:*", "s3:*", "ssm:*", "lambda:InvokeFunction", "sts:AssumeRole"]) &&
      !contains(keys(aws_lambda_function.runtime["evaluator"].environment[0].variables), "AUTHORITY_HMAC_SECRET_ARN") &&
      !contains(keys(aws_lambda_function.runtime["evaluator"].environment[0].variables), "AUTHORITY_TABLE_NAME")
    )
    error_message = "Evaluator must have only own-log permission; deny secrets, storage and downstream Lambda calls."
  }
  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.runtime) == 6 &&
      alltrue([for alarm in aws_cloudwatch_metric_alarm.runtime :
        alarm.alarm_actions == toset(["arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"]) &&
        alarm.ok_actions == alarm.alarm_actions && toset(keys(alarm.dimensions)) == toset(["FunctionName"])
      ]) &&
      aws_cloudwatch_metric_alarm.runtime["consumer-duration"].threshold == 26000 &&
      aws_cloudwatch_metric_alarm.runtime["evaluator-duration"].threshold == 20000 &&
      output.candidate_contract.consumer_endpoint == null && output.candidate_contract.authority_reused &&
      !output.candidate_contract.secret_value_in_state && !output.candidate_contract.daily_reporting_ready
    )
    error_message = "Existing support alarms must expose no payload dimensions or claim full reporting/activation."
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
        consumer = merge(var.deployment.artifacts.consumer, { object_version = "null" })
      })
    })
  }
  expect_failures = [var.deployment]
}

run "mixed_releases_rejected" {
  command = plan
  variables {
    deployment = merge(var.deployment, {
      artifacts = merge(var.deployment.artifacts, {
        evaluator = merge(var.deployment.artifacts.evaluator, {
          key = "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/recovery_evaluator.zip"
        })
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
        evaluator = merge(var.deployment.artifacts.evaluator, {
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
  expect_failures = [aws_iam_role_policy.consumer]
}
