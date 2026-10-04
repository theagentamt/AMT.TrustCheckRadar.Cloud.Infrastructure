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
  target = data.aws_caller_identity.account_fence
  values = { account_id = "107827791950" }
}
override_resource {
  target          = aws_apigatewayv2_api.age_attestation
  override_during = plan
  values          = { execution_arn = "arn:aws:execute-api:us-east-1:107827791950:example1234" }
}
override_resource {
  target          = aws_lambda_function.analysis
  override_during = plan
  values          = { version = "4" }
}
override_resource {
  target          = aws_lambda_alias.analysis_retired[0]
  override_during = plan
  values          = { invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-conversation-analysis:retired/invocations" }
}
run "reviewed_retirement_is_qualified_and_cannot_resurrect_dispatch" {
  command = plan
  variables {
    analysis_legacy_path_enabled = false
    analysis_lambda_env          = { FREE_MONTHLY_SCAN_LIMIT = "999", OPENAI_SECRET_ARN = "attacker", HISTORY_WRITES_ENABLED = "true", ENTITLEMENTS_TABLE_NAME = "old-free-tier", CAMPAIGN_OUTBOX_TABLE_NAME = "outbox" }
  }
  assert {
    condition = (aws_lambda_function.analysis.publish && aws_lambda_function.analysis.source_code_hash == var.analysis_retirement_deployment.source_hash &&
      aws_lambda_function.analysis.s3_object_version == var.analysis_retirement_deployment.object_version &&
      aws_lambda_alias.analysis_retired[0].function_version == "4" && length(aws_lambda_alias.analysis_retired[0].routing_config) == 0 &&
      aws_apigatewayv2_integration.analysis_lambda.integration_uri == aws_lambda_alias.analysis_retired[0].invoke_arn &&
      aws_lambda_permission.allow_api_gateway_invoke_analysis[0].qualifier == "retired" &&
      aws_lambda_permission.allow_api_gateway_invoke_analysis[0].source_account == "107827791950" &&
      endswith(aws_lambda_permission.allow_api_gateway_invoke_analysis[0].source_arn, "/$default/POST/analysis") &&
    length(aws_lambda_permission.allow_api_gateway_invoke_analysis_legacy) == 0)
    error_message = "Replay must pin qualified immutable code and exact same-account POST routes, with no weighted/latest dispatch."
  }
  assert {
    condition = (alltrue([for key in ["FREE_MONTHLY_SCAN_LIMIT", "OPENAI_SECRET_ARN", "OPENAI_SECRET_NAME", "ENTITLEMENTS_TABLE_NAME", "CAMPAIGN_OUTBOX_TABLE_NAME"] : !contains(keys(aws_lambda_function.analysis.environment[0].variables), key)]) &&
      aws_lambda_function.analysis.environment[0].variables.HISTORY_WRITES_ENABLED == "false" &&
      alltrue([for st in data.aws_iam_policy_document.analysis_runtime.statement : st.effect != "Allow" ||
      (toset(st.actions) == toset(["dynamodb:GetItem"]) && length(st.condition) == 1 && !contains(st.resources, "*"))]) &&
      anytrue([for st in data.aws_iam_policy_document.analysis_runtime.statement : st.effect == "Deny" && contains(st.actions, "lambda:InvokeFunction") && contains(st.actions, "secretsmanager:GetSecretValue")]) &&
    anytrue([for st in data.aws_iam_policy_document.analysis_runtime.statement : st.effect == "Deny" && contains(st.actions, "dynamodb:PutItem") && contains(st.actions, "dynamodb:Query")]))
    error_message = "Legacy env injection cannot restore quotas, provider secrets, settlement, campaign writes or broad database reads."
  }
}
run "missing_pin_blocks_plan" {
  command = plan
  variables { analysis_retirement_deployment = null }
  expect_failures = [aws_lambda_function.analysis]
}
run "generic_release_cannot_rollback_retirement" {
  command = plan
  variables {
    artifact_release                  = "pre-retirement-release"
    analysis_lambda_s3_key            = "legacy-provider.zip"
    analysis_lambda_s3_object_version = "old-version"
  }
  assert {
    condition = (aws_lambda_function.analysis.s3_key == "releases/d98ffd65b42d54953ad83e980e58846b6fc02c5d/conversation_analysis.zip" &&
    aws_lambda_function.analysis.source_code_hash == var.analysis_retirement_deployment.source_hash && aws_lambda_function.analysis.s3_object_version == "K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1")
    error_message = "Generic or History inputs cannot repin retired analysis."
  }
}
run "forged_known_revision_hash_is_rejected" {
  command = plan
  variables {
    analysis_retirement_deployment = { release_id = "d98ffd65b42d54953ad83e980e58846b6fc02c5d", object_version = "forged-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", approval_reference = "caller-claimed-approval", promotion_approved = true }
  }
  expect_failures = [aws_lambda_function.analysis]
}
run "unknown_revision_is_rejected" {
  command = plan
  variables {
    analysis_retirement_deployment = { release_id = "1111111111111111111111111111111111111111", object_version = "forged-version", source_hash = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4=", approval_reference = "caller-claimed-approval", promotion_approved = true }
  }
  expect_failures = [aws_lambda_function.analysis]
}
run "uat_requires_promotion_approval" {
  command = plan
  variables {
    environment                    = "uat"
    analysis_retirement_deployment = { release_id = "d98ffd65b42d54953ad83e980e58846b6fc02c5d", object_version = "K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1", source_hash = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4=", approval_reference = "review", promotion_approved = false }
  }
  expect_failures = [var.analysis_retirement_deployment]
}
run "prod_requires_promotion_approval" {
  command = plan
  variables {
    environment                    = "prod"
    analysis_retirement_deployment = { release_id = "d98ffd65b42d54953ad83e980e58846b6fc02c5d", object_version = "K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1", source_hash = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4=", approval_reference = "review", promotion_approved = false }
  }
  expect_failures = [var.analysis_retirement_deployment]
}
run "forged_object_version_is_rejected" {
  command = plan
  variables {
    analysis_retirement_deployment = { release_id = "d98ffd65b42d54953ad83e980e58846b6fc02c5d", object_version = "another-archive-version", source_hash = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4=", approval_reference = "review", promotion_approved = true }
  }
  expect_failures = [aws_lambda_function.analysis]
}
run "changed_primary_path_is_rejected" {
  command = plan
  variables { analysis_primary_path = "/another-analysis" }
  expect_failures = [var.analysis_primary_path]
}
run "uat_cannot_use_dev_catalog_even_with_claimed_approval" {
  command = plan
  variables { environment = "uat" }
  expect_failures = [aws_lambda_function.analysis]
}
run "prod_cannot_use_dev_catalog_even_with_claimed_approval" {
  command = plan
  variables { environment = "prod" }
  expect_failures = [aws_lambda_function.analysis]
}
run "mismatched_dual_retirement_inputs_are_rejected" {
  command = plan
  variables {
    research_consent_migration_deployment = {
      release_id         = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
      approval_reference = "synthetic-review"
      promotion_approved = false
      artifacts = {
        analysis      = { object_version = "different-version", source_hash = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4=" }
        participation = { object_version = "p", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        snapshot      = { object_version = "s", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        purchase      = { object_version = "b", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        web_risk      = { object_version = "w", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      }
    }
  }
  expect_failures = [var.analysis_retirement_deployment]
}
run "matching_dual_retirement_preserves_other_coordinated_pins" {
  command = plan
  variables {
    research_consent_migration_deployment = {
      release_id         = "d98ffd65b42d54953ad83e980e58846b6fc02c5d"
      approval_reference = "synthetic-review"
      promotion_approved = false
      artifacts = {
        analysis      = { object_version = "K6SXSdTc6rYObyN4qxbRVGTbsNvxAuU1", source_hash = "vMGNoWsUlbRK+JWlONEQ8tAjK+XvsOeyO4wYmKAn0O4=" }
        participation = { object_version = "p", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        snapshot      = { object_version = "s", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        purchase      = { object_version = "b", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        web_risk      = { object_version = "w", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      }
    }
  }
  assert {
    condition     = aws_lambda_function.campaign_participation.s3_key == "releases/d98ffd65b42d54953ad83e980e58846b6fc02c5d/campaign_participation.zip" && aws_lambda_function.campaign_participation.environment[0].variables.CONSENT_INDEPENDENCE_ENABLED == "false" && length(aws_iam_role_policy.research_migration_boundary) == 4
    error_message = "Matching selectors preserve all existing coordinated retirement pins and fences."
  }
}
run "legacy_route_cannot_be_reactivated" {
  command = plan
  variables { analysis_legacy_path_enabled = true }
  expect_failures = [var.analysis_legacy_path_enabled]
}
