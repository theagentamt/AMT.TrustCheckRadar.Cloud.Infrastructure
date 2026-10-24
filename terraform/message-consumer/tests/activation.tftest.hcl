mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/message-candidate" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { version = "1" }
  }
  mock_resource "aws_lambda_alias" {
    defaults = {
      arn        = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-message-evaluator:live"
      invoke_arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-message-evaluator:live"
    }
  }
}

variables {
  authority_maintenance = {
    schema_version        = 1
    environment           = "dev"
    authority_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
    recovery_alias_arn    = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-lease-recovery:live"
    recovery_version      = "11"
    recovery_code_sha256  = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    worker_enabled        = true
    schedule_enabled      = true
    heartbeat_enforced    = true
    provider_access_added = false
  }
  environment = "dev"
  enabled     = true
  deployment = {
    artifacts = {
      consumer = {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_consumer.zip"
        object_version = "consumer-version"
        source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      }
      evaluator = {
        bucket         = "trustcheckradar-dev-107827791950-artifacts"
        key            = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/message_evaluator.zip"
        object_version = "evaluator-version"
        source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      }
    }
    users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
    deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
    authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
    authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123"
    assessment_alias_arn      = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live"
    cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool"
    cognito_app_client_id     = "testclient"
  }
  api_gateway = {
    api_id        = "icuak34th9"
    execution_arn = "arn:aws:execute-api:us-east-1:107827791950:icuak34th9"
    authorizer_id = "authorizer1"
  }
  authority_configuration = {
    operation_validity_seconds = 300
    worker_settlement_seconds  = 60
    reconciliation_seconds     = 3600
    counter_retention_seconds  = 604800
  }
  provider_budget = {
    window_seconds          = 3600
    max_attempts_per_window = 20
    max_failures_per_window = 5
  }
}

run "inactive_candidate_publishes_authenticated_routes_but_executes_nothing" {
  command = apply

  assert {
    condition = (
      toset(output.candidate_contract.consumer_routes) == toset([
        "POST /v1/message-checks/prepare",
        "POST /v1/message-checks",
        "POST /v1/message-checks/reconcile",
      ]) &&
      length(aws_apigatewayv2_integration.message) == 1 &&
      length(aws_lambda_permission.message) == 3
    )
    error_message = "The isolated candidate must own exactly the three authenticated message routes."
  }

  assert {
    condition = alltrue([for route in aws_apigatewayv2_route.message :
      route.authorization_type == "JWT" && route.authorizer_id == "authorizer1" &&
      route.authorization_scopes == toset(["aws.cognito.signin.user.admin"])
    ])
    error_message = "Every message route must reuse the reviewed JWT authorizer and required scope."
  }

  assert {
    condition = (
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_CONSUMER_ENABLED == "false" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.AUTHORITY_ENABLED == "false" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_PROVIDER_CIRCUIT_OPEN == "true" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.DEV_SUBJECT_ALLOWLIST_JSON == "[]" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_EVALUATOR_ENABLED == "false" &&
      !output.candidate_contract.consumer_enabled && !output.candidate_contract.evaluator_enabled &&
      output.candidate_contract.provider_circuit_open
    )
    error_message = "Provisioned routes must remain fail-closed until bounded engineering activation."
  }
}

run "allowlisted_rules_engineering_activation_is_bounded_and_ai_stays_closed" {
  command = apply
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
  }

  assert {
    condition = (
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_CONSUMER_ENABLED == "true" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.AUTHORITY_ENABLED == "true" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_PROVIDER_CIRCUIT_OPEN == "false" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_PROVIDER_WINDOW_SECONDS == "3600" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_PROVIDER_ATTEMPTS_PER_WINDOW == "20" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_PROVIDER_FAILURES_PER_WINDOW == "5" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.RECEIPT_RETENTION_SECONDS == "604800" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.DEV_SUBJECT_ALLOWLIST_JSON == "[\"11111111-1111-4111-8111-111111111111\"]" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_EVALUATOR_ENABLED == "true"
    )
    error_message = "Rules qualification must bind exact subjects, authority horizons and provider caps."
  }

  assert {
    condition = (
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_AI_ENABLED == "false" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_AI_ENABLED == "false" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_AI_QUALIFIED == "false" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_PROPOSER_ENABLED == "false" &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[2].Effect == "Deny" &&
      contains(jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[2].Action, "secretsmanager:*") &&
      output.candidate_contract.consumer_enabled && output.candidate_contract.evaluator_enabled &&
      !output.candidate_contract.ai_enabled && !output.candidate_contract.ai_qualified
    )
    error_message = "Rules qualification must not enable AI or grant provider-secret access."
  }
}

run "engineering_activation_without_subjects_is_rejected" {
  command = plan
  variables {
    activate_rules_engineering = true
  }
  expect_failures = [var.activate_rules_engineering]
}

run "candidate3_rules_only_keeps_provider_circuit_closed_and_denies_url_invocation" {
  command = apply
  variables {
    activate_rules_engineering          = true
    candidate3_rules_only_enabled       = true
    governed_history_settlement_enabled = true
    engineering_subjects                = ["11111111-1111-4111-8111-111111111111"]
  }
  assert {
    condition     = alltrue([for fn in aws_lambda_function.runtime : fn.environment[0].variables.MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED == "true" && fn.environment[0].variables.MESSAGE_AI_ENABLED == "false"]) && aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_PROVIDER_CIRCUIT_OPEN == "true" && aws_lambda_function.runtime["consumer"].environment[0].variables.GOVERNED_HISTORY_SETTLEMENT_ENABLED == "true" && jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[1].Effect == "Deny"
    error_message = "Candidate.3 deterministic qualification must not invoke a provider or enable AI."
  }
}
run "candidate3_requires_exactly_one_subject" {
  command = plan
  variables {
    activate_rules_engineering    = true
    candidate3_rules_only_enabled = true
    engineering_subjects          = ["11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"]
  }
  expect_failures = [var.candidate3_rules_only_enabled]
}
run "history_settlement_cannot_enable_itself" {
  command = plan
  variables { governed_history_settlement_enabled = true }
  expect_failures = [var.governed_history_settlement_enabled]
}

run "ai_primary_requires_explicit_configuration" {
  command = plan
  variables {
    activate_rules_engineering = true
    message_ai_primary_enabled = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
  }
  expect_failures = [var.message_ai_primary_enabled]
}

run "paused_ai_does_not_enable_deterministic_fallback_or_clear_history" {
  command = apply
  variables {
    activate_rules_engineering          = true
    message_ai_primary_enabled          = false
    candidate3_rules_only_enabled       = false
    governed_history_settlement_enabled = true
    engineering_subjects                = ["11111111-1111-4111-8111-111111111111"]
  }
  assert {
    condition = (
      !output.candidate_contract.ai_enabled && !output.candidate_contract.candidate3_rules_only_enabled &&
      output.candidate_contract.governed_history_settlement_enabled &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_PROPOSER_ENABLED == "false" &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[1].Effect == "Deny"
    )
    error_message = "Pausing AI may preserve History configuration but cannot infer a deterministic profile, enable the legacy proposer or open URL invocation."
  }
}

run "normal_ai_primary_config_does_not_open_url_or_storage" {
  command = apply
  variables {
    activate_rules_engineering          = true
    message_ai_primary_enabled          = true
    governed_history_settlement_enabled = true
    engineering_subjects                = ["11111111-1111-4111-8111-111111111111"]
    ai_configuration = {
      secret_arn                    = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/openai-ABC123"
      qualification_id              = "fixture-only-not-accepted-evidence"
      qualification_evidence_sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      timeout_ms                    = 8000
      max_nano_usd_per_window       = 5000000000
      cost_policy = {
        model                 = "gpt-5.4-mini-2026-03-17"
        contextTokens         = 400000
        maxOutputTokens       = 512
        inputNanoUsdPerToken  = 750
        outputNanoUsdPerToken = 4500
      }
    }
  }
  assert {
    condition = (
      output.candidate_contract.ai_primary_enabled && !output.candidate_contract.url_assessment_enabled &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_AI_PRIMARY_ENABLED == "true" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.MESSAGE_PROVIDER_NANO_USD_PER_WINDOW == "5000000000" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.GOVERNED_HISTORY_SETTLEMENT_ENABLED == "true" &&
      jsondecode(aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_AI_COST_POLICY).model == "gpt-5.4-mini-2026-03-17" &&
      aws_lambda_function.runtime["evaluator"].environment[0].variables.MESSAGE_PROPOSER_ENABLED == "false" &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[1].Effect == "Deny" &&
      !contains(jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[2].Action, "secretsmanager:*") &&
      contains(jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[2].Action, "dynamodb:*") &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[3].Resource == var.ai_configuration.secret_arn &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[3].Condition.StringEquals["secretsmanager:VersionStage"] == "AWSCURRENT" &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[4].Effect == "Deny" &&
      jsondecode(aws_iam_role_policy.evaluator[0].policy).Statement[4].NotResource == var.ai_configuration.secret_arn &&
      toset(jsondecode(aws_iam_role_policy.consumer[0].policy).Statement[4].Condition["ForAllValues:StringEquals"]["dynamodb:Attributes"]) ==
      toset(["PK", "SK", "recordType", "revision", "windowStart", "attempts", "failures", "windowSeconds", "reservedNanoUsd", "unpricedAttempts"])
    )
    error_message = "Normal AI configuration must preserve URL denial, legacy proposer-off and evaluator storage denial, and narrowly bind currency attributes and current-secret reads. This source test does not qualify model evidence."
  }
}

run "message_rejects_maintenance_missing_contract" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = null
  }
  expect_failures = [var.activate_rules_engineering]
}

run "message_rejects_maintenance_disabled_worker" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = merge(var.authority_maintenance, { worker_enabled = false })
  }
  expect_failures = [var.activate_rules_engineering]
}

run "message_rejects_maintenance_disabled_schedule" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = merge(var.authority_maintenance, { schedule_enabled = false })
  }
  expect_failures = [var.activate_rules_engineering]
}

run "message_rejects_maintenance_missing_heartbeat" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = merge(var.authority_maintenance, { heartbeat_enforced = false })
  }
  expect_failures = [var.activate_rules_engineering]
}

run "message_rejects_maintenance_wrong_table" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = merge(var.authority_maintenance, { authority_table_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/unrelated" })
  }
  expect_failures = [var.activate_rules_engineering]
}

run "message_rejects_maintenance_wrong_alias" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = merge(var.authority_maintenance, { recovery_alias_arn = "arn:aws:lambda:us-east-1:107827791950:function:unrelated:live" })
  }
  expect_failures = [var.activate_rules_engineering]
}

run "message_rejects_maintenance_unversioned_worker" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = merge(var.authority_maintenance, { recovery_version = "$LATEST" })
  }
  expect_failures = [var.activate_rules_engineering]
}

run "message_rejects_maintenance_wrong_hash" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = merge(var.authority_maintenance, { recovery_code_sha256 = "not-a-hash" })
  }
  expect_failures = [var.activate_rules_engineering]
}

run "message_rejects_maintenance_added_provider_access" {
  command = plan
  variables {
    activate_rules_engineering = true
    engineering_subjects       = ["11111111-1111-4111-8111-111111111111"]
    authority_maintenance      = merge(var.authority_maintenance, { provider_access_added = true })
  }
  expect_failures = [var.activate_rules_engineering]
}
