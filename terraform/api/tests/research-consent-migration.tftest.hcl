mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  aws_region          = "us-east-1"
  project_name        = "trustcheckradar"
  environment         = "dev"
  state_bucket_name   = "terraform-state-example"
  state_bucket_region = "us-east-1"
  artifact_release    = "2026.09.07-1"
}

override_data {
  target = data.terraform_remote_state.foundation
  values = {
    outputs = {
      downstream_contract = {
        schema_version                    = 1
        artifact_bucket_name              = "artifact-example"
        cognito_user_pool_id              = "us-east-1_example"
        cognito_app_client_id             = "client-example"
        users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
        users_table_name                  = "trustcheckradar-dev-users"
        deletion_ledger_stream_arn        = null
        deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
        deletion_ledger_table_name        = "trustcheckradar-dev-deletion-ledger"
        analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-analysis-abuse-control"
        analysis_abuse_control_table_name = "trustcheckradar-dev-analysis-abuse-control"
        purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
        purchase_entitlements_table_name  = "trustcheckradar-dev-purchase-entitlements"
        device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
        device_bindings_table_name        = "trustcheckradar-dev-device-bindings"
        web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-web-risk-cache"
        web_risk_cache_table_name         = "trustcheckradar-dev-web-risk-cache"
      }
    }
  }
}


override_data {
  target = data.aws_caller_identity.account_fence
  values = { account_id = "107827791950" }
}

run "null_preserves_legacy_configuration" {
  command = plan
  assert {
    condition     = length(aws_iam_role_policy.research_migration_boundary) == 0 && !output.research_consent_migration_contract.selected && !contains(keys(aws_lambda_function.campaign_participation.environment[0].variables), "CONSENT_INDEPENDENCE_ENABLED") && aws_lambda_function.campaign_participation.environment[0].variables.CAMPAIGN_PARTICIPATION_NOTICE_VERSION == "2026-09-07"
    error_message = "An unset migration must not retire legacy access or switch consent versions."
  }
}

run "coordinated_candidate_is_pinned_and_consent_stays_closed" {
  command = plan
  variables {
    enable_web_risk_communication     = true
    campaign_participation_lambda_env = { CONSENT_INDEPENDENCE_ENABLED = "true", CAMPAIGN_PARTICIPATION_NOTICE_VERSION = "unreviewed" }
    analysis_lambda_env               = { HISTORY_WRITES_ENABLED = "true", RECOGNITION_ENABLED = "true" }
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
    condition     = alltrue([for fn in [aws_lambda_function.analysis, aws_lambda_function.campaign_participation, aws_lambda_function.entitlement_snapshot, aws_lambda_function.web_risk_communication[0], aws_lambda_function.purchase_handoff] : fn.runtime == "python3.14" && startswith(fn.s3_key, "releases/research-migration-reviewed/") && fn.s3_object_version != null && fn.source_code_hash != null]) && aws_lambda_function.analysis.s3_key == "releases/research-migration-reviewed/conversation_analysis.zip"
    error_message = "All legacy candidates require immutable per-artifact pins and Python 3.14."
  }
  assert {
    condition     = aws_lambda_function.campaign_participation.environment[0].variables.CONSENT_INDEPENDENCE_ENABLED == "false" && aws_lambda_function.campaign_participation.environment[0].variables.CAMPAIGN_PARTICIPATION_NOTICE_VERSION == "research-consent-2026-09-21-v2" && aws_lambda_function.campaign_participation.environment[0].variables.CAMPAIGN_PARTICIPATION_POLICY_VERSION == "independent-research-v1" && aws_lambda_function.analysis.environment[0].variables.HISTORY_WRITES_ENABLED == "false" && aws_lambda_function.analysis.environment[0].variables.RECOGNITION_ENABLED == "false" && !output.research_consent_migration_contract.live_qualified
    error_message = "General environment maps cannot enable new consent or revive legacy writers."
  }
  assert {
    condition     = aws_apigatewayv2_route.campaign_participation_get.route_key == "GET /v1/users/campaign-participation" && aws_apigatewayv2_route.campaign_participation_put.authorization_type == "JWT" && aws_apigatewayv2_route.analysis.authorization_type == "JWT" && aws_apigatewayv2_route.web_risk_communication[0].authorization_type == "JWT"
    error_message = "Cutover must preserve authenticated route boundaries."
  }
  assert {
    condition     = alltrue([for st in data.aws_iam_policy_document.campaign_participation_runtime.statement : !contains(st.resources, local.purchase_entitlements_table_arn) && !contains(st.resources, "${local.purchase_entitlements_table_arn}/index/*")]) && alltrue([for st in data.aws_iam_policy_document.campaign_participation_runtime.statement : anytrue([for c in st.condition : c.variable == "dynamodb:LeadingKeys"])]) && alltrue([for st in data.aws_iam_policy_document.campaign_participation_runtime.statement : !contains(st.actions, "dynamodb:PutItem") || anytrue([for c in st.condition : c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])])])
    error_message = "Consent gets no entitlement access; all operations must be partition-scoped and writes transaction-only."
  }
  assert {
    condition     = length(aws_iam_role_policy.research_migration_boundary) == 4 && alltrue([for k, doc in data.aws_iam_policy_document.research_migration_boundary : anytrue([for st in doc.statement : st.sid == "DenyProviderCredentialsAndDispatch" && st.effect == "Deny" && contains(st.actions, "secretsmanager:GetSecretValue")])]) && alltrue([for k in ["analysis", "snapshot", "web_risk"] : anytrue([for st in data.aws_iam_policy_document.research_migration_boundary[k].statement : st.sid == "DenyLegacySettlementAndWrites" && st.effect == "Deny" && contains(st.actions, "dynamodb:PutItem") && contains(st.actions, "dynamodb:UpdateItem")])]) && anytrue([for st in data.aws_iam_policy_document.research_migration_boundary["web_risk"].statement : st.sid == "DenyRetiredDirectLookupDataAccess" && st.effect == "Deny"])
    error_message = "Legacy replay/snapshot cannot charge/write and the retired direct lookup cannot use provider credentials or caches."
  }
  assert {
    condition     = aws_lambda_function.purchase_handoff.s3_key == "releases/research-migration-reviewed/purchase_handoff.zip" && aws_lambda_function.purchase_handoff.environment[0].variables.PURCHASE_OWNERSHIP_CANDIDATE_ENABLED == "false" && aws_lambda_function.purchase_handoff.environment[0].variables.DELETION_LEDGER_TABLE_NAME == "trustcheckradar-dev-deletion-ledger" && alltrue([for st in data.aws_iam_policy_document.purchase_handoff_runtime.statement : !contains(st.actions, "dynamodb:PutItem") || anytrue([for c in st.condition : c.variable == "dynamodb:EnclosingOperation" && toset(c.values) == toset(["TransactWriteItems"])])])
    error_message = "The revised purchase helper must ship in the same release with deletion guards and transaction-only writes; selecting it cannot approve ownership migration."
  }

}

run "missing_artifact_is_rejected" {
  command = plan
  variables {

    research_consent_migration_deployment = {
      release_id         = "research-migration-reviewed"
      approval_reference = "synthetic-contract-review"
      promotion_approved = false
      artifacts = {
        analysis      = { object_version = "analysis-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        participation = { object_version = "participation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
        snapshot      = { object_version = "snapshot-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }

      }
    }
  }
  expect_failures = [var.research_consent_migration_deployment]
}

run "unpinned_version_is_rejected" {
  command = plan
  variables {

    research_consent_migration_deployment = {
      release_id         = "research-migration-reviewed"
      approval_reference = "synthetic-contract-review"
      promotion_approved = false
      artifacts = {
        analysis      = { object_version = "null", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        participation = { object_version = "participation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
        snapshot      = { object_version = "snapshot-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
        purchase      = { object_version = "purchase-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        web_risk      = { object_version = "webrisk-version", source_hash = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=" }
      }
    }
  }
  expect_failures = [var.research_consent_migration_deployment]
}

run "invalid_hash_is_rejected" {
  command = plan
  variables {

    research_consent_migration_deployment = {
      release_id         = "research-migration-reviewed"
      approval_reference = "synthetic-contract-review"
      promotion_approved = false
      artifacts = {
        analysis      = { object_version = "analysis-version", source_hash = "not-a-hash" }
        participation = { object_version = "participation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
        snapshot      = { object_version = "snapshot-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
        purchase      = { object_version = "purchase-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        web_risk      = { object_version = "webrisk-version", source_hash = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=" }
      }
    }
  }
  expect_failures = [var.research_consent_migration_deployment]
}

run "unreviewed_consent_activation_is_rejected" {
  command = plan
  variables {

    research_consent_migration_deployment = {
      release_id         = "research-migration-reviewed"
      approval_reference = "synthetic-contract-review"
      promotion_approved = false
      consent_enabled    = true
      artifacts = {
        analysis      = { object_version = "analysis-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        participation = { object_version = "participation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
        snapshot      = { object_version = "snapshot-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
        purchase      = { object_version = "purchase-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        web_risk      = { object_version = "webrisk-version", source_hash = "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=" }
      }
    }
  }
  expect_failures = [var.research_consent_migration_deployment]
}

run "unapproved_uat_is_rejected" {
  command = plan
  variables {
    environment = "uat"
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
  expect_failures = [var.research_consent_migration_deployment]
}

run "active_history_writer_is_rejected" {
  command = plan
  variables {
    history_features = { reads = false, writes = true, mutations = false, recognition = false, durable_replay = true }
    history_deployment = {
      release_id         = "old-history"
      approval_reference = "synthetic-history-review"
      promotion_approved = false
      artifacts = {
        read     = { object_version = "read", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        mutation = { object_version = "mutation", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        analysis = { object_version = "analysis", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      }
    }
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
  expect_failures = [var.research_consent_migration_deployment]
}

run "explicitly_reviewed_consent_activation_is_separate" {
  command = plan
  variables {
    research_consent_migration_deployment = {
      release_id                 = "research-migration-reviewed"
      approval_reference         = "synthetic-contract-review"
      promotion_approved         = false
      consent_enabled            = true
      consent_approval_reference = "synthetic-notice-lifecycle-review"
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
    condition     = output.research_consent_migration_contract.consent_enabled && aws_lambda_function.campaign_participation.environment[0].variables.CONSENT_INDEPENDENCE_ENABLED == "true" && !output.research_consent_migration_contract.inventory_approved
    error_message = "Consent activation must be explicitly selected and cannot approve inventory."
  }
}

override_data {
  target = data.terraform_remote_state.research_campaign_processing
  values = {
    outputs = {
      research_consent_migration_contract = {
        selected         = true
        environment      = "dev"
        account_id       = "107827791950"
        release_id       = "research-migration-reviewed"
        consumers_paused = true
      }
    }
  }
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
      lifecycle_contract = { schema_version = 1, environment = "dev", deployed = true, active = true, account_deletion_active = true }
    }
  }
}


run "active_campaign_pipeline_is_rejected" {
  command = plan
  variables {
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
  override_data {
    target = data.terraform_remote_state.research_campaign_processing
    values = { outputs = { research_consent_migration_contract = {
      selected         = true
      environment      = "dev"
      account_id       = "107827791950"
      release_id       = "research-migration-reviewed"
      consumers_paused = false
    } } }
  }
  expect_failures = [terraform_data.research_migration_cutover]
}

run "different_worker_release_is_rejected" {
  command = plan
  variables {
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
  override_data {
    target = data.terraform_remote_state.research_campaign_processing
    values = { outputs = { research_consent_migration_contract = {
      selected         = true
      environment      = "dev"
      account_id       = "107827791950"
      release_id       = "different-release"
      consumers_paused = true
    } } }
  }
  expect_failures = [terraform_data.research_migration_cutover]
}

run "foreign_worker_account_is_rejected" {
  command = plan
  variables {
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
  override_data {
    target = data.terraform_remote_state.research_campaign_processing
    values = { outputs = { research_consent_migration_contract = {
      selected         = true
      environment      = "dev"
      account_id       = "000000000000"
      release_id       = "research-migration-reviewed"
      consumers_paused = true
    } } }
  }
  expect_failures = [terraform_data.research_migration_cutover]
}
