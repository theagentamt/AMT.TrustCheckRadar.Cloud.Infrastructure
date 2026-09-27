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
  campaign_recovery_preparation = null
  campaign_participation_fence_deployment = {
    release_id         = "existing-participation", object_version = "participation-version"
    source_hash        = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    approval_reference = "existing-synthetic-review", promotion_approved = false
  }
  account_data_deployment = {
    release_id         = "1111111111111111111111111111111111111111"
    object_version     = "synthetic-version"
    source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
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
run "export_and_cleanup_share_pins_without_reviving_legacy_analysis" {
  command = plan
  variables {
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
  }

  assert {
    condition = alltrue([for fn in [aws_lambda_function.account_data[0], aws_lambda_function.account_export[0]] :
      fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "true" && fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_ID == "22222222-2222-4222-8222-222222222222"
    ]) && aws_lambda_function.analysis.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "false" && aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_ENABLED == "false"
    error_message = "Work compatibility updates cleanup/export readers without enabling legacy analysis or unqualified export admission."
  }
  assert {
    condition     = alltrue([for st in data.aws_iam_policy_document.period_work_export[0].statement : length(setsubtract(toset(st.actions), toset(["dynamodb:GetItem", "dynamodb:DescribeTable"]))) == 0]) && anytrue([for st in data.aws_iam_policy_document.research_migration_boundary["analysis"].statement : st.sid == "DenyLegacySettlementAndWrites" && st.effect == "Deny"])
    error_message = "Export work grants stay read-only and the existing analysis write-deny must remain."
  }
}
run "activation_rejects_missing_export_reader" {
  command = plan
  variables {
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
  }
  expect_failures = [var.campaign_period_work_activation]
}
run "activation_rejects_stale_export_source" {
  command = plan
  variables {
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
      release_id                = "4444444444444444444444444444444444444444"
      object_version            = "export-version"
      source_hash               = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference        = "synthetic-export"
      promotion_approved        = false
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    }
  }
  expect_failures = [var.campaign_period_work_activation]
}
