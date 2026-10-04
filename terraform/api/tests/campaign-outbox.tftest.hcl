mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  analysis_retirement_deployment = {
    release_id         = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
    object_version     = "K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1"
    source_hash        = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4="
    approval_reference = "synthetic-retirement-review"
    promotion_approved = true
  }
  aws_region          = "us-east-1"
  project_name        = "trustcheckradar"
  environment         = "dev"
  state_bucket_name   = "terraform-state-example"
  state_bucket_region = "us-east-1"
  artifact_release    = "2026.09.06-1"
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
        users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/users"
        users_table_name                  = "users"
        deletion_ledger_stream_arn        = null
        deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger"
        deletion_ledger_table_name        = "deletion-ledger"
        analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/analysis-abuse"
        analysis_abuse_control_table_name = "analysis-abuse"
        purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/entitlements"
        purchase_entitlements_table_name  = "entitlements"
        device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/device-bindings"
        device_bindings_table_name        = "device-bindings"
        web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/web-risk-cache"
        web_risk_cache_table_name         = "web-risk-cache"
      }
    }
  }
}

run "retired_analysis_cannot_query_device_bindings_indexes" {
  command = plan
  assert {
    condition = alltrue([for statement in data.aws_iam_policy_document.analysis_runtime.statement :
      statement.effect != "Allow" || (toset(statement.actions) == toset(["dynamodb:GetItem"]) &&
      alltrue([for resource in statement.resources : !strcontains(resource, "/index/")]))
    ])
    error_message = "Retired replay must have only table GetItem reads, without index queries or dispatch/settlement writes."
  }
}

run "disabled_analysis_has_no_campaign_access" {
  command = plan

  variables {
    campaign_intelligence_enabled = false
  }

  assert {
    condition     = length(data.terraform_remote_state.campaign_data) == 0
    error_message = "A disabled API stack must not read campaign state."
  }

  assert {
    condition = !contains(
      keys(aws_lambda_function.analysis.environment[0].variables),
      "CAMPAIGN_OUTBOX_TABLE_NAME",
    )
    error_message = "A disabled analysis Lambda must not receive campaign outbox configuration."
  }
}

run "enabled_analysis_uses_its_environment_outbox" {
  command = plan

  variables {
    campaign_intelligence_enabled = true
  }

  override_data {
    target = data.terraform_remote_state.campaign_data[0]
    values = {
      outputs = {
        downstream_contract = {
          schema_version        = 1
          environment           = "dev"
          enabled               = true
          outbox_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-campaign-outbox"
          outbox_table_name     = "trustcheckradar-dev-campaign-outbox"
          transient_kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111"
        }
      }
    }
  }

  assert {
    condition = (
      local.campaign_outbox_write_actions == ["dynamodb:PutItem"] &&
      local.campaign_outbox_write_enclosing_operations == ["TransactWriteItems"] &&
      local.campaign_outbox_account_id == "107827791950" &&
      contains(local.campaign_outbox_kms_actions, "kms:GenerateDataKey*")
    )
    error_message = "The outbox policy must allow only transactional PutItem writes and same-account CMK use."
  }

  assert {
    condition = (!contains(keys(aws_lambda_function.analysis.environment[0].variables), "CAMPAIGN_OUTBOX_TABLE_NAME") &&
    alltrue([for st in data.aws_iam_policy_document.analysis_runtime.statement : st.effect != "Allow" || !contains(st.resources, local.campaign_outbox_table_arn)]))
    error_message = "Campaign configuration cannot restore outbox access to retired analysis."
  }

}

run "cross_environment_campaign_state_is_rejected" {
  command = plan

  variables {
    campaign_intelligence_enabled = true
  }

  override_data {
    target = data.terraform_remote_state.campaign_data[0]
    values = {
      outputs = {
        downstream_contract = {
          schema_version        = 1
          environment           = "uat"
          enabled               = true
          outbox_table_arn      = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-uat-campaign-outbox"
          outbox_table_name     = "trustcheckradar-uat-campaign-outbox"
          transient_kms_key_arn = "arn:aws:kms:us-east-1:107827791950:key/22222222-2222-2222-2222-222222222222"
        }
      }
    }
  }

  expect_failures = [check.campaign_data_contract_version]
}
