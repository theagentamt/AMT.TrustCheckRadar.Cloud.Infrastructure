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
    release_id         = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
    approval_reference = "synthetic-contract-review"
    promotion_approved = false
    artifacts = {
      analysis      = { object_version = "K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1", source_hash = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4=" }
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

  account_export_play_token_table_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens"
  account_export_monitoring           = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts" }
  account_export_activation = {
    phase               = "runtime"
    source_sha          = "1111111111111111111111111111111111111111"
    http_subjects       = ["0199abcd-1234-7000-8000-111111111111"]
    policy_reference    = "synthetic-policy"
    inventory_reference = "synthetic-inventory"
    identity_reference  = "synthetic-identity"
    contract_reference  = "synthetic-contract"
  }
  history_deployment = {
    release_id         = "history-candidate"
    approval_reference = "synthetic-history"
    promotion_approved = false
    artifacts = {
      read     = { object_version = "read-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      mutation = { object_version = "mutation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
      analysis = { object_version = "analysis-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
    }
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
    release_id       = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
    consumers_paused = true
  } } }
}
override_data {
  target = data.terraform_remote_state.history_data[0]
  values = {
    outputs = {
      downstream_contract = {
        schema_version              = 1
        environment                 = "dev"
        enabled                     = true
        content_table_name          = "trustcheckradar-dev-history-content"
        control_table_name          = "trustcheckradar-dev-history-control"
        content_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-content"
        control_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-control"
        history_retention_seconds   = 7776000
        active_deletion_sla_seconds = 86400
        expiration_index_name       = "ExpirationIndex"
        lifecycle_index_name        = "PendingLifecycleIndex"
        storage_policy              = { approved = true, dedup_retention_seconds = 10368000 }
      }
    }
  }
}

override_data {
  target = data.terraform_remote_state.history_processing[0]
  values = {
    outputs = {
      lifecycle_contract = { schema_version = 1, environment = "dev", deployed = true, active = false }
    }
  }
}
run "runtime_is_scoped_without_http" {
  command = plan
  assert {
    condition     = local.account_export_runtime_enabled && !output.account_export_candidate_contract.scoped_http_available && !output.account_export_candidate_contract.full_account_export_available && !output.account_export_candidate_contract.runtime_attested_by_terraform && length(aws_apigatewayv2_route.account_export) == 0 && length(aws_lambda_permission.account_export_gateway) == 0 && aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_HTTP_SUBJECTS_JSON == "[\"0199abcd-1234-7000-8000-111111111111\"]" && aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_PLAY_TOKENS_ENABLED == "true" && aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DELETION_ENABLED == "false" && aws_lambda_function.analysis.environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "false"
    error_message = "Private candidate.3 qualification must remain subject-scoped without opening HTTP or changing other gates."
  }
}
run "api_has_exact_jwt_route_and_throttle" {
  command = plan
  variables {
    account_export_activation = {
      phase               = "api"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = ["0199abcd-1234-7000-8000-111111111111"]
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      contract_reference  = "synthetic-contract"
      runtime_reference   = "synthetic-runtime"
    }
  }
  override_resource {
    target          = aws_apigatewayv2_api.age_attestation
    override_during = plan
    values          = { execution_arn = "arn:aws:execute-api:us-east-1:107827791950:synthetic" }
  }
  assert {
    condition     = output.account_export_candidate_contract.scoped_http_available && aws_apigatewayv2_route.account_export[0].route_key == "POST /v1/users/account-export" && aws_apigatewayv2_route.account_export[0].authorization_type == "JWT" && aws_apigatewayv2_route.account_export[0].authorization_scopes == toset(["aws.cognito.signin.user.admin"]) && aws_lambda_permission.account_export_gateway[0].source_account == "107827791950" && aws_lambda_permission.account_export_gateway[0].source_arn == "arn:aws:execute-api:us-east-1:107827791950:synthetic/*/POST/v1/users/account-export" && one([for r in aws_apigatewayv2_stage.age_attestation.route_settings : r if r.route_key == "POST /v1/users/account-export"]).throttling_rate_limit == 2 && one([for r in aws_apigatewayv2_stage.age_attestation.route_settings : r if r.route_key == "POST /v1/users/account-export"]).throttling_burst_limit == 4
    error_message = "API admission must use JWT plus scope, exact account/POST invocation and bounded route throttling."
  }
}
run "null_rolls_back_to_closed" {
  command = plan
  variables { account_export_activation = null }
  assert {
    condition     = !local.account_export_runtime_enabled && length(aws_apigatewayv2_route.account_export) == 0 && aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_ENABLED == "false" && aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_HTTP_SUBJECTS_JSON == "[]"
    error_message = "Null must disable export and remove route/subjects."
  }
}
run "quiescence_overrides_export_activation" {
  command = plan
  variables { campaign_period_work_quiescence = true }
  assert {
    condition     = !local.account_export_runtime_enabled && aws_lambda_function.account_export[0].reserved_concurrent_executions == 0 && aws_lambda_function.account_export[0].environment[0].variables.ACCOUNT_EXPORT_ENABLED == "false" && aws_lambda_function.account_export[0].environment[0].variables.CAMPAIGN_PERIOD_WORK_ENABLED == "false"
    error_message = "Existing work pause must stop export capacity and both runtime gates."
  }
}
run "missing_history_is_not_empty_inventory" {
  command = plan
  variables { history_deployment = null }
  expect_failures = [var.account_export_activation]
}
run "missing_play_is_not_empty_inventory" {
  command = plan
  variables { account_export_play_token_table_arn = null }
  expect_failures = [var.account_export_activation]
}
run "missing_monitoring_rejected" {
  command = plan
  variables { account_export_monitoring = null }
  expect_failures = [var.account_export_activation]
}
run "missing_work_inventory_rejected" {
  command = plan
  variables { campaign_period_work_activation = null }
  expect_failures = [var.account_export_activation]
}
run "reviewed_read_only_source_pair" {
  command = plan
  variables {
    account_export_activation = null
    account_export_deployment = {
      release_id                = "2222222222222222222222222222222222222222"
      object_version            = "new-export"
      source_hash               = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference        = "synthetic-reader-review"
      promotion_approved        = false
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    }
    account_export_work_compatibility = {
      work_source_sha   = "1111111111111111111111111111111111111111"
      export_source_sha = "2222222222222222222222222222222222222222"
      review_reference  = "synthetic-exact-pair-review"
    }
  }
  assert {
    condition     = aws_lambda_function.account_data[0].s3_key == "releases/1111111111111111111111111111111111111111/account_data_api.zip" && aws_lambda_function.account_export[0].s3_key == "releases/2222222222222222222222222222222222222222/account_export_api.zip" && alltrue([for st in data.aws_iam_policy_document.period_work_export[0].statement : length(setsubtract(toset(st.actions), toset(["dynamodb:GetItem", "dynamodb:DescribeTable"]))) == 0])
    error_message = "Reviewed read-only export upgrade must preserve installed writers and least privilege."
  }
}
run "stale_override_fails_even_with_matching_deployments" {
  command = plan
  variables {
    account_export_work_compatibility = {
      work_source_sha   = "1111111111111111111111111111111111111111"
      export_source_sha = "2222222222222222222222222222222222222222"
      review_reference  = "synthetic-stale-review"
    }
  }
  expect_failures = [var.account_export_work_compatibility]
}

run "rejects_empty_scope" {
  command = plan
  variables {
    account_export_activation = {
      phase               = "runtime"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = []
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      contract_reference  = "synthetic-contract"
    }
  }
  expect_failures = [var.account_export_activation]
}

run "rejects_oversized_scope" {
  command = plan
  variables {
    account_export_activation = {
      phase               = "runtime"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = ["0199abcd-1234-7000-8000-000000000000", "0199abcd-1234-7000-8000-000000000001", "0199abcd-1234-7000-8000-000000000002", "0199abcd-1234-7000-8000-000000000003", "0199abcd-1234-7000-8000-000000000004", "0199abcd-1234-7000-8000-000000000005", "0199abcd-1234-7000-8000-000000000006", "0199abcd-1234-7000-8000-000000000007", "0199abcd-1234-7000-8000-000000000008", "0199abcd-1234-7000-8000-000000000009", "0199abcd-1234-7000-8000-000000000010"]
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      contract_reference  = "synthetic-contract"
    }
  }
  expect_failures = [var.account_export_activation]
}

run "rejects_noncanonical_scope" {
  command = plan
  variables {
    account_export_activation = {
      phase               = "runtime"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = ["0199ABCD-1234-7000-8000-111111111111"]
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      contract_reference  = "synthetic-contract"
    }
  }
  expect_failures = [var.account_export_activation]
}

run "rejects_stale_export_source" {
  command = plan
  variables {
    account_export_activation = {
      phase               = "runtime"
      source_sha          = "2222222222222222222222222222222222222222"
      http_subjects       = ["0199abcd-1234-7000-8000-111111111111"]
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      contract_reference  = "synthetic-contract"
    }
  }
  expect_failures = [var.account_export_activation]
}

run "rejects_missing_inventory_evidence" {
  command = plan
  variables {
    account_export_activation = {
      phase               = "runtime"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = ["0199abcd-1234-7000-8000-111111111111"]
      policy_reference    = "synthetic-policy"
      inventory_reference = " "
      identity_reference  = "synthetic-identity"
      contract_reference  = "synthetic-contract"
    }
  }
  expect_failures = [var.account_export_activation]
}

run "rejects_api_without_runtime_evidence" {
  command = plan
  variables {
    account_export_activation = {
      phase               = "api"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = ["0199abcd-1234-7000-8000-111111111111"]
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      contract_reference  = "synthetic-contract"
    }
  }
  expect_failures = [var.account_export_activation]
}

run "rejects_unknown_phase" {
  command = plan
  variables {
    account_export_activation = {
      phase               = "general"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = ["0199abcd-1234-7000-8000-111111111111"]
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      contract_reference  = "synthetic-contract"
    }
  }
  expect_failures = [var.account_export_activation]
}

run "compatibility_cannot_change_writer_source" {
  command = plan
  variables {
    account_export_work_compatibility = {
      work_source_sha   = "2222222222222222222222222222222222222222"
      export_source_sha = "1111111111111111111111111111111111111111"
      review_reference  = "synthetic-stale-writer"
    }
  }
  expect_failures = [var.account_export_work_compatibility]
}
run "compatibility_requires_selected_work" {
  command = plan
  variables {
    account_export_activation       = null
    campaign_period_work_activation = null
    account_export_work_compatibility = {
      work_source_sha   = "1111111111111111111111111111111111111111"
      export_source_sha = "1111111111111111111111111111111111111111"
      review_reference  = "synthetic-no-work"
    }
  }
  expect_failures = [aws_lambda_function.account_export]
}
