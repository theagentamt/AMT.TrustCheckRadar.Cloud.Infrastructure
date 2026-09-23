mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
}

variables {
  aws_region          = "us-east-1"
  project_name        = "trustcheckradar"
  environment         = "dev"
  state_bucket_name   = "synthetic-state"
  state_bucket_region = "us-east-1"
  artifact_release    = "existing-release"
  account_export_deployment = {
    release_id                = "synthetic-candidate"
    object_version            = "synthetic-version"
    source_hash               = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference        = "synthetic-test-not-user-approval"
    promotion_approved        = false
    authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-AbCd12"
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


run "default_has_no_export_surface" {
  command = plan
  variables { account_export_deployment = null }
  assert {
    condition     = length(aws_lambda_function.account_export) == 0 && length(aws_iam_role.account_export) == 0 && length(aws_secretsmanager_secret.account_export_cursor) == 0 && !output.account_export_candidate_contract.deployed
    error_message = "Default configuration must create no export resources or secret container."
  }
}

run "candidate_is_pinned_private_and_unavailable" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.account_export[0].runtime == "python3.14" &&
      aws_lambda_function.account_export[0].s3_key == "releases/synthetic-candidate/account_export_api.zip" &&
      aws_lambda_function.account_export[0].s3_object_version == "synthetic-version" &&
      aws_lambda_function.account_export[0].source_code_hash == var.account_export_deployment.source_hash &&
      aws_lambda_function.account_export[0].reserved_concurrent_executions == 1 &&
      aws_lambda_function.account_export[0].environment[0].variables["ACCOUNT_EXPORT_ENABLED"] == "false" &&
      aws_lambda_function.account_export[0].environment[0].variables["ACCOUNT_EXPORT_INVENTORY_STATUS"] == "pending" &&
      aws_lambda_function.account_export[0].environment[0].variables["COGNITO_USERNAME_IS_SUB"] == "false" &&
      aws_lambda_function.account_export[0].environment[0].variables["COGNITO_REQUIRED_SCOPE"] == "aws.cognito.signin.user.admin" &&
      aws_lambda_function_event_invoke_config.account_export[0].maximum_retry_attempts == 0 &&
      length(output.account_export_candidate_contract.routes) == 0 &&
      !output.account_export_candidate_contract.enabled &&
      !output.account_export_candidate_contract.full_account_export_available &&
      !output.account_export_candidate_contract.payload_storage_created &&
      output.account_export_candidate_contract.continuation_seconds == 900 &&
      aws_secretsmanager_secret.account_export_cursor[0].name == "trustcheckradar/dev/account-export-cursor" &&
      aws_cloudwatch_log_group.account_export[0].retention_in_days == 14
    )
    error_message = "Candidate pins must not expose or activate an unqualified export or create retained payload storage."
  }
}

run "export_permissions_are_read_only_and_credential_scoped" {
  command = plan
  override_resource {
    target          = aws_secretsmanager_secret.account_export_cursor[0]
    override_during = plan
    values          = { arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/account-export-cursor-XyZ123" }
  }
  assert {
    condition = alltrue([for statement in data.aws_iam_policy_document.account_export[0].statement :
      statement.effect == "Deny" || alltrue([for action in statement.actions : contains([
        "dynamodb:GetItem", "dynamodb:Query", "cognito-idp:AdminGetUser", "secretsmanager:GetSecretValue", "logs:CreateLogStream", "logs:PutLogEvents"
      ], action)])
      ]) && alltrue([for statement in data.aws_iam_policy_document.account_export[0].statement :
      !contains(statement.actions, "dynamodb:Query") || length(statement.condition) == 1 && alltrue([for arn in statement.resources : startswith(arn, "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-")])
    ])
    error_message = "Export must not acquire write, scan, provider invocation, wildcard read or other-environment permissions."
  }
  assert {
    condition = (
      one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadCurrentOwnedIdentity"]).resources == toset(["arn:aws:cognito-idp:us-east-1:107827791950:userpool/us-east-1_example"]) &&
      toset(one(one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadOwnedAnalysis"]).condition).values) == toset(["ANALYSIS#REQUEST#*", "ANALYSIS#CONSUMPTION#*"]) &&
      one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadPurchaseCoverageMarker"]).actions == toset(["dynamodb:GetItem"]) &&
      one(one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadPurchaseCoverageMarker"]).condition).values == tolist(["PURCHASE#CONTROL"]) &&
      length(one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadTwoExactKeyrings"]).resources) == 2 &&
      one(one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadTwoExactKeyrings"]).condition).values == tolist(["AWSCURRENT"]) &&
      one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "NoPayloadStorageOrRoleChaining"]).effect == "Deny"
    )
    error_message = "Identity, keyrings and no-payload-storage constraints must stay explicit."
  }
}

run "candidate_rejects_wrong_deploying_account" {
  command = plan
  override_data {
    target = data.aws_caller_identity.account_fence[0]
    values = { account_id = "111111111111" }
  }
  expect_failures = [aws_lambda_function.account_export]
}

run "rejects_foreign_secret" {
  command = plan
  variables {
    account_export_deployment = {
      release_id                = "synthetic-candidate"
      object_version            = "synthetic-version"
      source_hash               = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference        = "synthetic-test-not-user-approval"
      promotion_approved        = false
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:111111111111:secret:trustcheckradar/dev/v1-authority-hmac-AbCd12"
    }
  }
  expect_failures = [var.account_export_deployment]
}

run "rejects_other_environment_secret" {
  command = plan
  variables {
    account_export_deployment = {
      release_id                = "synthetic-candidate"
      object_version            = "synthetic-version"
      source_hash               = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference        = "synthetic-test-not-user-approval"
      promotion_approved        = false
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/prod/v1-authority-hmac-AbCd12"
    }
  }
  expect_failures = [var.account_export_deployment]
}

run "rejects_unversioned_artifact" {
  command = plan
  variables {
    account_export_deployment = {
      release_id                = "synthetic-candidate"
      object_version            = "null"
      source_hash               = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference        = "synthetic-test-not-user-approval"
      promotion_approved        = false
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-AbCd12"
    }
  }
  expect_failures = [var.account_export_deployment]
}

run "rejects_invalid_hash" {
  command = plan
  variables {
    account_export_deployment = {
      release_id                = "synthetic-candidate"
      object_version            = "synthetic-version"
      source_hash               = "bad"
      approval_reference        = "synthetic-test-not-user-approval"
      promotion_approved        = false
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-AbCd12"
    }
  }
  expect_failures = [var.account_export_deployment]
}

run "campaign_projection_access_is_index_and_purpose_scoped" {
  command = plan
  variables { campaign_intelligence_enabled = true }
  override_data {
    target = data.terraform_remote_state.campaign_data[0]
    values = { outputs = { downstream_contract = {
      schema_version        = 1
      enabled               = true
      environment           = "dev"
      outbox_table_name     = "trustcheckradar-dev-campaign-outbox"
      outbox_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"
      pipeline_table_name   = "trustcheckradar-dev-campaign-pipeline"
      pipeline_table_arn    = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-pipeline"
      transient_kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/12345678-1234-1234-1234-123456789abc"
    } } }
  }
  assert {
    condition = (
      one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "FindOwnCampaignContributions"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-pipeline/index/ContributorPeriodIndex"]) &&
      one(one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "FindOwnCampaignContributions"]).condition).values == tolist(["CONTRIB#*"]) &&
      one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadOwnedCampaignPipeline"]).actions == toset(["dynamodb:GetItem"]) &&
      one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "DeriveOwnedCampaignPeriodTokens"]).actions == toset(["kms:GenerateMac"]) &&
      one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "DeriveOwnedCampaignPeriodTokens"]).resources == toset(["arn:aws:kms:us-east-1:107827791950:key/*"]) &&
      { for c in one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "DeriveOwnedCampaignPeriodTokens"]).condition : c.variable => one(c.values) } == {
        "aws:ResourceTag/Project"     = "trustcheckradar"
        "aws:ResourceTag/Environment" = "dev"
        "aws:ResourceTag/Purpose"     = "campaign-contributor-token"
        "kms:MacAlgorithm"            = "HMAC_SHA_256"
      } &&
      one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "DecryptCampaignStorageThroughDynamoDB"]).actions == toset(["kms:Decrypt"]) &&
      { for c in one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "DecryptCampaignStorageThroughDynamoDB"]).condition : c.variable => toset(c.values) } == {
        "kms:CallerAccount"                            = toset(["107827791950"])
        "kms:ViaService"                               = toset(["dynamodb.us-east-1.amazonaws.com"])
        "kms:EncryptionContext:aws:dynamodb:tableName" = toset(["trustcheckradar-dev-campaign-outbox", "trustcheckradar-dev-campaign-pipeline"])
      }
    )
    error_message = "Research export must use owned index lookup, purpose-tagged HMAC keys and table-constrained storage decryption, never broad campaign writes or key administration."
  }
}

run "export_monitoring_is_opt_in" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.account_export_runtime) == 0 && length(aws_cloudwatch_metric_alarm.account_export_unavailable) == 0
    error_message = "A candidate alone must not select a notification destination or create paid alarms."
  }
}

run "monitoring_matches_handled_failure_metrics" {
  command = plan
  variables { account_export_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts" } }
  assert {
    condition = length(aws_cloudwatch_metric_alarm.account_export_runtime) == 2 && length(aws_cloudwatch_metric_alarm.account_export_unavailable) == 3 && alltrue([
      for op, alarm in aws_cloudwatch_metric_alarm.account_export_unavailable :
      alarm.metric_name == "AccountExportUnavailable" && alarm.namespace == "AMT/TrustCheckRadar/AccountExport" &&
      alarm.dimensions == tomap({ Environment = "dev", Operation = op }) && alarm.period == 300 &&
      alarm.threshold == 0 && alarm.treat_missing_data == "notBreaching" &&
      alarm.alarm_actions == toset([var.account_export_monitoring.alarm_topic_arn])
    ]) && !output.account_export_candidate_contract.enabled && length(output.account_export_candidate_contract.routes) == 0
    error_message = "Handled503s require all three exact EMF dimension sets without activating export."
  }
}

run "export_monitoring_rejects_missing_candidate" {
  command = plan
  variables {
    account_export_deployment = null
    account_export_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts" }
  }
  expect_failures = [var.account_export_monitoring]
}

run "export_monitoring_rejects_foreign_topic" {
  command = plan
  variables { account_export_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:111111111111:synthetic-alerts" } }
  expect_failures = [var.account_export_monitoring]
}

run "play_token_metadata_reader_stays_closed" {
  command = plan
  variables { account_export_play_token_table_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens" }
  assert {
    condition     = aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_PLAY_TOKENS_ENABLED == "false" && aws_lambda_function.account_export[0].environment[0].variables.PLAY_TOKEN_TABLE_NAME == "trustcheckradar-dev-play-tokens" && one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadOwnedPlayTokens"]).actions == toset(["dynamodb:GetItem", "dynamodb:Query"]) && one([for statement in data.aws_iam_policy_document.account_export[0].statement : statement if statement.sid == "ReadOwnedPlayTokens"]).resources == toset([var.account_export_play_token_table_arn])
    error_message = "Export integration provides only exact-table metadata reads and must not activate candidate.3."
  }
}
