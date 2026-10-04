mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
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
  state_bucket_name   = "synthetic-state"
  state_bucket_region = "us-east-1"
  artifact_release    = "existing-release"
  demographic_research_deployment = {
    release_id         = "1111111111111111111111111111111111111111"
    object_version     = "demographic-version"
    source_hash        = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    approval_reference = "synthetic-test-not-user-approval"
    promotion_approved = false
  }
  demographic_research_monitoring = {
    alarm_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
  }
}

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
    web_risk_cache_table_name         = "trustcheckradar-dev-web-risk-cache"
    web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-web-risk-cache"
  } } }
}

override_resource {
  target          = aws_apigatewayv2_api.age_attestation
  override_during = plan
  values = {
    id            = "abcdefghij"
    execution_arn = "arn:aws:execute-api:us-east-1:107827791950:abcdefghij"
  }
}

run "installed_candidate_is_closed" {
  command = plan

  assert {
    condition = (
      aws_lambda_function.demographic_research[0].runtime == "python3.14" &&
      aws_lambda_function.demographic_research[0].architectures == tolist(["arm64"]) &&
      aws_lambda_function.demographic_research[0].s3_key == "releases/1111111111111111111111111111111111111111/demographic_research.zip" &&
      aws_lambda_function.demographic_research[0].s3_object_version == "demographic-version" &&
      aws_lambda_function.demographic_research[0].source_code_hash == "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" &&
      aws_lambda_function.demographic_research[0].reserved_concurrent_executions == 0 &&
      aws_lambda_function.demographic_research[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_SERVICE_ENABLED == "false" &&
      aws_lambda_function.demographic_research[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_ENROLLMENT_ENABLED == "false" &&
      aws_lambda_function.demographic_research[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_HTTP_SUBJECTS_JSON == "[]" &&
      length(aws_apigatewayv2_route.demographic_research) == 0 &&
      length(aws_lambda_permission.demographic_research_gateway) == 0
    )
    error_message = "A selected demographic candidate must remain concurrency-zero, subject-empty and unrouted until reviewed activation."
  }

  assert {
    condition = (
      output.demographic_research_candidate_contract.deployed &&
      !output.demographic_research_candidate_contract.service_enabled &&
      !output.demographic_research_candidate_contract.enrollment_enabled &&
      !output.demographic_research_candidate_contract.lifecycle_selected &&
      output.demographic_research_candidate_contract.profile_retention_days == 400 &&
      output.demographic_research_candidate_contract.operation_retention_days == 7 &&
      output.demographic_research_candidate_contract.consent_audit_days == 400 &&
      output.demographic_research_candidate_contract.cleanup_sla_hours == 24 &&
      !output.demographic_research_candidate_contract.campaign_enrichment &&
      !output.demographic_research_candidate_contract.commercial_use
    )
    error_message = "The output must preserve the approved disabled Phase A retention and use boundary."
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.demographic_research[0].retention_in_days == 14 &&
      length(aws_cloudwatch_metric_alarm.demographic_research_runtime) == 2 &&
      length(aws_cloudwatch_metric_alarm.demographic_research_internal_error) == 5 &&
      alltrue([for alarm in aws_cloudwatch_metric_alarm.demographic_research_internal_error : alarm.namespace == "TrustCheckRadar/DemographicResearch" && alarm.metric_name == "InternalError"])
    )
    error_message = "The candidate needs content-free 14-day logs and low-cardinality support alarms."
  }
}

run "iam_is_transaction_and_owner_bounded" {
  command = plan

  assert {
    condition = (
      one([for statement in data.aws_iam_policy_document.demographic_research[0].statement : statement if statement.sid == "ReadOwnedProfileAndDemographicState"]).actions == toset(["dynamodb:GetItem"]) &&
      one([for statement in data.aws_iam_policy_document.demographic_research[0].statement : statement if statement.sid == "WriteOwnedDemographicTransaction"]).actions == toset(["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]) &&
      one([for statement in data.aws_iam_policy_document.demographic_research[0].statement : statement if statement.sid == "CheckOwnedDemographicTransaction"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
      one([for statement in data.aws_iam_policy_document.demographic_research[0].statement : statement if statement.sid == "ReadOwnDeletionFence"]).actions == toset(["dynamodb:GetItem"]) &&
      alltrue([for statement in data.aws_iam_policy_document.demographic_research[0].statement : statement.sid == "WriteOwnLogs" || statement.sid == "DenyPayloadStorageAndRoleChaining" || alltrue([for resource in statement.resources : resource == local.users_table_arn || resource == local.deletion_ledger_table_arn])])
    )
    error_message = "Demographic IAM must stay on exact user/deletion tables with transactional owner-bound mutation families."
  }
}

run "activation_requires_lifecycle_coverage" {
  command = plan
  variables {
    demographic_research_activation = {
      phase               = "read_withdraw"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = ["0199abcd-1234-7000-8000-111111111111"]
      contract_reference  = "synthetic-contract"
      lifecycle_reference = "synthetic-lifecycle"
      runtime_reference   = "synthetic-runtime"
    }
  }
  expect_failures = [var.demographic_research_activation]
}

run "lifecycle_requires_export_and_deletion_sources" {
  command = plan
  variables {
    demographic_research_lifecycle_compatibility = {
      source_sha          = "1111111111111111111111111111111111111111"
      contract_reference  = "synthetic-contract"
      inventory_reference = "synthetic-inventory"
      export_reference    = "synthetic-export"
      deletion_reference  = "synthetic-deletion"
    }
  }
  expect_failures = [var.demographic_research_lifecycle_compatibility]
}

run "read_withdraw_activation_is_scoped_and_lifecycle_complete" {
  command = plan
  variables {
    account_data_deployment = {
      release_id         = "1111111111111111111111111111111111111111"
      object_version     = "account-data-version"
      source_hash        = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
      approval_reference = "synthetic-account-data"
      promotion_approved = false
    }
    account_data_finalization_candidate = {
      manifest_sha256    = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      inventory_revision = 2
      approval_reference = "synthetic-inventory-review"
    }
    account_export_deployment = {
      release_id                = "1111111111111111111111111111111111111111"
      object_version            = "account-export-version"
      source_hash               = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="
      approval_reference        = "synthetic-account-export"
      promotion_approved        = false
      authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    }
    demographic_research_lifecycle_compatibility = {
      source_sha          = "1111111111111111111111111111111111111111"
      contract_reference  = "synthetic-contract"
      inventory_reference = "synthetic-inventory"
      export_reference    = "synthetic-export"
      deletion_reference  = "synthetic-deletion"
    }
    demographic_research_activation = {
      phase               = "read_withdraw"
      source_sha          = "1111111111111111111111111111111111111111"
      http_subjects       = ["0199abcd-1234-7000-8000-111111111111"]
      contract_reference  = "synthetic-contract"
      lifecycle_reference = "synthetic-lifecycle"
      runtime_reference   = "synthetic-runtime"
    }
  }

  assert {
    condition = (
      output.demographic_research_candidate_contract.service_enabled &&
      !output.demographic_research_candidate_contract.enrollment_enabled &&
      output.demographic_research_candidate_contract.lifecycle_selected &&
      aws_lambda_function.demographic_research[0].reserved_concurrent_executions == 1 &&
      aws_lambda_function.demographic_research[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_SERVICE_ENABLED == "true" &&
      aws_lambda_function.demographic_research[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_ENROLLMENT_ENABLED == "false" &&
      aws_lambda_function.demographic_research[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_HTTP_SUBJECTS_JSON == "[\"0199abcd-1234-7000-8000-111111111111\"]" &&
      toset([for route in aws_apigatewayv2_route.demographic_research : route.route_key]) == toset([
        "GET /v1/users/demographic-research-profile",
        "PUT /v1/users/demographic-research-profile",
      ]) &&
      alltrue([for route in aws_apigatewayv2_route.demographic_research : route.authorization_type == "JWT" && route.authorization_scopes == toset(["aws.cognito.signin.user.admin"])])
    )
    error_message = "Read/withdraw activation must expose only exact JWT routes to the allowlisted candidate while enrollment stays closed."
  }

  assert {
    condition = (
      aws_lambda_permission.demographic_research_gateway["GET"].source_arn == "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/*/GET/v1/users/demographic-research-profile" &&
      aws_lambda_permission.demographic_research_gateway["PUT"].source_arn == "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/*/PUT/v1/users/demographic-research-profile" &&
      one([for settings in aws_apigatewayv2_stage.age_attestation.route_settings : settings if settings.route_key == "GET /v1/users/demographic-research-profile"]).throttling_rate_limit == 2 &&
      one([for settings in aws_apigatewayv2_stage.age_attestation.route_settings : settings if settings.route_key == "PUT /v1/users/demographic-research-profile"]).throttling_burst_limit == 4
    )
    error_message = "API Gateway permissions and throttles must be exact for both demographic owner-resource methods."
  }

  assert {
    condition = (
      aws_lambda_function.account_export[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_EXPORT_CONTRACT_ENABLED == "true" &&
      output.account_export_candidate_contract.transport_version == null &&
      output.account_export_candidate_contract.demographic_research_included &&
      aws_lambda_function.account_data[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_DELETION_POLICY_STATUS == "approved" &&
      output.account_data_candidate_contract.demographic_research_included
    )
    error_message = "A route can exist only when the exact export and account-deletion packages own the demographic families."
  }
}

run "enrollment_requires_published_policy" {
  command = plan
  variables {
    account_data_deployment = {
      release_id = "1111111111111111111111111111111111111111", object_version = "data", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", approval_reference = "data", promotion_approved = false
    }
    account_data_finalization_candidate = {
      manifest_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", inventory_revision = 2, approval_reference = "inventory"
    }
    account_export_deployment = {
      release_id = "1111111111111111111111111111111111111111", object_version = "export", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=", approval_reference = "export", promotion_approved = false, authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    }
    demographic_research_lifecycle_compatibility = {
      source_sha = "1111111111111111111111111111111111111111", contract_reference = "contract", inventory_reference = "inventory", export_reference = "export", deletion_reference = "deletion"
    }
    demographic_research_activation = {
      phase = "enrollment", source_sha = "1111111111111111111111111111111111111111", http_subjects = ["0199abcd-1234-7000-8000-111111111111"], contract_reference = "contract", lifecycle_reference = "lifecycle", runtime_reference = "runtime"
    }
  }
  expect_failures = [var.demographic_research_activation]
}

run "enrollment_phase_sets_only_the_enrollment_gate" {
  command = plan
  variables {
    account_data_deployment = {
      release_id = "1111111111111111111111111111111111111111", object_version = "data", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", approval_reference = "data", promotion_approved = false
    }
    account_data_finalization_candidate = {
      manifest_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", inventory_revision = 2, approval_reference = "inventory"
    }
    account_export_deployment = {
      release_id = "1111111111111111111111111111111111111111", object_version = "export", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=", approval_reference = "export", promotion_approved = false, authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    }
    demographic_research_lifecycle_compatibility = {
      source_sha = "1111111111111111111111111111111111111111", contract_reference = "contract", inventory_reference = "inventory", export_reference = "export", deletion_reference = "deletion"
    }
    demographic_research_activation = {
      phase = "enrollment", source_sha = "1111111111111111111111111111111111111111", http_subjects = ["0199abcd-1234-7000-8000-111111111111"], contract_reference = "contract", lifecycle_reference = "lifecycle", runtime_reference = "runtime", policy_publication_reference = "published-policy-evidence"
    }
  }
  assert {
    condition = (
      output.demographic_research_candidate_contract.enrollment_enabled &&
      aws_lambda_function.demographic_research[0].environment[0].variables.DEMOGRAPHIC_RESEARCH_ENROLLMENT_ENABLED == "true" &&
      !output.demographic_research_candidate_contract.campaign_enrichment &&
      !output.demographic_research_candidate_contract.commercial_use
    )
    error_message = "Published-policy evidence may enable only the approved enrollment gate, never campaign or commercial use."
  }
}

run "null_removes_candidate_resources" {
  command = plan
  variables {
    demographic_research_deployment = null
    demographic_research_monitoring = null
  }
  assert {
    condition = (
      length(aws_lambda_function.demographic_research) == 0 &&
      length(aws_cloudwatch_log_group.demographic_research) == 0 &&
      length(aws_iam_role.demographic_research) == 0 &&
      !output.demographic_research_candidate_contract.deployed
    )
    error_message = "Null deployment must remove the candidate Lambda, role and log group."
  }
}

run "production_requires_promotion_approval" {
  command = plan
  variables { environment = "prod" }
  expect_failures = [var.demographic_research_deployment]
}
