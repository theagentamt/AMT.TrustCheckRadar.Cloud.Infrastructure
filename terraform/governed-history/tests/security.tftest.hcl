mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::107827791950:role/governed-history-test" } }
  mock_resource "aws_lambda_function" { defaults = { version = "1" } }
  mock_resource "aws_lambda_alias" { defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-governed-history:live", invoke_arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-governed-history:live" } }
}
variables {
  environment = "dev"
  deployment = {
    artifacts = { reader = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/governed_history.zip"
      object_version = "reader-version"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    } }
    users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
    authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
    authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
    cognito_app_client_id     = "testclient"
  }
  api_gateway = { api_id = "icuak34th9", execution_arn = "arn:aws:execute-api:us-east-1:107827791950:icuak34th9", authorizer_id = "itms4b" }
}
run "default_provisions_nothing" {
  command = plan
  assert {
    condition     = length(aws_lambda_function.runtime) == 0 && length(aws_apigatewayv2_route.history) == 0 && !output.governed_history_contract.list_enabled && !output.governed_history_contract.detail_enabled
    error_message = "Default module must create no runtime or routes and enable no capability."
  }
}
run "provisioned_reader_is_inactive_and_read_only" {
  command = apply
  variables { enabled = true }
  assert {
    condition     = !output.governed_history_contract.hmac_key_material_in_state && !contains(keys(output.governed_history_contract), "secrets_in_state")
    error_message = "State privacy must describe HMAC key material precisely, not overclaim all secret-sourced values. Private subject identifiers and derived partitions enter state."
  }
  assert {
    condition     = aws_lambda_function.runtime["reader"].runtime == "python3.14" && toset(aws_lambda_function.runtime["reader"].architectures) == toset(["arm64"]) && aws_lambda_function.runtime["reader"].environment[0].variables.AUTHORITY_ENABLED == "false" && aws_lambda_function.runtime["reader"].environment[0].variables.GOVERNED_HISTORY_LIST_ENABLED == "false" && aws_lambda_function.runtime["reader"].environment[0].variables.GOVERNED_HISTORY_DETAIL_ENABLED == "false" && length(aws_apigatewayv2_route.history) == 2 && alltrue([for route in aws_apigatewayv2_route.history : route.authorization_type == "JWT" && route.authorizer_id == "itms4b" && route.authorization_scopes == toset(["aws.cognito.signin.user.admin"])])
    error_message = "Inactive immutable Python3.14 reader must own only JWT protected list and detail routes."
  }
  assert {
    condition     = length(jsondecode(aws_iam_role_policy.reader[0].policy).Statement) == 2 && jsondecode(aws_iam_role_policy.reader[0].policy).Statement[0].Sid == "OwnLogs" && jsondecode(aws_iam_role_policy.reader[0].policy).Statement[1].Effect == "Deny" && contains(jsondecode(aws_iam_role_policy.reader[0].policy).Statement[1].Action, "dynamodb:Scan") && contains(jsondecode(aws_iam_role_policy.reader[0].policy).Statement[1].Action, "lambda:InvokeFunction")
    error_message = "Inactive reader role must have only logs and explicit denies, with no keyring, receipt or identity read grants."
  }
}
run "list_can_activate_without_detail_or_unrelated_capabilities" {
  command = apply
  variables {
    enabled              = true
    list_enabled         = true
    index_ready          = true
    authority_partitions = ["V1#test#aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]
    engineering_subjects = ["11111111-1111-4111-8111-111111111111"]
  }
  assert {
    condition     = aws_lambda_function.runtime["reader"].environment[0].variables.GOVERNED_HISTORY_LIST_ENABLED == "true" && aws_lambda_function.runtime["reader"].environment[0].variables.GOVERNED_HISTORY_DETAIL_ENABLED == "false" && length([for key in keys(aws_lambda_function.runtime["reader"].environment[0].variables) : key if startswith(key, "HISTORY_") || startswith(key, "BILLING_") || startswith(key, "EXPORT_") || startswith(key, "DELETION_") && key != "DELETION_LEDGER_TABLE_NAME"]) == 0 && !output.governed_history_contract.provider_calls_enabled && !output.governed_history_contract.legacy_history_gates_changed
    error_message = "List activation cannot open detail, legacy History export, billing or deletion admission."
  }
}
run "active_reader_iam_is_subject_partition_and_attribute_scoped" {
  command = apply
  variables {
    enabled              = true
    list_enabled         = true
    index_ready          = true
    engineering_subjects = ["11111111-1111-4111-8111-111111111111"]
    authority_partitions = ["V1#test#aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.reader[0].policy).Statement[5].Resource == "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements/index/GSI2" && jsondecode(aws_iam_role_policy.reader[0].policy).Statement[5].Condition.StringEquals["dynamodb:Select"] == "SPECIFIC_ATTRIBUTES" && alltrue([for statement in slice(jsondecode(aws_iam_role_policy.reader[0].policy).Statement, 1, 6) : statement.Condition.Null["dynamodb:Attributes"] == "false" && statement.Condition.Null["dynamodb:LeadingKeys"] == "false"]) && jsondecode(aws_iam_role_policy.reader[0].policy).Statement[1].Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"] == ["USER#11111111-1111-4111-8111-111111111111"]
    error_message = "Active reader must require exact account keys, explicit bounded attributes and specific index selection."
  }
}

run "detail_can_activate_without_list" {
  command = apply
  variables {
    enabled              = true
    detail_enabled       = true
    index_ready          = true
    authority_partitions = ["V1#test#aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]
    engineering_subjects = ["11111111-1111-4111-8111-111111111111"]
  }
  assert {
    condition     = !output.governed_history_contract.list_enabled && output.governed_history_contract.detail_enabled
    error_message = "Detail must be gated independently from listing."
  }
}
run "missing_index_is_rejected" {
  command = plan
  variables {
    enabled              = true
    list_enabled         = true
    engineering_subjects = ["11111111-1111-4111-8111-111111111111"]
  }
  expect_failures = [var.list_enabled]
}
run "missing_subject_is_rejected" {
  command = plan
  variables {
    enabled        = true
    detail_enabled = true
    index_ready    = true
  }
  expect_failures = [var.detail_enabled]
}
run "uat_provision_is_rejected" {
  command = plan
  variables {
    environment = "uat"
    enabled     = true
    deployment  = null
  }
  expect_failures = [var.enabled]
}
