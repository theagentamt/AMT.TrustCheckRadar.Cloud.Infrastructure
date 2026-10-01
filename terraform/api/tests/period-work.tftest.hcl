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
run "period_work_default_absent" {
  command = plan
  assert {
    condition     = length(aws_iam_role_policy_attachment.period_work) == 0 && !contains(keys(aws_lambda_function.analysis.environment[0].variables), "CAMPAIGN_PERIOD_WORK_ENABLED")
    error_message = "No producer work access is installed implicitly."
  }
}
run "period_work_requires_immutable_producer_selection" {
  command = plan
  variables { campaign_period_work_preparation = { review_reference = "synthetic" } }
  expect_failures = [var.campaign_period_work_preparation]
}
run "period_work_prep_is_closed_and_separates_registry" {
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
  }
  assert {
    condition = alltrue([for fn in [aws_lambda_function.analysis, aws_lambda_function.account_data[0]] :
      fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "false" &&
      fn.environment[0].variables.CAMPAIGN_PERIOD_ADMISSION_ENABLED == "false" &&
      fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_NAME == "trustcheckradar-dev-campaign-pipeline" &&
      fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_PIPELINE_TABLE_ID == "" &&
      fn.environment[0].variables.CAMPAIGN_PERIOD_WORK_MANIFEST_SHA256 == ""
    ])
    error_message = "Untrusted environment overrides cannot enable unqualified work or select another table."
  }
  assert {
    condition = toset(keys(aws_iam_role_policy_attachment.period_work)) == toset(["analysis", "account_data"]) && alltrue([for p in data.aws_iam_policy_document.period_work :
      alltrue([for st in p.statement :
        !contains(st.actions, "dynamodb:DeleteItem") || toset(flatten([for c in st.condition : c.values if c.variable == "dynamodb:LeadingKeys"])) == toset(["PERIOD_WORK#*", "WORK_LOOKUP#*"])
      ])
    ])
    error_message = "Work deletion cannot reach period registries, approval markers or progress controls."
  }
  assert {
    condition = alltrue([for p in data.aws_iam_policy_document.period_work : alltrue([for st in p.statement :
      length(setintersection(toset(st.actions), toset(["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]))) == 0 ||
      anytrue([for c in st.condition : c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])])
    ])])
    error_message = "Paired producer work mutations must use transactions."
  }
  assert {
    condition = alltrue([for p in data.aws_iam_policy_document.period_work :
      toset(one([for st in p.statement : st.resources if st.sid == "VerifyPeriodWorkResourceIdentity"])) == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-pipeline", "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"])
    ])
    error_message = "Only the two exact campaign table identities may be inspected."
  }
}
