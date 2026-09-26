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
  campaign_recovery_preparation = { review_reference = "synthetic-engineering-review" }
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
    outbox_table_name     = "trustcheckradar-dev-campaign-outbox"
    outbox_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"
    transient_kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
  } } }
}

run "null_preserves_participation_checks_and_corrects_account_data_checks" {
  command = plan
  variables { campaign_recovery_preparation = null }
  assert {
    condition = (
      length(terraform_data.campaign_recovery_preparation) == 0 &&
      !output.campaign_recovery_preparation_contract.selected &&
      alltrue([for st in concat(tolist(data.aws_iam_policy_document.account_data[0].statement), tolist(data.aws_iam_policy_document.campaign_participation_runtime.statement)) :
        contains(["CheckParticipationAuthorityUsers", "CheckParticipationAuthorityLedger"], st.sid) ?
        anytrue([for c in st.condition : c.variable == "dynamodb:EnclosingOperation" && c.test == "StringEquals" && toset(c.values) == toset(["TransactWriteItems"])]) : true
      ])
    )
    error_message = "No preparation must preserve existing participation checks and add no preparation resources; account-data check corrections apply independently."
  }
}

run "preparation_retains_exact_account_data_and_participation_checks" {
  command = plan
  assert {
    condition = alltrue([for st in concat(tolist(data.aws_iam_policy_document.account_data[0].statement), tolist(data.aws_iam_policy_document.campaign_participation_runtime.statement)) :
      contains(["CheckDeletionProofTransaction", "CheckParticipationAuthorityUsers", "CheckParticipationAuthorityLedger"], st.sid) ? (
        toset(st.actions) == toset(["dynamodb:ConditionCheckItem"]) &&
        alltrue([for c in st.condition : c.variable != "dynamodb:EnclosingOperation"]) &&
        anytrue([for c in st.condition : c.variable == "dynamodb:ReturnValues" && c.test == "StringEqualsIfExists" && toset(c.values) == toset(["NONE"])]) &&
        anytrue([for c in st.condition : c.variable == "dynamodb:LeadingKeys" && c.test == "ForAllValues:StringLike" && toset(c.values) == toset(st.sid == "CheckParticipationAuthorityUsers" ? ["USER#*"] : (st.sid == "CheckDeletionProofTransaction" ? ["ACCOUNT#*", "INVENTORY#dev"] : ["ACCOUNT#*"]))]) &&
        st.resources == toset([st.sid == "CheckParticipationAuthorityUsers" ? "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"])
      ) : true
    ])
    error_message = "Selected checks need the exact resources/key families and NONE guard without unsupported context."
  }
  assert {
    condition = (
      alltrue([for st in [one([for s in data.aws_iam_policy_document.account_data[0].statement : s if s.sid == "CheckPurchaseCleanupInventory"])] :
        st.actions == toset(["dynamodb:ConditionCheckItem"]) &&
        st.resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"]) &&
        length(st.condition) == 2 &&
        alltrue([for c in st.condition : c.variable != "dynamodb:EnclosingOperation"]) &&
        anytrue([for c in st.condition : c.test == "ForAllValues:StringEquals" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["PURCHASE#CONTROL"])]) &&
        anytrue([for c in st.condition : c.test == "StringEqualsIfExists" && c.variable == "dynamodb:ReturnValues" && toset(c.values) == toset(["NONE"])])
      ]) &&
      one([for st in data.aws_iam_policy_document.account_data[0].statement : st if st.sid == "ReadCommandAndWriteRevocationReceipt"]).actions == toset(["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]) &&
      alltrue([for st in data.aws_iam_policy_document.campaign_participation_runtime.statement : contains(st.actions, "dynamodb:PutItem") ? anytrue([for c in st.condition : c.variable == "dynamodb:EnclosingOperation"]) : true])
    )
    error_message = "Preparation must retain the corrected exact purchase inventory check, existing account-data receipt permissions and transaction-only participation writes."
  }
}

run "preparation_preserves_source_and_deletion_gates" {
  command = plan
  assert {
    condition = (
      output.campaign_recovery_preparation_contract.selected &&
      !output.campaign_recovery_preparation_contract.writes_enabled &&
      !output.campaign_recovery_preparation_contract.coverage_qualified &&
      !output.campaign_recovery_preparation_contract.source_selected_by_preparation &&
      aws_lambda_function.account_data[0].s3_key == "releases/synthetic-candidate/account_data_api.zip" &&
      aws_lambda_function.account_data[0].source_code_hash == var.account_data_deployment.source_hash &&
      aws_lambda_function.campaign_participation.s3_key == "releases/existing-participation/campaign_participation.zip" &&
      aws_lambda_function.campaign_participation.source_code_hash == var.campaign_participation_fence_deployment.source_hash &&
      aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DELETION_ENABLED == "false" &&
      aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_IDENTITY_FINALIZER_ENABLED == "false" &&
      !aws_lambda_event_source_mapping.account_data_revocation[0].enabled &&
      aws_cloudwatch_event_rule.account_data_reconcile[0].state == "DISABLED"
    )
    error_message = "Preparation cannot select new source, enable writes or activate account deletion."
  }
}

run "reject_missing_contract" {
  command = plan
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
  expect_failures = [terraform_data.campaign_recovery_preparation]
}

run "reject_wrong_projection" {
  command = plan
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
        projection         = "ALL"
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
  expect_failures = [terraform_data.campaign_recovery_preparation]
}

run "reject_wrong_index_account" {
  command = plan
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
        index_arn          = "arn:aws:dynamodb:us-east-1:123456789012:table/trustcheckradar-dev-deletion-ledger/index/CampaignRecoveryDueIndex"
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
  expect_failures = [terraform_data.campaign_recovery_preparation]
}

run "reject_wrong_shard_count" {
  command = plan
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
        shard_count        = 8
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
  expect_failures = [terraform_data.campaign_recovery_preparation]
}

run "reject_upstream_writes_enabled" {
  command = plan
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
        writes_enabled     = true
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
  expect_failures = [terraform_data.campaign_recovery_preparation]
}

run "reject_unpinned_participation" {
  command = plan
  variables { campaign_participation_fence_deployment = null }
  expect_failures = [terraform_data.campaign_recovery_preparation]
}

run "reject_empty_review_reference" {
  command = plan
  variables { campaign_recovery_preparation = { review_reference = " " } }
  expect_failures = [var.campaign_recovery_preparation]
}

run "preparation_adds_only_confirmed_scoped_operations" {
  command = plan
  assert {
    condition = alltrue([for policy in [data.aws_iam_policy_document.account_data[0], data.aws_iam_policy_document.campaign_participation_runtime] :
      alltrue([for sid, actions in {
        FindAccountCampaignRecoverySidecars      = ["dynamodb:Query"]
        UpdateCampaignRecoveryControlTransaction = ["dynamodb:UpdateItem"]
        } : (
        one([for st in policy.statement : st if st.sid == sid]).actions == toset(actions) &&
        one([for st in policy.statement : st if st.sid == sid]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"]) &&
        anytrue([for c in one([for st in policy.statement : st if st.sid == sid]).condition : c.test == "ForAllValues:StringLike" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["ACCOUNT#*"])])
      )]) &&
      anytrue([for c in one([for st in policy.statement : st if st.sid == "UpdateCampaignRecoveryControlTransaction"]).condition : c.test == "ForAnyValue:StringEquals" && c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])])
    ])
    error_message = "Both producers need only base-table ACCOUNT# Query and transaction-only ACCOUNT# Update; no speculative Delete, index query or control-namespace grant."
  }
}

run "general_environment_map_cannot_enable_recovery_writes" {
  command = plan
  variables {
    campaign_participation_lambda_env = { CAMPAIGN_RECOVERY_WRITES_ENABLED = "true" }
  }
  assert {
    condition = (
      aws_lambda_function.account_data[0].environment[0].variables.CAMPAIGN_RECOVERY_WRITES_ENABLED == "false" &&
      aws_lambda_function.campaign_participation.environment[0].variables.CAMPAIGN_RECOVERY_WRITES_ENABLED == "false"
    )
    error_message = "Preparation must force the confirmed producer writes gate false even against a general environment override."
  }
}

run "null_adds_no_new_operation_or_environment_grant" {
  command = plan
  variables { campaign_recovery_preparation = null }
  assert {
    condition = (
      alltrue([for st in concat(tolist(data.aws_iam_policy_document.account_data[0].statement), tolist(data.aws_iam_policy_document.campaign_participation_runtime.statement)) : !contains(["FindAccountCampaignRecoverySidecars", "UpdateCampaignRecoveryControlTransaction"], st.sid)]) &&
      !contains(keys(aws_lambda_function.account_data[0].environment[0].variables), "CAMPAIGN_RECOVERY_WRITES_ENABLED") &&
      !contains(keys(aws_lambda_function.campaign_participation.environment[0].variables), "CAMPAIGN_RECOVERY_WRITES_ENABLED")
    )
    error_message = "Default/unselected producer configuration must remain unchanged."
  }
}
