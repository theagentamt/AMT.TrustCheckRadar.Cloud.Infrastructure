mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::107827791950:role/inactive-play-candidate" } }
  mock_resource "aws_lambda_function" { defaults = { version = "1" } }
}
variables {
  environment = "dev"
  deployment = {
    artifact = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/v1_play_handoff.zip"
      object_version = "synthetic-version"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
    users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
    authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
    authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-AbC123"
    google_play_secret_arn    = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/google-play-service-account-AbC123"
    cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
    cognito_app_client_id     = "testclient"
    package_name              = "com.andmorethings.trustcheckradar"
    product_id                = "trustcheck_radar_pro_monthly"
    base_plan_id              = "pro-monthly"
  }
}
run "default_provisions_nothing" {
  command = apply
  assert {
    condition     = length(aws_lambda_function.runtime) == 0 && length(aws_iam_role.runtime) == 0 && !output.candidate_contract.provisioned && !output.candidate_contract.route_published
    error_message = "Default configuration must not create a runtime or public route."
  }
}
run "candidate_has_no_activation_surface" {
  command = apply
  variables { enabled = true }
  assert {
    condition = (
      aws_lambda_function.runtime[0].environment[0].variables.PLAY_HANDOFF_ENABLED == "false" &&
      aws_lambda_function.runtime[0].environment[0].variables.AUTHORITY_ENABLED == "false" &&
      aws_lambda_function.runtime[0].environment[0].variables.PLAY_CATALOG_P1M_VERIFIED == "false" &&
      aws_lambda_function.runtime[0].environment[0].variables.PLAY_REQUIRE_TEST_PURCHASES == "true" &&
      aws_lambda_function.runtime[0].environment[0].variables.DEV_SUBJECT_ALLOWLIST_JSON == "[]" &&
      !output.candidate_contract.general_customer_access && !output.candidate_contract.route_published
    )
    error_message = "Provisioning must not enable grants, claim catalog verification or publish an unqualified route."
  }
  assert {
    condition = (
      aws_lambda_function.runtime[0].runtime == "python3.14" &&
      aws_lambda_function.runtime[0].architectures == tolist(["arm64"]) &&
      aws_lambda_function.runtime[0].handler == "v1_play_handoff.app.lambda_handler" &&
      aws_lambda_function.runtime[0].timeout == 29 &&
      aws_lambda_function.runtime[0].reserved_concurrent_executions == 2 &&
      aws_lambda_function_event_invoke_config.runtime[0].maximum_retry_attempts == 0
    )
    error_message = "Runtime work and implicit async retries must remain bounded."
  }
  assert {
    condition = alltrue([for s in jsondecode(aws_iam_role_policy.runtime[0].policy).Statement :
      s.Effect != "Allow" || !try(contains(s.Action, "dynamodb:PutItem"), false) || (
        s.Resource == var.deployment.authority_table_arn &&
        s.Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"] &&
        toset(s.Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"]) == toset(["V1#*#*", "TOKEN#*", "USER#*"])
      )
    ])
    error_message = "Purchase writes must be transactional and exclude both ownership and authority inventory controls."
  }
  assert {
    condition = alltrue([for s in jsondecode(aws_iam_role_policy.runtime[0].policy).Statement :
      s.Effect != "Allow" || try(s.Action != "secretsmanager:GetSecretValue", true) || (
        toset(s.Resource) == toset([var.deployment.authority_hmac_secret_arn, var.deployment.google_play_secret_arn]) &&
        s.Condition.StringEquals["secretsmanager:VersionStage"] == "AWSCURRENT"
      )
    ])
    error_message = "Only the two exact existing current secrets may be read."
  }
  assert {
    condition = anytrue([for s in jsondecode(aws_iam_role_policy.runtime[0].policy).Statement :
      s.Effect == "Deny" && try(alltrue([for a in ["lambda:InvokeFunction", "s3:*", "ssm:*", "sts:AssumeRole", "dynamodb:Scan", "dynamodb:Query", "dynamodb:DeleteItem", "dynamodb:UpdateItem"] : contains(s.Action, a)]), false)
    ])
    error_message = "The verifier cannot enumerate/delete storage, invoke other Lambdas or chain roles."
  }
  assert {
    condition     = aws_lambda_function.runtime[0].environment[0].variables.GOOGLE_PLAY_PACKAGE_NAME == "com.andmorethings.trustcheckradar" && aws_lambda_function.runtime[0].environment[0].variables.GOOGLE_PLAY_BILLING_PERIOD == "P1M"
    error_message = "Use the owner-confirmed app identity and monthly plan, never client-supplied store configuration."
  }
}
run "uat_provisioning_rejected" {
  command = plan
  variables {
    enabled     = true
    environment = "uat"
  }
  expect_failures = [var.enabled]
}
run "prod_provisioning_rejected" {
  command = plan
  variables {
    enabled     = true
    environment = "prod"
  }
  expect_failures = [var.enabled]
}
run "missing_release_rejected" {
  command = plan
  variables {
    enabled    = true
    deployment = null
  }
  expect_failures = [var.enabled]
}
run "other_region_rejected" {
  command = plan
  variables {
    enabled    = true
    aws_region = "us-west-2"
  }
  expect_failures = [var.enabled]
}

run "optional_runtime_alerts_are_bounded" {
  command = apply
  variables {
    enabled         = true
    alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
  }
  assert {
    condition = toset(output.candidate_contract.runtime_alarm_names) == toset([
      "trustcheckradar-dev-v1-play-handoff-errors", "trustcheckradar-dev-v1-play-handoff-throttles"
      ]) && alltrue([for alarm in aws_cloudwatch_metric_alarm.runtime :
      alarm.alarm_actions == toset([var.alert_topic_arn]) &&
      alarm.namespace == "AWS/Lambda" && alarm.dimensions.FunctionName == aws_lambda_function.runtime[0].function_name
    ])
    error_message = "Native runtime alarms must use the exact existing support topic and candidate function."
  }
}

run "authenticated_route_keeps_purchase_gates_closed" {
  command = apply
  variables {
    enabled              = true
    catalog_p1m_verified = true
    api_gateway = {
      api_id        = "icuak34th9"
      execution_arn = "arn:aws:execute-api:us-east-1:107827791950:icuak34th9"
      stage_name    = "$default"
    }
  }
  assert {
    condition = (
      aws_apigatewayv2_route.play[0].route_key == "POST /v1/purchases/google-play/verify" &&
      aws_apigatewayv2_route.play[0].authorization_type == "JWT" &&
      aws_apigatewayv2_route.play[0].authorization_scopes == toset(["aws.cognito.signin.user.admin"]) &&
      aws_apigatewayv2_authorizer.play[0].jwt_configuration[0].audience == toset([var.deployment.cognito_app_client_id]) &&
      aws_apigatewayv2_authorizer.play[0].jwt_configuration[0].issuer == var.deployment.cognito_issuer &&
      aws_apigatewayv2_integration.play[0].payload_format_version == "2.0" &&
      aws_apigatewayv2_integration.play[0].timeout_milliseconds == 29000 &&
      aws_lambda_permission.play[0].qualifier == "live" &&
      aws_lambda_permission.play[0].source_account == "107827791950" &&
      aws_lambda_permission.play[0].source_arn == "arn:aws:execute-api:us-east-1:107827791950:icuak34th9/$default/POST/v1/purchases/google-play/verify"
    )
    error_message = "The purchase route must bind access-token JWT identity and the exact same-account API/stage/method/path/live alias."
  }
  assert {
    condition = (
      output.candidate_contract.route_published && output.candidate_contract.catalog_verified &&
      output.candidate_contract.endpoint == "https://icuak34th9.execute-api.us-east-1.amazonaws.com/v1/purchases/google-play/verify" &&
      aws_lambda_function.runtime[0].environment[0].variables.PLAY_CATALOG_P1M_VERIFIED == "true" &&
      aws_lambda_function.runtime[0].environment[0].variables.PLAY_HANDOFF_ENABLED == "false" &&
      aws_lambda_function.runtime[0].environment[0].variables.AUTHORITY_ENABLED == "false" &&
      aws_lambda_function.runtime[0].environment[0].variables.DEV_SUBJECT_ALLOWLIST_JSON == "[]"
    )
    error_message = "Catalog verification and authenticated routing must not activate paid access."
  }
}
run "other_gateway_rejected" {
  command = plan
  variables {
    api_gateway = { api_id = "abcdefghij", execution_arn = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij", stage_name = "$default" }
  }
  expect_failures = [var.api_gateway]
}

run "closed_lifecycle_preparation_is_scoped" {
  command = apply
  variables {
    enabled = true
    lifecycle_storage = { table_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens", kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111" }
    api_gateway = { api_id = "icuak34th9", execution_arn = "arn:aws:execute-api:us-east-1:107827791950:icuak34th9", stage_name = "$default" }
  }
  assert {
    condition = aws_lambda_function.runtime[0].environment[0].variables.PLAY_PREPARATION_ENABLED == "false" && aws_lambda_function.runtime[0].environment[0].variables.PLAY_LIFECYCLE_ENABLED == "false" && aws_apigatewayv2_route.prepare[0].authorization_type == "JWT" && aws_apigatewayv2_route.prepare[0].authorization_scopes == toset(["aws.cognito.signin.user.admin"]) && aws_lambda_permission.prepare[0].source_arn == "arn:aws:execute-api:us-east-1:107827791950:icuak34th9/$default/POST/v1/purchases/google-play/prepare" && aws_lambda_permission.prepare[0].qualifier == "live"
    error_message = "Preparation must require the same authenticated active-account route while remaining disabled."
  }
  assert {
    condition = alltrue([for statement in jsondecode(aws_iam_role_policy.lifecycle[0].policy).Statement : statement.Effect != "Allow" || !contains(statement.Action, "dynamodb:PutItem") || (statement.Resource == var.lifecycle_storage.table_arn && statement.Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"] && toset(statement.Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"]) == toset(["V1#*#*", "PLAY_BINDING#*"]))]) && alltrue([for statement in jsondecode(aws_iam_role_policy.lifecycle[0].policy).Statement : statement.Effect != "Allow" || !contains(statement.Action, "kms:Decrypt")])
    error_message = "Foreground may atomically prepare its binding/encrypt a verified token but cannot decrypt or write control records."
  }
  assert {
    condition = alltrue([for statement in jsondecode(aws_iam_role_policy.lifecycle[0].policy).Statement : statement.Effect != "Deny" || !strcontains(jsonencode(statement.Action), "kms:") || statement.Resource == var.lifecycle_storage.kms_key_arn])
    error_message = "The explicit token decrypt denial must leave the required Secrets Manager credential-decryption path available."
  }
}
run "reject_other_lifecycle_table" {
  command = plan
  variables {
    enabled = true
    lifecycle_storage = { table_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/other", kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111" }
  }
  expect_failures = [var.lifecycle_storage]
}
