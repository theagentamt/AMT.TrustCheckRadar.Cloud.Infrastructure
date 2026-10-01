mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
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
    purchase_entitlements_table_name  = "trustcheckradar-dev-purchase-entitlements"
    purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
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
      length(aws_cloudwatch_metric_alarm.account_data_function) == 0 &&
      length(aws_cloudwatch_metric_alarm.account_data_reconciliation) == 0 &&
      length(aws_cloudwatch_metric_alarm.account_data_stream_failure) == 0 &&
      !output.account_data_candidate_contract.deployed
    )
    error_message = "Account data must remain opt-in without IAM grants or event consumers by default."
  }
}

run "candidate_monitoring_is_opt_in" {
  command = plan
  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.account_data_function) == 0 &&
      length(aws_cloudwatch_metric_alarm.account_data_reconciliation) == 0 &&
      length(aws_cloudwatch_metric_alarm.account_data_stream_failure) == 0
    )
    error_message = "A disabled candidate must not silently add monitoring cost or a notification destination."
  }
}

run "stream_discovery_is_regional_and_reads_are_exact" {
  command = plan
  assert {
    condition = (
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "ReadOwnDeletionStream"]).actions == toset(["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "ReadOwnDeletionStream"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-14T00:00:00.000"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "DiscoverDeletionStreamsInRegion"]).actions == toset(["dynamodb:ListStreams"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "DiscoverDeletionStreamsInRegion"]).resources == toset(["*"]) &&
      one(one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "DiscoverDeletionStreamsInRegion"]).condition).variable == "aws:RequestedRegion" &&
      one(one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "DiscoverDeletionStreamsInRegion"]).condition).values == tolist(["us-east-1"])
    )
    error_message = "ListStreams needs regional discovery permission; stream content reads must stay restricted to the exact deletion stream."
  }
}

run "account_monitoring_uses_source_metrics_without_activating_workers" {
  command = plan
  variables {
    account_data_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts" }
  }
  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.account_data_function) == 3 &&
      length(aws_cloudwatch_metric_alarm.account_data_reconciliation) == 9 &&
      length(aws_cloudwatch_metric_alarm.account_data_stream_failure) == 1 &&
      alltrue([for alarm in aws_cloudwatch_metric_alarm.account_data_function :
        alarm.namespace == "AWS/Lambda" &&
        alarm.dimensions == tomap({ FunctionName = "trustcheckradar-dev-account-data-api" }) &&
        alarm.treat_missing_data == "notBreaching" &&
        alarm.alarm_actions == toset([var.account_data_monitoring.alarm_topic_arn]) &&
        alarm.ok_actions == toset([var.account_data_monitoring.alarm_topic_arn])
      ]) &&
      aws_cloudwatch_metric_alarm.account_data_function["lag"].unit == "Milliseconds" &&
      aws_cloudwatch_metric_alarm.account_data_function["lag"].threshold == 300000 &&
      alltrue([for alarm in aws_cloudwatch_metric_alarm.account_data_reconciliation :
        alarm.namespace == "AMT/TrustCheckRadar/AccountData" &&
        alarm.dimensions == tomap({ Environment = "dev" }) &&
        alarm.alarm_actions == toset([var.account_data_monitoring.alarm_topic_arn])
      ]) &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["heartbeat"].metric_name == "SessionRevocationReconciliationSuccess" &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["heartbeat"].evaluation_periods == 3 &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["no_full_pass"].period == 21600 &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["stale_full_pass"].unit == "Seconds" &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["stale_full_pass"].threshold == 21600 &&
      alltrue([for key in ["heartbeat", "no_full_pass", "stale_full_pass"] :
        !aws_cloudwatch_metric_alarm.account_data_reconciliation[key].actions_enabled &&
        aws_cloudwatch_metric_alarm.account_data_reconciliation[key].treat_missing_data == "notBreaching"
      ]) &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["failure"].actions_enabled &&
      alltrue([for key in ["command_failure", "pass_failure"] :
        aws_cloudwatch_metric_alarm.account_data_reconciliation[key].actions_enabled &&
        aws_cloudwatch_metric_alarm.account_data_reconciliation[key].period == 300 &&
        aws_cloudwatch_metric_alarm.account_data_reconciliation[key].threshold == 0 &&
        aws_cloudwatch_metric_alarm.account_data_reconciliation[key].treat_missing_data == "notBreaching"
      ]) &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["command_failure"].metric_name == "AccountDeletionReconciliationCommandFailures" &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["pass_failure"].metric_name == "AccountDeletionReconciliationPassFailures" &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["policy_blocked"].actions_enabled &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["policy_blocked"].metric_name == "AccountDeletionAnalysisAbusePolicyBlocked" &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["outbox_blocked"].metric_name == "AccountDeletionCampaignOutboxPolicyBlocked" &&
      aws_cloudwatch_metric_alarm.account_data_reconciliation["profile_blocked"].metric_name == "AccountDeletionUserProfilePolicyBlocked" &&
      aws_cloudwatch_metric_alarm.account_data_stream_failure[0].metric_name == "AccountDeletionFailure" &&
      aws_cloudwatch_metric_alarm.account_data_stream_failure[0].dimensions == tomap({ Environment = "dev", Operation = "session-revocation" }) &&
      aws_cloudwatch_event_rule.account_data_reconcile[0].state == "DISABLED" &&
      !aws_lambda_event_source_mapping.account_data_revocation[0].enabled &&
      !output.account_data_candidate_contract.enabled
    )
    error_message = "Monitoring must match emitted metrics, cover partial batch failures and suppress scheduled-heartbeat actions for disabled candidates."
  }
}

run "monitoring_rejects_missing_candidate" {
  command = plan
  variables {
    account_data_deployment = null
    account_data_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts" }
  }
  expect_failures = [var.account_data_monitoring]
}

run "monitoring_rejects_cross_account_topic" {
  command = plan
  variables { account_data_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:111111111111:synthetic-alerts" } }
  expect_failures = [var.account_data_monitoring]
}

run "monitoring_rejects_cross_region_topic" {
  command = plan
  variables { account_data_monitoring = { alarm_topic_arn = "arn:aws:sns:us-west-2:107827791950:synthetic-alerts" } }
  expect_failures = [var.account_data_monitoring]
}

run "monitoring_rejects_fifo_topic" {
  command = plan
  variables { account_data_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts.fifo" } }
  expect_failures = [var.account_data_monitoring]
}

run "candidate_rejects_foreign_deploying_account" {
  command = plan
  override_data {
    target = data.aws_caller_identity.account_fence[0]
    values = { account_id = "111111111111" }
  }
  expect_failures = [aws_lambda_function.account_data]
}

run "candidate_is_immutable_private_and_fail_closed" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.account_data[0].s3_key == "releases/synthetic-candidate/account_data_api.zip" &&
      aws_lambda_function.account_data[0].s3_object_version == "synthetic-version" &&
      aws_lambda_function.account_data[0].source_code_hash == var.account_data_deployment.source_hash &&
      aws_lambda_function.account_data[0].reserved_concurrent_executions == 1 &&
      aws_lambda_function.account_data[0].runtime == "python3.14" &&
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
      (!contains(statement.actions, "dynamodb:DeleteItem") || contains(["EraseFencedUserDeviceBindings", "ReadCommandAndWriteRevocationReceipt", "MinimizeFencedUserRecoveryEvidence", "EnumerateAndEraseFencedAnalysisState", "EraseAccountOutboxContent", "EraseFencedUserProfileState", "EraseOwnedPurchaseTransaction"], statement.sid)) &&
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
  override_resource {
    target          = aws_cloudwatch_event_rule.account_data_reconcile[0]
    override_during = plan
    values          = { arn = "arn:aws:events:us-east-1:107827791950:rule/trustcheckradar-dev-account-deletion-reconcile" }
  }
  assert {
    condition = (
      aws_cloudwatch_event_rule.account_data_reconcile[0].state == "DISABLED" &&
      aws_cloudwatch_event_rule.account_data_reconcile[0].schedule_expression == "rate(5 minutes)" &&
      aws_cloudwatch_event_target.account_data_reconcile[0].input == jsonencode({ schemaVersion = 1, operation = "reconcile-session-revocation" }) &&
      aws_lambda_permission.account_data_reconcile[0].principal == "events.amazonaws.com" &&
      aws_lambda_permission.account_data_reconcile[0].source_account == "107827791950" &&
      aws_lambda_permission.account_data_reconcile[0].source_arn == aws_cloudwatch_event_rule.account_data_reconcile[0].arn &&
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

run "outbox_cleanup_is_subject_scoped_and_coverage_gated" {
  command = plan
  variables { campaign_intelligence_enabled = true }
  override_data {
    target = data.terraform_remote_state.campaign_data[0]
    values = { outputs = { downstream_contract = {
      schema_version        = 1, environment = "dev", enabled = true
      outbox_table_name     = "trustcheckradar-dev-campaign-outbox"
      outbox_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"
      transient_kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
    } } }
  }
  assert {
    condition = (
      aws_lambda_function.account_data[0].environment[0].variables["CAMPAIGN_OUTBOX_TABLE_NAME"] == "trustcheckradar-dev-campaign-outbox" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_CAMPAIGN_OUTBOX_PAGE_SIZE"] == "100" &&
      aws_lambda_function.account_data[0].environment[0].variables["CAMPAIGN_OUTBOX_LOCATOR_COVERAGE_STATUS"] == "pending" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_ENABLED"] == "false" &&
      alltrue([for sid, spec in {
        EnumerateAccountOutboxLocators = { actions = ["dynamodb:Query"], keys = ["ACCOUNT#*"] }
        ReadAccountOutboxTarget        = { actions = ["dynamodb:GetItem"], keys = ["EVENT#*"] }
        EraseAccountOutboxContent      = { actions = ["dynamodb:DeleteItem"], keys = ["ACCOUNT#*", "EVENT#*"] }
        } :
        one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == sid]).actions == toset(spec.actions) &&
        one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == sid]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"]) &&
        anytrue([for c in one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == sid]).condition :
          c.test == "ForAllValues:StringLike" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(spec.keys)
        ])
      ]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "DecryptAccountOutboxThroughDynamoDB"]).actions == toset(["kms:Decrypt", "kms:DescribeKey"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "DecryptAccountOutboxThroughDynamoDB"]).resources == toset(["arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"]) &&
      alltrue([for name, value in { "kms:CallerAccount" = "107827791950", "kms:ViaService" = "dynamodb.us-east-1.amazonaws.com" } :
        anytrue([for c in one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "DecryptAccountOutboxThroughDynamoDB"]).condition :
          c.test == "StringEquals" && c.variable == name && toset(c.values) == toset([value])
        ])
      ]) &&
      alltrue([for s in data.aws_iam_policy_document.account_data[0].statement :
        !contains(s.resources, "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox") ||
        (!contains(s.actions, "dynamodb:Scan") && !contains(s.actions, "dynamodb:PutItem") && !contains(s.actions, "dynamodb:UpdateItem"))
      ])
    )
    error_message = "Outbox erasure needs bounded locator queries, ownership-checked event reads/deletes and exact KMS access, without approving coverage or activation."
  }
}

run "disabled_campaign_grants_no_outbox_cleanup_access" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.account_data[0].environment[0].variables["CAMPAIGN_OUTBOX_TABLE_NAME"] == "" &&
      alltrue([for s in data.aws_iam_policy_document.account_data[0].statement :
        !contains(["EnumerateAccountOutboxLocators", "ReadAccountOutboxTarget", "EraseAccountOutboxContent", "DecryptAccountOutboxThroughDynamoDB"], s.sid)
      ])
    )
    error_message = "Disabled campaigns must not grant outbox or KMS access."
  }
}

run "outbox_cleanup_rejects_another_account" {
  command = plan
  variables { campaign_intelligence_enabled = true }
  override_data {
    target = data.terraform_remote_state.campaign_data[0]
    values = { outputs = { downstream_contract = {
      schema_version        = 1, environment = "dev", enabled = true
      outbox_table_name     = "trustcheckradar-dev-campaign-outbox"
      outbox_table_arn      = "arn:aws:dynamodb:us-east-1:111111111111:table/trustcheckradar-dev-campaign-outbox"
      transient_kms_key_arn = "arn:aws:kms:us-east-1:111111111111:key/11111111-1111-1111-1111-111111111111"
    } } }
  }
  expect_failures = [aws_lambda_function.account_data]
}

run "participation_fence_is_pinned_and_transaction_scoped" {
  command = plan
  variables {
    campaign_participation_fence_deployment = {
      release_id         = "participation-fence", object_version = "participation-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test-not-user-approval", promotion_approved = false
    }
    campaign_participation_lambda_env               = { USERS_TABLE_NAME = "wrong-users", DELETION_LEDGER_TABLE_NAME = "wrong-ledger" }
    campaign_participation_lambda_s3_bucket         = "wrong-bucket"
    campaign_participation_lambda_s3_key            = "wrong-key"
    campaign_participation_lambda_s3_object_version = "wrong-version"
  }
  assert {
    condition = (
      aws_lambda_function.campaign_participation.s3_bucket == "synthetic-artifacts" &&
      aws_lambda_function.campaign_participation.s3_key == "releases/participation-fence/campaign_participation.zip" &&
      aws_lambda_function.campaign_participation.s3_object_version == "participation-version" &&
      aws_lambda_function.campaign_participation.source_code_hash == var.campaign_participation_fence_deployment.source_hash &&
      aws_lambda_function.campaign_participation.environment[0].variables["USERS_TABLE_NAME"] == "trustcheckradar-dev-users" &&
      aws_lambda_function.campaign_participation.environment[0].variables["DELETION_LEDGER_TABLE_NAME"] == "trustcheckradar-dev-deletion-ledger" &&
      alltrue([for key, spec in {
        Users  = { arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users", pk = "USER#*" }
        Ledger = { arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger", pk = "ACCOUNT#*" }
        } :
        one([for s in data.aws_iam_policy_document.campaign_participation_runtime.statement : s if s.sid == "CheckParticipationAuthority${key}"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
        one([for s in data.aws_iam_policy_document.campaign_participation_runtime.statement : s if s.sid == "CheckParticipationAuthority${key}"]).resources == toset([spec.arn]) &&
        anytrue([for c in one([for s in data.aws_iam_policy_document.campaign_participation_runtime.statement : s if s.sid == "CheckParticipationAuthority${key}"]).condition :
          c.test == "StringEquals" && c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])
        ]) &&
        anytrue([for c in one([for s in data.aws_iam_policy_document.campaign_participation_runtime.statement : s if s.sid == "CheckParticipationAuthority${key}"]).condition :
          c.test == "ForAllValues:StringLike" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset([spec.pk])
        ])
      ]) &&
      one([for s in data.aws_iam_policy_document.campaign_participation_runtime.statement : s if s.sid == "ReadParticipationDeletionFence"]).actions == toset(["dynamodb:GetItem"])
    )
    error_message = "Participation fencing must pin its reviewed artifact, prevent env overrides, and condition-check exact subject partitions transactionally."
  }
  assert {
    condition = alltrue([for s in data.aws_iam_policy_document.campaign_participation_runtime.statement :
      !contains(s.actions, "dynamodb:PutItem") ? true :
      length(s.resources) == 1 &&
      anytrue([for c in s.condition : c.variable == "dynamodb:LeadingKeys" && c.test == "ForAllValues:StringLike" &&
        toset(c.values) == (s.sid == "WriteParticipationTransactionLedger" ? toset(["ACCOUNT#*"]) : toset(["USER#*"]))
      ]) &&
      anytrue([for c in s.condition : c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])])
    ])
    error_message = "Every pinned participation mutation must be transaction-only and constrained to the owning table's subject-key family."
  }
}

run "default_participation_does_not_select_fence_release_or_permissions" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.campaign_participation.s3_key == "releases/existing-release/campaign_participation.zip" &&
      alltrue([for s in data.aws_iam_policy_document.campaign_participation_runtime.statement :
        !startswith(s.sid, "CheckParticipationAuthority") && s.sid != "ReadParticipationDeletionFence"
      ])
    )
    error_message = "The existing participation deployment and IAM must remain unchanged without an explicit pinned release."
  }
}

run "participation_fence_rejects_mutable_artifact" {
  command = plan
  variables {
    campaign_participation_fence_deployment = {
      release_id         = "participation-fence", object_version = "null", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = false
    }
  }
  expect_failures = [var.campaign_participation_fence_deployment]
}

run "participation_fence_rejects_cross_environment_tables" {
  command = plan
  variables {
    account_data_deployment = null
    environment             = "uat"
    campaign_participation_fence_deployment = {
      release_id         = "participation-fence", object_version = "participation-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = true
    }
  }
  expect_failures = [aws_lambda_function.campaign_participation]
}

run "purchase_fence_is_pinned_and_authority_checked" {
  command = plan
  variables {
    purchase_handoff_fence_deployment = {
      release_id         = "purchase-fence", object_version = "purchase-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test-not-user-approval", promotion_approved = false
    }
    purchase_handoff_lambda_env       = { USERS_TABLE_NAME = "wrong-users", DELETION_LEDGER_TABLE_NAME = "wrong-ledger", PURCHASE_OWNERSHIP_CANDIDATE_ENABLED = "true" }
    purchase_handoff_lambda_s3_bucket = "wrong-bucket"
  }
  assert {
    condition = (
      aws_lambda_function.purchase_handoff.s3_bucket == "synthetic-artifacts" &&
      aws_lambda_function.purchase_handoff.runtime == "python3.14" &&
      aws_lambda_function.purchase_handoff.environment[0].variables["PURCHASE_OWNERSHIP_CANDIDATE_ENABLED"] == "false" &&
      aws_lambda_function.purchase_handoff.s3_key == "releases/purchase-fence/purchase_handoff.zip" &&
      aws_lambda_function.purchase_handoff.s3_object_version == "purchase-version" &&
      aws_lambda_function.purchase_handoff.source_code_hash == var.purchase_handoff_fence_deployment.source_hash &&
      aws_lambda_function.purchase_handoff.environment[0].variables["USERS_TABLE_NAME"] == "trustcheckradar-dev-users" &&
      aws_lambda_function.purchase_handoff.environment[0].variables["DELETION_LEDGER_TABLE_NAME"] == "trustcheckradar-dev-deletion-ledger" &&
      alltrue([for key, spec in {
        Users  = { arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users", pk = "USER#*" }
        Ledger = { arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger", pk = "ACCOUNT#*" }
        } :
        one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "CheckPurchaseAuthority${key}"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
        one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "CheckPurchaseAuthority${key}"]).resources == toset([spec.arn]) &&
        anytrue([for c in one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "CheckPurchaseAuthority${key}"]).condition :
          c.test == "StringEquals" && c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])
        ]) &&
        anytrue([for c in one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "CheckPurchaseAuthority${key}"]).condition :
          c.test == "ForAllValues:StringLike" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset([spec.pk])
        ])
      ]) &&
      one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "ReadPurchaseDeletionFence"]).actions == toset(["dynamodb:GetItem"])
    )
    error_message = "Purchase fencing must pin its package and authoritatively check account/profile state within the entitlement transaction."
  }
  assert {
    condition = (
      one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "PurchaseEntitlementsReadWrite"]).actions == toset(["dynamodb:GetItem"]) &&
      one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "WriteFencedPurchaseTransaction"]).actions == toset(["dynamodb:PutItem"]) &&
      one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "ReadPurchaseOwnershipInventory"]).actions == toset(["dynamodb:GetItem"]) &&
      one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "CheckPurchaseOwnershipInventory"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
      alltrue([for sid in ["ReadPurchaseOwnershipInventory", "CheckPurchaseOwnershipInventory"] :
        anytrue([for c in one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == sid]).condition :
          c.test == "ForAllValues:StringEquals" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["PURCHASE#CONTROL"])
        ])
      ]) &&
      anytrue([for c in one([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement : s if s.sid == "CheckPurchaseOwnershipInventory"]).condition :
        c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])
      ]) &&
      alltrue([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement :
        !contains(s.actions, "dynamodb:UpdateItem") && !contains(s.actions, "dynamodb:DeleteItem") &&
        (!contains(s.actions, "dynamodb:PutItem") || (
          s.resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"]) &&
          anytrue([for c in s.condition : c.test == "StringEquals" && c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])]) &&
          anytrue([for c in s.condition : c.test == "ForAllValues:StringLike" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["USER#*", "TOKEN#*"])])
        ))
      ])
    )
    error_message = "Pinned purchase writes must not bypass authority checks via standalone Put/Update/Delete or index grants."
  }
}

run "default_purchase_package_and_permissions_are_preserved" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.purchase_handoff.s3_key == "releases/existing-release/purchase_handoff.zip" &&
      aws_lambda_function.purchase_handoff.runtime == var.purchase_handoff_lambda_runtime &&
      !contains(keys(aws_lambda_function.purchase_handoff.environment[0].variables), "PURCHASE_OWNERSHIP_CANDIDATE_ENABLED") &&
      !contains(keys(aws_lambda_function.purchase_handoff.environment[0].variables), "DELETION_LEDGER_TABLE_NAME") &&
      alltrue([for s in data.aws_iam_policy_document.purchase_handoff_runtime.statement :
        !startswith(s.sid, "CheckPurchaseAuthority") && !contains(["ReadPurchaseDeletionFence", "ReadPurchaseOwnershipInventory", "CheckPurchaseOwnershipInventory"], s.sid)
      ])
    )
    error_message = "Purchase fencing must not alter the default release or grant new ledger access."
  }
}

run "profile_cleanup_is_subject_scoped_and_remains_pending" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.account_data[0].environment[0].variables["USER_PROFILE_DELETION_POLICY_STATUS"] == "pending" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_ENABLED"] == "false" &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "EraseFencedUserProfileState"]).actions == toset(["dynamodb:Query", "dynamodb:DeleteItem"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "EraseFencedUserProfileState"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"]) &&
      anytrue([for c in one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "EraseFencedUserProfileState"]).condition :
        c.test == "ForAllValues:StringLike" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["USER#*"])
      ]) &&
      alltrue([for s in data.aws_iam_policy_document.account_data[0].statement : !contains(s.actions, "cognito-idp:AdminDeleteUser")])
    )
    error_message = "Profile erasure must stay policy-gated, subject-partition scoped and must not imply identity deletion approval."
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
        contains(statement.actions, "dynamodb:ConditionCheckItem") ?
        alltrue([for condition in statement.condition : condition.variable != "dynamodb:EnclosingOperation"]) :
        anytrue([for condition in statement.condition : condition.test == "ForAnyValue:StringEquals" && condition.variable == "dynamodb:EnclosingOperation" && toset(condition.values) == toset(["TransactWriteItems"])])
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

run "purchase_cleanup_and_inventory_proofs_are_fenced" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.account_data[0].environment[0].variables["ENTITLEMENTS_TABLE_NAME"] == "trustcheckradar-dev-purchase-entitlements" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_ENABLED"] == "false" &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "ReadAccountInventoryProof"]).actions == toset(["dynamodb:GetItem"]) &&
      one(one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "ReadAccountInventoryProof"]).condition).values == tolist(["INVENTORY#dev"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "EraseOwnedPurchaseTransaction"]).actions == toset(["dynamodb:DeleteItem"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "EraseOwnedPurchaseTransaction"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"]) &&
      one(one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "FindOwnedPurchaseCleanupTargets"]).condition).values == tolist(["USER#*"]) &&
      alltrue([for sid in ["EraseOwnedPurchaseTransaction", "TransactionallyFenceAuthoritativeProfile"] :
        anytrue([for c in one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == sid]).condition :
          c.test == "ForAnyValue:StringEquals" && c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])
          ]) && anytrue([for c in one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == sid]).condition :
          c.test == "StringEqualsIfExists" && c.variable == "dynamodb:ReturnValues" && toset(c.values) == toset(["NONE"])
        ])
      ]) &&
      alltrue([for s in data.aws_iam_policy_document.account_data[0].statement :
        !anytrue([for action in s.actions : contains(["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"], action)]) ||
        alltrue([for c in s.condition : c.variable != "dynamodb:LeadingKeys" || alltrue([for key in c.values : !startswith(key, "INVENTORY#") && key != "*" && key != "PURCHASE#CONTROL"])])
      ])
    )
    error_message = "Purchase erasure must be subject/transaction bounded, and workers must not write their own authoritative inventory approval rows."
  }
}

run "account_data_checks_have_supported_context_without_recovery_preparation" {
  command = plan
  assert {
    condition = alltrue([for sid, scope in {
      CheckDeletionProofTransaction = {
        arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
        keys = ["ACCOUNT#*", "INVENTORY#dev"]
        test = "ForAllValues:StringLike"
      }
      CheckPurchaseCleanupInventory = {
        arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
        keys = ["PURCHASE#CONTROL"]
        test = "ForAllValues:StringEquals"
      }
      } : alltrue([for st in [one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == sid])] :
        st.actions == toset(["dynamodb:ConditionCheckItem"]) && st.resources == toset([scope.arn]) &&
        length(st.condition) == 2 &&
        alltrue([for c in st.condition : c.variable != "dynamodb:EnclosingOperation"]) &&
        anytrue([for c in st.condition : c.test == scope.test && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(scope.keys)]) &&
        anytrue([for c in st.condition : c.test == "StringEqualsIfExists" && c.variable == "dynamodb:ReturnValues" && toset(c.values) == toset(["NONE"])])
    ])])
    error_message = "Both account-data checks must preserve exact resources/key families and NONE without unsupported enclosing context, even when campaign recovery is unselected."
  }
}

run "identity_finalizer_candidate_is_pinned_but_disabled" {
  command = plan
  variables {
    account_data_finalization_candidate = {
      manifest_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      inventory_revision = 2
      approval_reference = "synthetic-test-not-user-approval"
    }
  }
  assert {
    condition = (
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_IDENTITY_FINALIZER_ENABLED"] == "false" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DELETION_ENABLED"] == "false" &&
      aws_lambda_function.account_data[0].environment[0].variables["COGNITO_USERNAME_IS_SUB"] == "false" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DATA_INVENTORY_STATUS"] == "pending" &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DATA_INVENTORY_MANIFEST_SHA256"] == var.account_data_finalization_candidate.manifest_sha256 &&
      aws_lambda_function.account_data[0].environment[0].variables["ACCOUNT_DATA_INVENTORY_REVISION"] == "2" &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "FinalizeIdentityInOwnPool"]).actions == toset(["cognito-idp:AdminGetUser", "cognito-idp:AdminDeleteUser"]) &&
      one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "FinalizeIdentityInOwnPool"]).resources == toset(["arn:aws:cognito-idp:us-east-1:107827791950:userpool/us-east-1_example"]) &&
      !aws_lambda_event_source_mapping.account_data_revocation[0].enabled &&
      aws_cloudwatch_event_rule.account_data_reconcile[0].state == "DISABLED" &&
      output.account_data_candidate_contract.routes == []
    )
    error_message = "Reviewed finalizer pins grant only exact-pool IAM and must not activate admission, cleanup, identity mapping or routes."
  }
}

run "identity_finalizer_requires_artifact" {
  command = plan
  variables {
    account_data_deployment = null
    account_data_finalization_candidate = {
      manifest_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      inventory_revision = 1
      approval_reference = "synthetic-test-not-user-approval"
    }
  }
  expect_failures = [var.account_data_finalization_candidate]
}

run "identity_finalizer_rejects_invalid_pins" {
  command = plan
  variables {
    account_data_finalization_candidate = {
      manifest_sha256    = "not-a-manifest"
      inventory_revision = 1.5
      approval_reference = ""
    }
  }
  expect_failures = [var.account_data_finalization_candidate]
}

run "transition_prepares_without_changing_existing_source_or_users_permissions" {
  command = plan
  variables {
    account_data_deployment          = null
    profile_fence_deployment         = null
    profile_fence_transition_enabled = true
  }
  assert {
    condition = (
      aws_lambda_function.age_attestation.s3_key == "releases/existing-release/age_attestation.zip" &&
      aws_lambda_function.age_attestation.environment[0].variables["DELETION_LEDGER_TABLE_NAME"] == "trustcheckradar-dev-deletion-ledger" &&
      one([for st in data.aws_iam_policy_document.age_attestation_dynamodb.statement : st if st.sid == "UsersTableReadUpdate"]).actions == toset(["dynamodb:GetItem", "dynamodb:UpdateItem"]) &&
      length(one([for st in data.aws_iam_policy_document.age_attestation_dynamodb.statement : st if st.sid == "UsersTableReadUpdate"]).condition) == 0 &&
      output.profile_fence_contract.transition_enabled &&
      !output.profile_fence_contract.transactional_user_permissions &&
      !output.profile_fence_contract.account_deletion_activation_approved
    )
    error_message = "Prepare must add exact ledger configuration while preserving old source and its users permissions."
  }
  assert {
    condition = alltrue([for st in data.aws_iam_policy_document.age_attestation_dynamodb.statement :
      contains(st.actions, "dynamodb:ConditionCheckItem") ? (
        st.resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"]) &&
        alltrue([for c in st.condition : c.variable != "dynamodb:EnclosingOperation"]) &&
        anytrue([for c in st.condition : c.variable == "dynamodb:LeadingKeys" && c.test == "ForAllValues:StringLike" && toset(c.values) == toset(["ACCOUNT#*"])]) &&
        anytrue([for c in st.condition : c.variable == "dynamodb:ReturnValues" && c.test == "StringEqualsIfExists" && toset(c.values) == toset(["NONE"])])
      ) : true
    ])
    error_message = "Transition must add only same-environment scoped condition checks with no returned ledger contents."
  }
}

run "transition_pins_source_before_tightening_users_permissions" {
  command = plan
  variables {
    account_data_deployment          = null
    profile_fence_transition_enabled = true
    profile_fence_deployment = {
      release_id         = "profile-candidate", object_version = "immutable-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = false
    }
  }
  assert {
    condition = (
      aws_lambda_function.age_attestation.s3_key == "releases/profile-candidate/age_attestation.zip" &&
      one([for st in data.aws_iam_policy_document.age_attestation_dynamodb.statement : st if st.sid == "UsersTableReadUpdate"]).actions == toset(["dynamodb:GetItem", "dynamodb:UpdateItem"]) &&
      !output.profile_fence_contract.transactional_user_permissions
    )
    error_message = "Installation must allow old in-flight writes until source verification and drain complete."
  }
}

run "transition_does_not_bypass_production_approval" {
  command = plan
  variables {
    account_data_deployment          = null
    profile_fence_transition_enabled = true
    environment                      = "prod"
  }
  expect_failures = [var.profile_fence_transition_enabled]
}

run "transition_rejects_other_caller_account" {
  command = plan
  variables {
    account_data_deployment          = null
    profile_fence_transition_enabled = true
    profile_fence_deployment         = null
  }
  override_data {
    target = data.aws_caller_identity.account_fence[0]
    values = { account_id = "999999999999" }
  }
  expect_failures = [aws_lambda_function.age_attestation]
}
