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
    release_id         = "1111111111111111111111111111111111111111"
    object_version     = "synthetic-version"
    source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
  }
  account_data_finalization_candidate = {
    manifest_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    inventory_revision = 1
    approval_reference = "synthetic-inventory"
  }
  account_data_monitoring = { alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:synthetic-alerts" }
  account_deletion_activation = {
    phase               = "workers"
    source_sha          = "1111111111111111111111111111111111111111"
    policy_reference    = "synthetic-policy"
    inventory_reference = "synthetic-inventory"
    identity_reference  = "synthetic-identity"
    component_reference = "synthetic-components"
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


run "null_leaves_candidate_closed" {
  command = plan
  variables { account_deletion_activation = null }
  assert {
    condition     = (!output.account_data_candidate_contract.enabled && !output.account_data_candidate_contract.workers_enabled && length(aws_apigatewayv2_route.account_deletion) == 0 && length(aws_lambda_permission.account_deletion_gateway) == 0 && aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DELETION_ENABLED == "false")
    error_message = "Null must retain the closed candidate without public routes."
  }
}
run "workers_enable_reconciliation_before_admission" {
  command = plan
  assert {
    condition     = (!output.account_data_candidate_contract.enabled && output.account_data_candidate_contract.workers_enabled && length(aws_apigatewayv2_route.account_deletion) == 0 && length(aws_lambda_permission.account_deletion_gateway) == 0 && aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DELETION_HTTP_SUBJECTS_JSON == "[]" && aws_lambda_event_source_mapping.account_data_revocation[0].enabled && aws_cloudwatch_event_rule.account_data_reconcile[0].state == "ENABLED" && aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_IDENTITY_FINALIZER_ENABLED == "true" && aws_lambda_function.account_data[0].environment[0].variables.CAMPAIGN_RECOVERY_WRITES_ENABLED == "true" && length(jsondecode(aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DELETION_REQUIRED_COMPONENTS_JSON)) == 12 && aws_cloudwatch_metric_alarm.account_data_reconciliation["heartbeat"].actions_enabled && aws_cloudwatch_metric_alarm.account_data_reconciliation["heartbeat"].treat_missing_data == "breaching" && aws_lambda_function.campaign_participation.environment[0].variables.CAMPAIGN_RECOVERY_WRITES_ENABLED == "false")
    error_message = "Workers must enable durable reconciliation and heartbeat monitoring without opening routes or other producer gates."
  }
}
run "api_requires_prior_worker_evidence" {
  command = plan
  variables {
    account_deletion_activation = {
      phase               = "api"
      source_sha          = "1111111111111111111111111111111111111111"
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      component_reference = "synthetic-components"
    }
  }
  expect_failures = [var.account_deletion_activation]
}
run "api_exposes_only_authenticated_exact_routes" {
  command = plan
  variables {
    account_deletion_activation = {
      phase                       = "api"
      source_sha                  = "1111111111111111111111111111111111111111"
      policy_reference            = "synthetic-policy"
      inventory_reference         = "synthetic-inventory"
      identity_reference          = "synthetic-identity"
      component_reference         = "synthetic-components"
      worker_acceptance_reference = "synthetic-deployed-worker-evidence"
      http_subjects               = ["01959cef-9123-7abc-8def-0123456789ab"]
    }
  }
  assert {
    condition     = (aws_lambda_function.account_data[0].environment[0].variables.ACCOUNT_DELETION_HTTP_SUBJECTS_JSON == jsonencode(["01959cef-9123-7abc-8def-0123456789ab"]) && output.account_data_candidate_contract.enabled && toset(output.account_data_candidate_contract.routes) == toset(["GET /v1/users/account-deletion", "POST /v1/users/account-deletion"]) && alltrue([for route in aws_apigatewayv2_route.account_deletion : route.authorization_type == "JWT" && route.authorization_scopes == toset(["aws.cognito.signin.user.admin"])]) && length(aws_lambda_permission.account_deletion_gateway) == 2 && alltrue([for permission in aws_lambda_permission.account_deletion_gateway : permission.principal == "apigateway.amazonaws.com" && permission.source_account == "107827791950" && endswith(permission.source_arn, "/v1/users/account-deletion") && !endswith(permission.source_arn, "*")]) && aws_apigatewayv2_integration.account_deletion[0].payload_format_version == "2.0")
    error_message = "Only scoped JWT GET and POST routes may invoke the activated account-data function."
  }
}
run "reject_missing_finalizer_pins" {
  command = plan
  variables { account_data_finalization_candidate = null }
  expect_failures = [var.account_deletion_activation]
}
run "reject_missing_monitoring" {
  command = plan
  variables { account_data_monitoring = null }
  expect_failures = [var.account_deletion_activation]
}
run "reject_unprepared_recovery" {
  command = plan
  variables { campaign_recovery_preparation = null }
  expect_failures = [var.account_deletion_activation]
}
run "reject_mismatched_source" {
  command = plan
  variables {
    account_deletion_activation = {
      phase               = "workers"
      source_sha          = "2222222222222222222222222222222222222222"
      policy_reference    = "synthetic-policy"
      inventory_reference = "synthetic-inventory"
      identity_reference  = "synthetic-identity"
      component_reference = "synthetic-components"
    }
  }
  expect_failures = [var.account_deletion_activation]
}

run "reject_unsupported_phase" {
  command = plan
  variables { account_deletion_activation = {
    phase              = "accept-only", source_sha = "1111111111111111111111111111111111111111"
    policy_reference   = "synthetic-policy", inventory_reference = "synthetic-inventory"
    identity_reference = "synthetic-identity", component_reference = "synthetic-components"
  } }
  expect_failures = [var.account_deletion_activation]
}
run "reject_unreviewed_identity" {
  command = plan
  variables { account_deletion_activation = {
    phase              = "workers", source_sha = "1111111111111111111111111111111111111111"
    policy_reference   = "synthetic-policy", inventory_reference = "synthetic-inventory"
    identity_reference = " ", component_reference = "synthetic-components"
  } }
  expect_failures = [var.account_deletion_activation]
}

override_resource {
  target          = aws_apigatewayv2_api.age_attestation
  override_during = plan
  values          = { execution_arn = "arn:aws:execute-api:us-east-1:107827791950:synthetic-api", id = "synthetic-api" }
}

run "reject_missing_recovery_contract" {
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
        schema_version = 2
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
  expect_failures = [var.account_deletion_activation]
}

run "reject_foreign_outbox" {
  command = plan
  override_data {
    target = data.terraform_remote_state.campaign_data[0]
    values = { outputs = { downstream_contract = {
      schema_version        = 1, environment = "dev", enabled = true
      outbox_table_name     = "trustcheckradar-dev-campaign-outbox"
      outbox_table_arn      = "arn:aws:dynamodb:us-east-1:000000000000:table/trustcheckradar-dev-campaign-outbox"
      transient_kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
    } } }
  }
  expect_failures = [var.account_deletion_activation]
}

run "reject_missing_deletion_stream" {
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
      deletion_ledger_stream_arn        = ""
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
  expect_failures = [aws_lambda_function.account_data]
}

run "api_rejects_unscoped_admission" {
  command = plan
  variables {
    account_deletion_activation = {
      phase                       = "api"
      source_sha                  = "1111111111111111111111111111111111111111"
      policy_reference            = "synthetic-policy"
      inventory_reference         = "synthetic-inventory"
      identity_reference          = "synthetic-identity"
      component_reference         = "synthetic-components"
      worker_acceptance_reference = "synthetic-deployed-worker-evidence"
      http_subjects               = []
    }
  }
  expect_failures = [var.account_deletion_activation]
}

run "api_rejects_malformed_subject" {
  command = plan
  variables {
    account_deletion_activation = {
      phase                       = "api"
      source_sha                  = "1111111111111111111111111111111111111111"
      policy_reference            = "synthetic-policy"
      inventory_reference         = "synthetic-inventory"
      identity_reference          = "synthetic-identity"
      component_reference         = "synthetic-components"
      worker_acceptance_reference = "synthetic-deployed-worker-evidence"
      http_subjects               = ["not-a-subject"]
    }
  }
  expect_failures = [var.account_deletion_activation]
}

run "api_rejects_noncanonical_subject" {
  command = plan
  variables {
    account_deletion_activation = {
      phase                       = "api"
      source_sha                  = "1111111111111111111111111111111111111111"
      policy_reference            = "synthetic-policy"
      inventory_reference         = "synthetic-inventory"
      identity_reference          = "synthetic-identity"
      component_reference         = "synthetic-components"
      worker_acceptance_reference = "synthetic-deployed-worker-evidence"
      http_subjects               = ["01959CEF-9123-7abc-8def-0123456789ab"]
    }
  }
  expect_failures = [var.account_deletion_activation]
}

run "api_rejects_more_than_ten_subjects" {
  command = plan
  variables {
    account_deletion_activation = {
      phase                       = "api"
      source_sha                  = "1111111111111111111111111111111111111111"
      policy_reference            = "synthetic-policy"
      inventory_reference         = "synthetic-inventory"
      identity_reference          = "synthetic-identity"
      component_reference         = "synthetic-components"
      worker_acceptance_reference = "synthetic-deployed-worker-evidence"
      http_subjects               = [for i in range(11) : format("01959cef-9123-7abc-8def-%012d", i)]
    }
  }
  expect_failures = [var.account_deletion_activation]
}

run "workers_reject_http_subjects" {
  command = plan
  variables {
    account_deletion_activation = {
      phase                       = "workers"
      source_sha                  = "1111111111111111111111111111111111111111"
      policy_reference            = "synthetic-policy"
      inventory_reference         = "synthetic-inventory"
      identity_reference          = "synthetic-identity"
      component_reference         = "synthetic-components"
      worker_acceptance_reference = "synthetic-deployed-worker-evidence"
      http_subjects               = ["01959cef-9123-7abc-8def-0123456789ab"]
    }
  }
  expect_failures = [var.account_deletion_activation]
}
