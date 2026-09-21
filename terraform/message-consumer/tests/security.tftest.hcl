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
    defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-message-evaluator:live" }
  }
}
variables {
  environment = "dev"
}
run "disabled_creates_no_runtime" {
  command = plan
  assert {
    condition     = length(aws_lambda_function.runtime) == 0 && length(aws_iam_role.runtime) == 0 && length(aws_iam_role_policy.consumer) == 0 && length(aws_iam_role_policy.evaluator) == 0 && output.candidate_contract.consumer_endpoint == null
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
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_consumer.zip"
          object_version = "consumer-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
        evaluator = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_evaluator.zip"
          object_version = "evaluator-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
      }
      users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
      devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
      deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
      assessment_alias_arn      = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live"
      cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
      cognito_app_client_id     = "testclient"
    }
  }
  assert {
    condition     = length(aws_lambda_function.runtime) == 2 && alltrue([for f in aws_lambda_function.runtime : f.runtime == "python3.14" && toset(f.architectures) == toset(["arm64"]) && f.publish && f.reserved_concurrent_executions == 2]) && aws_lambda_function.runtime["consumer"].timeout == 29 && aws_lambda_function.runtime["evaluator"].timeout == 23
    error_message = "Both isolated runtimes must be pinned, published and bounded."
  }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_CONSUMER_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.AUTHORITY_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_PROVIDER_CIRCUIT_OPEN == "true" && aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_EVALUATOR_ENABLED == "false" && !output.candidate_contract.consumer_enabled && !output.candidate_contract.evaluator_enabled && !output.candidate_contract.model_enabled
    error_message = "Provisioning must not activate service, authority writes, providers or model access."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[3].Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"] && jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[3].Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"] == ["V1#*"] && jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[4].Resource == var.deployment.authority_hmac_secret_arn && jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[4].Condition.StringEquals["secretsmanager:VersionStage"] == "AWSCURRENT" && jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[5].Resource == aws_lambda_alias.runtime["evaluator"].arn
    error_message = "Consumer must reuse the existing fenced ledger/HMAC and invoke only the private evaluator alias."
  }
  assert {
    condition     = !contains(jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[2].Action, "dynamodb:Query") && !contains(jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[3].Action, "dynamodb:DeleteItem")
    error_message = "Message processing must not enumerate or delete authority records; existing lifecycle workers own that work."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[1].Resource == var.deployment.assessment_alias_arn && jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[2].Effect == "Deny" && alltrue([for action in ["dynamodb:*", "secretsmanager:*", "s3:*", "ssm:*", "sts:AssumeRole"] : contains(jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[2].Action, action)]) && !contains(keys(aws_lambda_function.runtime["evaluator"].environment[0].variables), "AUTHORITY_HMAC_SECRET_ARN") && !contains(keys(aws_lambda_function.runtime["evaluator"].environment[0].variables), "AUTHORITY_TABLE_NAME")
    error_message = "Evaluator must have no authority/storage/secret access and only the exact private URL-assessment invocation grant."
  }
  assert {
    condition     = alltrue([for f in aws_lambda_function_event_invoke_config.no_async_retries : f.maximum_retry_attempts == 0]) && output.candidate_contract.authority_reused && !output.candidate_contract.secret_value_in_state && output.candidate_contract.consumer_endpoint == null
    error_message = "Candidate must not add automatic retries, new authority, secret values or public endpoints."
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

run "prod_provisioning_rejected" {
  command = plan
  variables {
    environment = "prod"
    enabled     = true
  }
  expect_failures = [var.enabled]
}

run "missing_artifacts_rejected" {
  command = plan
  variables {
    enabled = true
  }
  expect_failures = [var.enabled]
}

run "wrong_hmac_environment_rejected" {
  command = plan
  variables {
    deployment = {
      artifacts = {
        consumer = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_consumer.zip"
          object_version = "consumer-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
        evaluator = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_evaluator.zip"
          object_version = "evaluator-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
      }
      users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
      devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
      deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/prod/v1-authority-hmac-ABC123"
      assessment_alias_arn      = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live"
      cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
      cognito_app_client_id     = "testclient"
    }
  }
  expect_failures = [var.deployment]
}

run "unqualified_assessment_rejected" {
  command = plan
  variables {
    deployment = {
      artifacts = {
        consumer = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_consumer.zip"
          object_version = "consumer-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
        evaluator = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_evaluator.zip"
          object_version = "evaluator-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
      }
      users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
      devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
      deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
      assessment_alias_arn      = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment"
      cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
      cognito_app_client_id     = "testclient"
    }
  }
  expect_failures = [var.deployment]
}

run "mixed_release_artifacts_rejected" {
  command = plan
  variables {
    deployment = {
      artifacts = {
        consumer = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_consumer.zip"
          object_version = "consumer-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
        evaluator = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/message_evaluator.zip"
          object_version = "evaluator-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
      }
      users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
      devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
      deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
      assessment_alias_arn      = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live"
      cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
      cognito_app_client_id     = "testclient"
    }
  }
  expect_failures = [var.deployment]
}

run "mutable_artifact_rejected" {
  command = plan
  variables {
    deployment = {
      artifacts = {
        consumer = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_consumer.zip"
          object_version = "null"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
        evaluator = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_evaluator.zip"
          object_version = "evaluator-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
      }
      users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
      devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
      deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
      assessment_alias_arn      = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live"
      cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
      cognito_app_client_id     = "testclient"
    }
  }
  expect_failures = [var.deployment]
}

run "foreign_dependency_account_rejected" {
  command = plan
  variables {
    enabled = true
    deployment = {
      artifacts = {
        consumer = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_consumer.zip"
          object_version = "consumer-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
        evaluator = {
          bucket         = "trustcheckradar-dev-107827791950-artifacts"
          key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_evaluator.zip"
          object_version = "evaluator-version"
          source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
      }
      users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
      devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
      deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:999999999999:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
      assessment_alias_arn      = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live"
      cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
      cognito_app_client_id     = "testclient"
    }
  }
  expect_failures = [aws_iam_role_policy.consumer]
}
