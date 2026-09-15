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
    analysis_abuse_control_table_name = "trustcheckradar-dev-analysis-abuse-control"
    analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-analysis-abuse-control"
    purchase_entitlements_table_name  = "entitlements"
    purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/entitlements"
    device_bindings_table_name        = "trustcheckradar-dev-device-bindings"
    device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    web_risk_cache_table_name         = "web-risk-cache"
    web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/web-risk-cache"
    device_recovery_control = {
      schema_version = 1
      enabled        = true
      environment    = "dev"
      table_name     = "trustcheckradar-dev-device-recovery-control"
      table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-recovery-control"
      ttl_attribute  = "expiresAt"
      policy = {
        approved               = true
        approval_reference     = "synthetic-test-not-user-approval"
        audit_retention_days   = 90
        receipt_retention_days = 7
        rate_retention_hours   = 24
        pitr_days              = 7
      }
    }
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
      (!contains(statement.actions, "dynamodb:DeleteItem") || contains(["EraseFencedUserDeviceBindings", "ReadCommandAndWriteRevocationReceipt", "MinimizeFencedUserRecoveryEvidence", "EnumerateAndEraseFencedAnalysisState"], statement.sid)) &&
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

run "recovery_cleanup_has_exact_scope_and_approved_retention" {
  command = plan
  assert {
    condition = (
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "MinimizeFencedUserRecoveryEvidence"]).actions == toset(["dynamodb:Query", "dynamodb:PutItem", "dynamodb:DeleteItem"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "MinimizeFencedUserRecoveryEvidence"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-recovery-control"]) &&
      anytrue([for c in one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "MinimizeFencedUserRecoveryEvidence"]).condition :
        c.test == "ForAllValues:StringLike" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["USER#*"])
      ]) &&
      aws_lambda_function.account_data[0].environment[0].variables["DEVICE_RECOVERY_CONTROL_TABLE_NAME"] == "trustcheckradar-dev-device-recovery-control" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_RECOVERY_DELETE_PAGE_SIZE"] == "100" &&
      aws_lambda_function.account_data[0].environment[0].variables["DEVICE_RECOVERY_RECEIPT_RETENTION_DAYS"] == "7" &&
      aws_lambda_function.account_data[0].environment[0].variables["DEVICE_RECOVERY_AUDIT_RETENTION_DAYS"] == "90" &&
      aws_lambda_function.account_data[0].environment[0].variables["DEVICE_RECOVERY_RATE_STATE_TTL_SECONDS"] == "86400" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_RECEIPT_RETENTION_DAYS"] == "120" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_ENABLED"] == "false"
    )
    error_message = "Recovery cleanup needs bounded USER-partition access and approved retention without activating deletion."
  }
}

run "analysis_cleanup_permissions_and_policy_gates_are_separate" {
  command = plan
  assert {
    condition = (
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "EnumerateAndEraseFencedAnalysisState"]).actions == toset(["dynamodb:Query", "dynamodb:DeleteItem"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "MinimizeAnalysisRequestContent"]).actions == toset(["dynamodb:PutItem"]) &&
      alltrue([for s in data.aws_iam_policy_document.account_data[0].statement :
        !contains(["EnumerateAndEraseFencedAnalysisState", "MinimizeAnalysisRequestContent"], s.sid) ? true :
        s.resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-analysis-abuse-control"]) &&
        anytrue([for c in s.condition :
          c.test == "ForAllValues:StringLike" && c.variable == "dynamodb:LeadingKeys" &&
          toset(c.values) == (s.sid == "MinimizeAnalysisRequestContent" ? toset(["ANALYSIS#REQUEST#*"]) : toset(["ANALYSIS#REQUEST#*", "ANALYSIS#RATE#*", "ANALYSIS#SCAN_RATE#*", "ANALYSIS#CONSUMPTION#*"]))
        ])
      ]) &&
      aws_lambda_function.account_data[0].environment[0].variables["ANALYSIS_ABUSE_TABLE_NAME"] == "trustcheckradar-dev-analysis-abuse-control" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_ANALYSIS_ABUSE_PAGE_SIZE"] == "100" &&
      aws_lambda_function.account_data[0].environment[0].variables["ANALYSIS_REQUEST_ID_TTL_SECONDS"] == "900" &&
      aws_lambda_function.account_data[0].environment[0].variables["HISTORY_DEDUP_RETENTION_DAYS"] == "120" &&
      alltrue([for key in ["ANALYSIS_REQUEST_DEDUPE_POLICY_STATUS", "ANALYSIS_LEGACY_REQUEST_RETENTION_POLICY_STATUS", "ANALYSIS_CONSUMPTION_DELETION_POLICY_STATUS"] :
        aws_lambda_function.account_data[0].environment[0].variables[key] == "pending"
      ]) &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_ENABLED"] == "false"
    )
    error_message = "Analysis cleanup needs exact family-scoped IAM while independent unapproved policies remain pending."
  }
}

run "age_attestation_candidate_is_pinned_with_atomic_ledger_fence" {
  command = plan
  variables {
    account_data_deployment = null
    profile_fence_deployment = {
      release_id         = "profile-candidate", object_version = "age-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = false
    }
    age_attestation_lambda_env = { DELETION_LEDGER_TABLE_NAME = "wrong-table" }
  }
  assert {
    condition = (
      aws_lambda_function.age_attestation.s3_key == "releases/profile-candidate/age_attestation.zip" &&
      aws_lambda_function.age_attestation.s3_object_version == "age-version" &&
      aws_lambda_function.age_attestation.source_code_hash == var.profile_fence_deployment.source_hash &&
      aws_lambda_function.age_attestation.environment[0].variables["DELETION_LEDGER_TABLE_NAME"] == "trustcheckradar-dev-deletion-ledger" &&
      one([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement : statement if statement.sid == "UsersTableReadUpdate"]).actions == toset(["dynamodb:UpdateItem"]) &&
      one([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement : statement if statement.sid == "PreventDeletedProfileReactivation"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"]) &&
      alltrue([for statement in data.aws_iam_policy_document.age_attestation_dynamodb.statement :
        anytrue([for condition in statement.condition : condition.variable == "dynamodb:EnclosingOperation" && toset(condition.values) == toset(["TransactWriteItems"])])
      ])
    )
    error_message = "Age attestation must update the profile only transactionally with the authoritative deletion fence and pinned corrected package."
  }
}

run "default_age_attestation_remains_unchanged" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.age_attestation.s3_key == "releases/existing-release/age_attestation.zip" &&
      length(data.aws_iam_policy_document.age_attestation_dynamodb.statement) == 1 &&
      !output.profile_fence_contract.age_attestation_fenced
    )
    error_message = "Adding the candidate must not silently migrate the existing age-attestation writer."
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
  assert {
    condition = (
      !local.recovery_storage_valid &&
      alltrue([for s in data.aws_iam_policy_document.account_data[0].statement : s.sid != "MinimizeFencedUserRecoveryEvidence"])
    )
    error_message = "Invalid recovery storage must not supply a table name or cleanup IAM grant."
  }
}
