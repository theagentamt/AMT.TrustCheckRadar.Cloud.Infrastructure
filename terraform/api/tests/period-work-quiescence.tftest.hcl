# Synthetic plan assertions only; these fixtures are not activation approvals.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  aws_region                    = "us-east-1"
  project_name                  = "trustcheckradar"
  environment                   = "dev"
  state_bucket_name             = "synthetic-state"
  state_bucket_region           = "us-east-1"
  artifact_release              = "existing-release"
  campaign_intelligence_enabled = true
  enable_device_recovery        = true
  enable_web_risk_communication = true
  campaign_recovery_preparation = { review_reference = "synthetic-recovery" }

  account_data_deployment = {
    release_id         = "1111111111111111111111111111111111111111"
    object_version     = "synthetic-version"
    source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
  }

  campaign_period_work_preparation        = { review_reference = "synthetic" }
  analysis_lambda_env                     = { CAMPAIGN_PERIOD_WORK_ENABLED = "true", CAMPAIGN_PERIOD_ADMISSION_ENABLED = "true", CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_NAME = "other-table" }
  campaign_participation_fence_deployment = null
  research_consent_migration_deployment = {
    release_id         = "research-migration-reviewed"
    approval_reference = "synthetic-contract-review"
    promotion_approved = false
    artifacts = {
      analysis      = { object_version = "analysis-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      participation = { object_version = "participation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
      snapshot      = { object_version = "snapshot-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
      purchase      = { object_version = "purchase-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      web_risk      = { object_version = "webrisk-version", source_hash = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=" }
    }
  }
  campaign_period_work_activation = {
    source_sha                 = "1111111111111111111111111111111111111111"
    generation                 = "11111111-1111-4111-8111-111111111111"
    manifest_sha256            = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    inventory_revision         = 1
    locator_manifest_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    locator_inventory_revision = 1
    pipeline_table_id          = "22222222-2222-4222-8222-222222222222"
    outbox_table_id            = "33333333-3333-4333-8333-333333333333"
    inventory_reference        = "synthetic-inventory"
    runtime_reference          = "synthetic-runtime"
    iam_reference              = "synthetic-iam"
  }
  account_export_deployment = {
    release_id                = "1111111111111111111111111111111111111111"
    object_version            = "export-version"
    source_hash               = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference        = "synthetic-export"
    promotion_approved        = false
    authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
  }

  account_data_finalization_candidate = {
    manifest_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    inventory_revision = 1
    approval_reference = "synthetic-inventory"
  }
  account_data_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts" }
  account_deletion_activation = {
    phase                       = "api"
    source_sha                  = "1111111111111111111111111111111111111111"
    policy_reference            = "synthetic-policy"
    inventory_reference         = "synthetic-inventory"
    identity_reference          = "synthetic-identity"
    component_reference         = "synthetic-components"
    worker_acceptance_reference = "synthetic-worker-acceptance"
    http_subjects               = ["01959cef-9123-7abc-8def-0123456789ab"]
  }
}

override_data {
  target = data.terraform_remote_state.foundation
  values = { outputs = { downstream_contract = {
    campaign_recovery = {
      schema_version     = 1
      enabled            = true
      environment        = "dev"
      table_name         = "trustcheckradar-dev-deletion-ledger"
      table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
      index_name         = "CampaignRecoveryDueIndex"
      index_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/index/CampaignRecoveryDueIndex"
      partition_key      = "campaignRecoveryPartition"
      sort_key           = "nextAttemptAtEpoch"
      projection         = "KEYS_ONLY"
      shard_count        = 16
      writes_enabled     = false
      coverage_qualified = false
    }
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

override_data {
  target = data.terraform_remote_state.campaign_data[0]
  values = { outputs = { downstream_contract = {
    schema_version        = 1, environment = "dev", enabled = true
    pipeline_table_name   = "trustcheckradar-dev-campaign-pipeline"
    pipeline_table_arn    = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-pipeline"
    outbox_table_name     = "trustcheckradar-dev-campaign-outbox"
    outbox_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"
    transient_kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
  } } }
}

override_data {
  target = data.terraform_remote_state.research_campaign_processing
  values = { outputs = { research_consent_migration_contract = {
    selected         = true
    environment      = "dev"
    account_id       = "107827791950"
    release_id       = "research-migration-reviewed"
    consumers_paused = true
  } } }
}

run "pause_preserves_scoped_route_configuration" {
  command = plan
  variables { campaign_period_work_quiescence = true }

  assert {
    condition     = (alltrue([for fn in [aws_lambda_function.account_data[0], aws_lambda_function.account_export[0]] : fn.reserved_concurrent_executions == 0 && fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "false"]) && aws_lambda_function.analysis.reserved_concurrent_executions == 0)
    error_message = "Pause must stop the three API-side participants and restore their prior limits."
  }

  assert {
    condition     = (alltrue([for key in ["ACCOUNT_DELETION_ENABLED", "ACCOUNT_IDENTITY_FINALIZER_ENABLED", "CAMPAIGN_RECOVERY_WRITES_ENABLED"] : aws_lambda_function.account_data[0].environment[0].variables[key] == "false"]) && aws_lambda_event_source_mapping.account_data_revocation[0].enabled == false && aws_cloudwatch_event_rule.account_data_reconcile[0].state == "DISABLED")
    error_message = "Deletion admission, finalization, stream and reconciliation must pause and restore together."
  }

  assert {
    condition     = (aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DATA_INVENTORY_MANIFEST_SHA256 == var.account_data_finalization_candidate.manifest_sha256)
    error_message = "Pausing must not substitute the independently qualified account inventory."
  }

  assert {
    condition     = (length(aws_apigatewayv2_route.account_deletion) == 2 && alltrue([for route in aws_apigatewayv2_route.account_deletion : route.authorization_type == "JWT" && toset(route.authorization_scopes) == toset(["aws.cognito.signin.user.admin"])]) && length(aws_lambda_permission.account_deletion_gateway) == 2)
    error_message = "Quiescence preserves the configured authenticated routes; runtime gates and concurrency prevent admission."
  }

  assert {
    condition     = (aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_ENABLED == "false" && aws_lambda_function.analysis.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "false" && aws_lambda_function.campaign_participation.environment[0].variables.CAMPAIGN_RECOVERY_WRITES_ENABLED == "false" && anytrue([for st in data.aws_iam_policy_document.research_migration_boundary["analysis"].statement : st.sid == "DenyLegacySettlementAndWrites" && st.effect == "Deny"]))
    error_message = "Pause/restore must not enable export, legacy analysis writes or consent recovery producers."
  }

  assert {
    condition     = (aws_lambda_function.age_attestation.reserved_concurrent_executions == var.age_attestation_lambda_reserved_concurrency && aws_lambda_function.device_registration.reserved_concurrent_executions == var.device_registration_lambda_reserved_concurrency && aws_lambda_function.device_recovery[0].reserved_concurrent_executions == var.device_recovery_lambda_reserved_concurrency && aws_lambda_function.entitlement_snapshot.reserved_concurrent_executions == var.entitlement_snapshot_lambda_reserved_concurrency && aws_lambda_function.campaign_participation.reserved_concurrent_executions == var.campaign_participation_lambda_reserved_concurrency && aws_lambda_function.purchase_handoff.reserved_concurrent_executions == var.purchase_handoff_lambda_reserved_concurrency && aws_lambda_function.web_risk_communication[0].reserved_concurrent_executions == var.web_risk_communication_lambda_reserved_concurrency)
    error_message = "The narrow pause must preserve unrelated API concurrency."
  }

  assert {
    condition     = (lookup(aws_lambda_function.account_data[0].environment[0].variables, "ACCOUNT_DELETION_HTTP_SUBJECTS_JSON", "[]") == "[]")
    error_message = "Paused deletion must not retain an effective HTTP subject scope."
  }
}

run "restore_exact_sec200_scope" {
  command = plan
  variables { campaign_period_work_quiescence = false }

  assert {
    condition     = (alltrue([for fn in [aws_lambda_function.account_data[0], aws_lambda_function.account_export[0]] : fn.reserved_concurrent_executions == 1 && fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "true"]) && aws_lambda_function.analysis.reserved_concurrent_executions == var.analysis_lambda_reserved_concurrency)
    error_message = "Pause must stop the three API-side participants and restore their prior limits."
  }

  assert {
    condition     = (alltrue([for key in ["ACCOUNT_DELETION_ENABLED", "ACCOUNT_IDENTITY_FINALIZER_ENABLED", "CAMPAIGN_RECOVERY_WRITES_ENABLED"] : aws_lambda_function.account_data[0].environment[0].variables[key] == "true"]) && aws_lambda_event_source_mapping.account_data_revocation[0].enabled == true && aws_cloudwatch_event_rule.account_data_reconcile[0].state == "ENABLED")
    error_message = "Deletion admission, finalization, stream and reconciliation must pause and restore together."
  }

  assert {
    condition     = (aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DATA_INVENTORY_MANIFEST_SHA256 == var.account_data_finalization_candidate.manifest_sha256)
    error_message = "Pausing must not substitute the independently qualified account inventory."
  }

  assert {
    condition     = (length(aws_apigatewayv2_route.account_deletion) == 2 && alltrue([for route in aws_apigatewayv2_route.account_deletion : route.authorization_type == "JWT" && toset(route.authorization_scopes) == toset(["aws.cognito.signin.user.admin"])]) && length(aws_lambda_permission.account_deletion_gateway) == 2)
    error_message = "Quiescence preserves the configured authenticated routes; runtime gates and concurrency prevent admission."
  }

  assert {
    condition     = (aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_ENABLED == "false" && aws_lambda_function.analysis.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "false" && aws_lambda_function.campaign_participation.environment[0].variables.CAMPAIGN_RECOVERY_WRITES_ENABLED == "false" && anytrue([for st in data.aws_iam_policy_document.research_migration_boundary["analysis"].statement : st.sid == "DenyLegacySettlementAndWrites" && st.effect == "Deny"]))
    error_message = "Pause/restore must not enable export, legacy analysis writes or consent recovery producers."
  }

  assert {
    condition     = (aws_lambda_function.age_attestation.reserved_concurrent_executions == var.age_attestation_lambda_reserved_concurrency && aws_lambda_function.device_registration.reserved_concurrent_executions == var.device_registration_lambda_reserved_concurrency && aws_lambda_function.device_recovery[0].reserved_concurrent_executions == var.device_recovery_lambda_reserved_concurrency && aws_lambda_function.entitlement_snapshot.reserved_concurrent_executions == var.entitlement_snapshot_lambda_reserved_concurrency && aws_lambda_function.campaign_participation.reserved_concurrent_executions == var.campaign_participation_lambda_reserved_concurrency && aws_lambda_function.purchase_handoff.reserved_concurrent_executions == var.purchase_handoff_lambda_reserved_concurrency && aws_lambda_function.web_risk_communication[0].reserved_concurrent_executions == var.web_risk_communication_lambda_reserved_concurrency)
    error_message = "The narrow pause must preserve unrelated API concurrency."
  }

  assert {
    condition     = (toset(jsondecode(aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DELETION_HTTP_SUBJECTS_JSON)) == var.account_deletion_activation.http_subjects && toset(jsondecode(aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DELETION_REQUIRED_COMPONENTS_JSON)) == toset(["SESSION_REVOCATION", "DEVICE_BINDINGS", "DEVICE_RECOVERY", "ANALYSIS_ABUSE", "HISTORY", "CAMPAIGN", "CAMPAIGN_OUTBOX", "ENTITLEMENTS", "V1_AUTHORITY", "PLAY_TOKENS", "USER_PROFILE", "IDENTITY"]))
    error_message = "Releasing the pause must restore only the original subject and all twelve required components."
  }
}
