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

  research_consent_migration_deployment = {
    release_id         = "1111111111111111111111111111111111111111"
    approval_reference = "synthetic-closed-migration", promotion_approved = false
    artifacts = {
      analysis      = { object_version = "a", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      participation = { object_version = "p", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      snapshot      = { object_version = "s", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      purchase      = { object_version = "b", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      web_risk      = { object_version = "w", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
    }
  }
  research_campaign_release_compatibility = {
    api_release_sha      = "1111111111111111111111111111111111111111"
    consumer_release_sha = "2222222222222222222222222222222222222222"
    review_reference     = "synthetic-compatible-pair"
  }
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

override_data {
  target = data.terraform_remote_state.research_campaign_processing
  values = {
    outputs = {
      research_consent_migration_contract = {
        selected         = true
        environment      = "dev"
        account_id       = "107827791950"
        release_id       = "2222222222222222222222222222222222222222"
        consumers_paused = true
      }
    }
  }
}


run "reviewed_exact_pair_preserves_api_artifacts" {
  command = plan
  assert {
    condition     = aws_lambda_function.analysis.s3_key == "releases/1111111111111111111111111111111111111111/conversation_analysis.zip" && aws_lambda_function.campaign_participation.environment[0].variables.CONSENT_INDEPENDENCE_ENABLED == "false"
    error_message = "Compatibility must not repin APIs or enable consent."
  }
}
run "default_still_rejects_different_releases" {
  command = plan
  variables { research_campaign_release_compatibility = null }
  expect_failures = [terraform_data.research_migration_cutover]
}
run "reject_stale_api" {
  command = plan
  variables { research_campaign_release_compatibility = { api_release_sha = "3333333333333333333333333333333333333333", consumer_release_sha = "2222222222222222222222222222222222222222", review_reference = "review" } }
  expect_failures = [var.research_campaign_release_compatibility]
}
run "reject_stale_consumer" {
  command = plan
  variables { research_campaign_release_compatibility = { api_release_sha = "1111111111111111111111111111111111111111", consumer_release_sha = "3333333333333333333333333333333333333333", review_reference = "review" } }
  expect_failures = [terraform_data.research_migration_cutover]
}
run "reject_missing_review" {
  command = plan
  variables { research_campaign_release_compatibility = { api_release_sha = "1111111111111111111111111111111111111111", consumer_release_sha = "2222222222222222222222222222222222222222", review_reference = "" } }
  expect_failures = [var.research_campaign_release_compatibility]
}
run "reject_active_consumers" {
  command = plan
  override_data {
    target = data.terraform_remote_state.research_campaign_processing
    values = {
      outputs = {
        research_consent_migration_contract = {
          selected         = true
          environment      = "dev"
          account_id       = "107827791950"
          release_id       = "2222222222222222222222222222222222222222"
          consumers_paused = false
        }
      }
    }
  }


  expect_failures = [terraform_data.research_migration_cutover]
}
run "reject_foreign_account" {
  command = plan
  override_data {
    target = data.terraform_remote_state.research_campaign_processing
    values = {
      outputs = {
        research_consent_migration_contract = {
          selected         = true
          environment      = "dev"
          account_id       = "000000000000"
          release_id       = "2222222222222222222222222222222222222222"
          consumers_paused = true
        }
      }
    }
  }


  expect_failures = [terraform_data.research_migration_cutover]
}
run "reject_wrong_environment" {
  command = plan
  override_data {
    target = data.terraform_remote_state.research_campaign_processing
    values = {
      outputs = {
        research_consent_migration_contract = {
          selected         = true
          environment      = "uat"
          account_id       = "107827791950"
          release_id       = "2222222222222222222222222222222222222222"
          consumers_paused = true
        }
      }
    }
  }


  expect_failures = [terraform_data.research_migration_cutover]
}
run "reject_no_migration" {
  command = plan
  variables { research_consent_migration_deployment = null }
  expect_failures = [var.research_campaign_release_compatibility]
}
