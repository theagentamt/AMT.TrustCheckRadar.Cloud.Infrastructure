mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  aws_region          = "us-east-1"
  project_name        = "trustcheckradar"
  environment         = "dev"
  state_bucket_name   = "synthetic-state"
  state_bucket_region = "us-east-1"
  artifact_release    = "existing-release"
  account_data_deployment = {
    release_id         = "synthetic-candidate"
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
    users_table_name                  = "trustcheckradar-dev-users"
    users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    deletion_ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
    deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
    deletion_ledger_stream_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-14T00:00:00.000"
    analysis_abuse_control_table_name = "analysis-abuse"
    analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/analysis-abuse"
    purchase_entitlements_table_name  = "entitlements"
    purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/entitlements"
    device_bindings_table_name        = "trustcheckradar-dev-device-bindings"
    device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    web_risk_cache_table_name         = "web-risk-cache"
    web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/web-risk-cache"
  } } }
}

run "default_creates_no_account_data_resources" {
  command = plan
  variables { account_data_deployment = null }
  assert {
    condition = (
      length(aws_lambda_function.account_data) == 0 &&
      length(aws_iam_role_policy.account_data) == 0 &&
      length(aws_lambda_event_source_mapping.account_data_revocation) == 0 &&
      length(aws_cloudwatch_event_rule.account_data_reconcile) == 0 &&
      !output.account_data_candidate_contract.deployed
    )
    error_message = "Account data must remain opt-in without IAM grants or event consumers by default."
  }
}

run "candidate_is_immutable_private_and_fail_closed" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.account_data[0].s3_key == "releases/synthetic-candidate/account_data_api.zip" &&
      aws_lambda_function.account_data[0].s3_object_version == "synthetic-version" &&
      aws_lambda_function.account_data[0].source_code_hash == var.account_data_deployment.source_hash &&
      aws_lambda_function.account_data[0].reserved_concurrent_executions == 1 &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_ENABLED"] == "false" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_POLICY_STATUS"] == "pending" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DATA_INVENTORY_STATUS"] == "pending" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_COMPLETION_STATUS"] == "incomplete" &&
      aws_lambda_function.account_data[0].environment[0].variables["COGNITO_USERNAME_IS_SUB"] == "false" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_REQUIRED_COMPONENTS_JSON"] == "[]" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_MAX_REAUTH_AGE_SECONDS"] == "300" &&
      length(output.account_data_candidate_contract.routes) == 0 &&
      !output.account_data_candidate_contract.enabled &&
      !output.account_data_candidate_contract.full_account_export_available &&
      !output.account_data_candidate_contract.overall_deletion_completion_available
    )
    error_message = "A candidate must not approve inventory, assume Cognito identity mapping, expose routes or accept account deletion."
  }
  assert {
    condition = (
      !aws_lambda_event_source_mapping.account_data_revocation[0].enabled &&
      aws_lambda_event_source_mapping.account_data_revocation[0].function_response_types == toset(["ReportBatchItemFailures"]) &&
      aws_lambda_event_source_mapping.account_data_revocation[0].starting_position == "TRIM_HORIZON" &&
      aws_lambda_event_source_mapping.account_data_revocation[0].maximum_retry_attempts == -1 &&
      aws_lambda_event_source_mapping.account_data_revocation[0].bisect_batch_on_function_error &&
      one(one(aws_lambda_event_source_mapping.account_data_revocation[0].filter_criteria).filter).pattern == jsonencode({
        eventName = ["INSERT", "MODIFY"]
        dynamodb = { NewImage = {
          PK            = { S = [{ prefix = "ACCOUNT#" }] }
          SK            = { S = ["ACCOUNT_DELETION"] }
          eventType     = { S = ["account.deletion.requested"] }
          environment   = { S = ["dev"] }
          schemaVersion = { N = ["1"] }
          status        = { S = ["REQUESTED"] }
        } }
      })
    )
    error_message = "The disabled revocation consumer must exclude receipt recursion and support DynamoDB partial-batch retries."
  }
}

run "account_data_permissions_scope_device_cleanup_and_reconciliation" {
  command = plan
  assert {
    condition = alltrue([for statement in data.aws_iam_policy_document.account_data[0].statement :
      (!contains(statement.actions, "dynamodb:Scan") || (statement.sid == "ReconcileMissedRevocations" && statement.resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"]))) &&
      (!contains(statement.actions, "dynamodb:DeleteItem") || contains(["EraseFencedUserDeviceBindings", "ReadCommandAndWriteRevocationReceipt"], statement.sid)) &&
      !contains(statement.actions, "cognito-idp:AdminDeleteUser") && !contains(statement.actions, "*")
      ]) && (
      one([for statement in data.aws_iam_policy_document.account_data[0].statement : statement if statement.sid == "RevokeSessionsInOwnPool"]).resources == toset(["arn:aws:cognito-idp:us-east-1:107827791950:userpool/us-east-1_example"]) &&
      one([for statement in data.aws_iam_policy_document.account_data[0].statement : statement if statement.sid == "TransactionallyFenceAuthoritativeProfile"]).actions == toset(["dynamodb:UpdateItem"]) &&
      anytrue([for condition in one([for statement in data.aws_iam_policy_document.account_data[0].statement : statement if statement.sid == "TransactionallyFenceAuthoritativeProfile"]).condition :
        condition.variable == "dynamodb:EnclosingOperation" && toset(condition.values) == toset(["TransactWriteItems"])
      ])
    )
    error_message = "Account-data IAM must fence profiles transactionally and revoke only its own pool, without broad deletion or scanning."
  }
}

run "account_reconciliation_remains_disabled_and_bounded" {
  command = plan
  assert {
    condition = (
      aws_cloudwatch_event_rule.account_data_reconcile[0].state == "DISABLED" &&
      aws_cloudwatch_event_rule.account_data_reconcile[0].schedule_expression == "rate(5 minutes)" &&
      aws_cloudwatch_event_target.account_data_reconcile[0].input == jsonencode({ schemaVersion = 1, operation = "reconcile-session-revocation" }) &&
      aws_lambda_permission.account_data_reconcile[0].principal == "events.amazonaws.com" &&
      aws_lambda_function_event_invoke_config.account_data_reconcile[0].maximum_event_age_in_seconds == 300 &&
      aws_lambda_function_event_invoke_config.account_data_reconcile[0].maximum_retry_attempts == 1 &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_RECONCILIATION_SCAN_LIMIT"] == "100" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_RECONCILIATION_MAX_PAGES"] == "10" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_DEVICE_DELETE_PAGE_SIZE"] == "100" &&
      one([for statement in data.aws_iam_policy_document.account_data[0].statement : statement if statement.sid == "EraseFencedUserDeviceBindings"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"])
    )
    error_message = "Reconciliation must stay disabled, bounded, and limited to its own device table and deletion ledger."
  }
}

run "mutable_account_data_artifact_is_rejected" {
  command = plan
  variables {
    account_data_deployment = {
      release_id         = "synthetic-candidate", object_version = "null", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = false
    }
  }
  expect_failures = [var.account_data_deployment]
}

run "another_environment_cannot_use_dev_account_data" {
  command = plan
  variables {
    environment = "uat"
    account_data_deployment = {
      release_id         = "synthetic-candidate", object_version = "version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = true
    }
  }
  expect_failures = [aws_lambda_function.account_data]
}
