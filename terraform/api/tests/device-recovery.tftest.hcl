mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  aws_region             = "us-east-1"
  project_name           = "trustcheckradar"
  environment            = "dev"
  state_bucket_name      = "synthetic-state"
  state_bucket_region    = "us-east-1"
  artifact_release       = "synthetic-release"
  enable_device_recovery = true
}

override_resource {
  target          = aws_apigatewayv2_api.age_attestation
  override_during = plan
  values          = { execution_arn = "arn:aws:execute-api:us-east-1:107827791950:abcdef1234" }
}

override_data {
  target = data.terraform_remote_state.foundation
  values = { outputs = { downstream_contract = {
    schema_version                    = 1
    artifact_bucket_name              = "synthetic-artifacts"
    cognito_user_pool_id              = "us-east-1_example"
    cognito_app_client_id             = "synthetic-client"
    users_table_name                  = "users"
    users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/users"
    deletion_ledger_table_name        = "deletion-ledger"
    deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger"
    analysis_abuse_control_table_name = "analysis-abuse"
    analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/analysis-abuse"
    purchase_entitlements_table_name  = "entitlements"
    purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/entitlements"
    device_bindings_table_name        = "device-bindings"
    device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/device-bindings"
    web_risk_cache_table_name         = "web-risk-cache"
    web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/web-risk-cache"
    device_recovery_control = {
      schema_version = 1
      environment    = "dev"
      enabled        = true
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
  target = data.terraform_remote_state.history_data[0]
  values = { outputs = { downstream_contract = {
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
  } } }
}

override_data {
  target = data.terraform_remote_state.history_processing[0]
  values = { outputs = {
    lifecycle_contract = { schema_version = 1, environment = "dev", deployed = true, active = false }
  } }
}

run "operator_recovery_rejects_consumer_jwt_authorization" {
  command = plan
  assert {
    condition     = aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_RECOVERY_ALLOWED_PRINCIPAL_ARNS_JSON"] == "[]"
    error_message = "The corrected handler must deny operator recovery unless exact principals are explicitly configured."
  }
  assert {
    condition = (
      aws_apigatewayv2_route.device_recovery[0].authorization_type == "AWS_IAM" &&
      aws_apigatewayv2_route.device_recovery[0].authorizer_id == null &&
      output.device_recovery_backend_settings.authorizationType == "AWS_IAM" &&
      !output.device_recovery_backend_settings.consumerSupported &&
      !contains(keys(output.device_recovery_backend_settings), "audience")
    )
    error_message = "Operator recovery must require IAM authorization and must never advertise a consumer JWT contract."
  }
  assert {
    condition = (
      aws_lambda_permission.allow_api_gateway_invoke_device_recovery[0].source_arn == "arn:aws:execute-api:us-east-1:107827791950:abcdef1234/*/POST/device-recovery" &&
      aws_lambda_permission.allow_api_gateway_invoke_device_recovery[0].principal == "apigateway.amazonaws.com"
    )
    error_message = "Only the exact operator POST route may invoke the recovery Lambda."
  }
}

run "operator_allowlist_cannot_be_overridden_by_generic_environment" {
  command = plan
  variables {
    device_recovery_allowed_principal_arns = ["arn:aws:iam::107827791950:user/synthetic-operator"]
    device_recovery_lambda_env             = { DEVICE_RECOVERY_ALLOWED_PRINCIPAL_ARNS_JSON = "[\"*\"]" }
  }
  assert {
    condition     = aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_RECOVERY_ALLOWED_PRINCIPAL_ARNS_JSON"] == "[\"arn:aws:iam::107827791950:user/synthetic-operator\"]"
    error_message = "Generic environment variables must not bypass the validated operator allowlist."
  }
}

run "operator_allowlist_rejects_wildcards" {
  command = plan
  variables { device_recovery_allowed_principal_arns = ["arn:aws:sts::107827791950:assumed-role/operator/*"] }
  expect_failures = [var.device_recovery_allowed_principal_arns]
}

run "operator_allowlist_rejects_other_accounts" {
  command = plan
  variables { device_recovery_allowed_principal_arns = ["arn:aws:iam::999999999999:user/operator"] }
  expect_failures = [var.device_recovery_allowed_principal_arns]
}

run "custom_operator_path_stays_exact" {
  command = plan
  variables { device_recovery_path = "/v1/internal/device-recovery" }
  assert {
    condition = (
      aws_apigatewayv2_route.device_recovery[0].route_key == "POST /v1/internal/device-recovery" &&
      aws_lambda_permission.allow_api_gateway_invoke_device_recovery[0].source_arn == "arn:aws:execute-api:us-east-1:107827791950:abcdef1234/*/POST/v1/internal/device-recovery"
    )
    error_message = "Changing the static operator path must also narrow the invocation permission to that path."
  }
}

run "wildcard_operator_path_is_rejected" {
  command = plan
  variables { device_recovery_path = "/device-recovery/*" }
  expect_failures = [var.device_recovery_path]
}

run "operator_path_cannot_replace_consumer_route" {
  command = plan
  variables { device_recovery_path = "/v1/users/device-recovery" }
  expect_failures = [var.device_recovery_path]
}

run "consumer_recovery_requires_coordinated_artifacts" {
  command = plan
  variables { device_self_recovery_enabled = true }
  expect_failures = [var.device_self_recovery_enabled]
}

run "consumer_recovery_is_pinned_scoped_and_fresh_auth_only" {
  command = plan
  variables {
    device_self_recovery_enabled = true
    device_self_recovery_acceptance = {
      approved                        = true
      release_id                      = "synthetic-release"
      contract_version                = "1.0.0"
      contract_sha256                 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference              = "synthetic-test-not-owner-approval"
      security_verification_reference = "synthetic-test-not-live-acceptance"
    }
    history_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        read     = { object_version = "read-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        mutation = { object_version = "mutation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
        analysis = { object_version = "analysis-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
      }
    }
    device_recovery_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        recovery     = { object_version = "recovery-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        registration = { object_version = "registration-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
      }
    }
  }
  assert {
    condition = (
      aws_apigatewayv2_route.device_self_recovery[0].authorization_type == "JWT" &&
      aws_apigatewayv2_route.device_self_recovery[0].authorization_scopes == toset(["aws.cognito.signin.user.admin"]) &&
      aws_lambda_permission.device_self_recovery[0].source_arn == "arn:aws:execute-api:us-east-1:107827791950:abcdef1234/*/POST/v1/users/device-recovery" &&
      aws_apigatewayv2_route.device_recovery[0].authorization_type == "AWS_IAM"
    )
    error_message = "Consumer and operator recovery must retain distinct authorization and exact invocation permissions."
  }
  assert {
    condition = (
      output.device_self_recovery_contract.acceptance_approved &&
      output.device_self_recovery_contract.contract_version == "1.0.0" &&
      output.device_self_recovery_contract.contract_sha256 == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    )
    error_message = "An activated consumer contract must expose the exact accepted version and digest."
  }
  assert {
    condition = (
      aws_lambda_function.device_recovery[0].s3_key == "releases/synthetic-release/device_recovery.zip" &&
      aws_lambda_function.device_recovery[0].s3_object_version == "recovery-version" &&
      aws_lambda_function.device_registration.s3_key == "releases/synthetic-release/device_registration.zip" &&
      aws_lambda_function.device_registration.s3_object_version == "registration-version" &&
      aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_SELF_RECOVERY_ENABLED"] == "true" &&
      aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_RECOVERY_MAX_REAUTH_AGE_SECONDS"] == "300" &&
      aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_RECOVERY_AUDIT_RETENTION_DAYS"] == "90" &&
      aws_lambda_function.device_registration.environment[0].variables["COGNITO_REQUIRED_SCOPE"] == "aws.cognito.signin.user.admin"
    )
    error_message = "Recovery and registration must deploy immutable coordinated packages with trusted identity and recovery policy settings."
  }
  assert {
    condition = (
      length(aws_iam_role_policy.device_identity) == 2 &&
      one([for statement in data.aws_iam_policy_document.device_recovery_control[0].statement : statement if statement.sid == "RecoveryReceiptsAuditAndRateState"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-recovery-control"]) &&
      one([for statement in data.aws_iam_policy_document.device_recovery_control[0].statement : statement if statement.sid == "RecoveryReceiptsAuditAndRateState"]).actions == toset(["dynamodb:PutItem", "dynamodb:UpdateItem"]) &&
      one([for statement in data.aws_iam_policy_document.device_identity[0].statement : statement if statement.sid == "SerializeExistingActivePointer"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
      anytrue([for settings in aws_apigatewayv2_stage.age_attestation.route_settings : settings.route_key == "POST /v1/users/device-recovery" && settings.throttling_rate_limit == 2])
    )
    error_message = "Recovery must scope control state to its own table, supply both identity fences, and bound the consumer route."
  }
  assert {
    condition = (
      length(data.aws_iam_policy_document.device_recovery_control[0].statement) == 2 &&
      one([for statement in data.aws_iam_policy_document.device_recovery_control[0].statement : statement if statement.sid == "ReadRecoveryReceiptsAndRateState"]).actions == toset(["dynamodb:GetItem"]) &&
      alltrue([for statement in data.aws_iam_policy_document.device_recovery_control[0].statement :
        statement.resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-recovery-control"]) &&
        anytrue([for rule in statement.condition : rule.variable == "dynamodb:LeadingKeys" && rule.test == "ForAllValues:StringLike" && toset(rule.values) == toset(["USER#*"])])
      ]) &&
      anytrue([for rule in one([for statement in data.aws_iam_policy_document.device_recovery_control[0].statement : statement if statement.sid == "RecoveryReceiptsAuditAndRateState"]).condition :
        rule.variable == "dynamodb:EnclosingOperation" && rule.test == "ForAnyValue:StringEquals" && toset(rule.values) == toset(["TransactWriteItems"])
      ])
    )
    error_message = "Recovery control reads must be point reads; only subject-scoped transactional puts/updates may mutate receipts, audit and rate records, without scans, deletes or wildcard resources."
  }
}

run "operator_candidate_has_pointer_permission_without_consumer_storage" {
  command = plan
  variables {
    device_recovery_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        recovery     = { object_version = "recovery-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        registration = { object_version = "registration-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
      }
    }
  }
  override_data {
    target = data.terraform_remote_state.foundation
    values = { outputs = { downstream_contract = {
      schema_version                    = 1
      artifact_bucket_name              = "synthetic-artifacts"
      cognito_user_pool_id              = "us-east-1_example"
      cognito_app_client_id             = "synthetic-client"
      users_table_name                  = "users"
      users_table_arn                   = "arn:aws:dynamodb:us-east-1:107827791950:table/users"
      deletion_ledger_table_name        = "deletion-ledger"
      deletion_ledger_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger"
      analysis_abuse_control_table_name = "analysis-abuse"
      analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/analysis-abuse"
      purchase_entitlements_table_name  = "entitlements"
      purchase_entitlements_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/entitlements"
      device_bindings_table_name        = "device-bindings"
      device_bindings_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/device-bindings"
      web_risk_cache_table_name         = "web-risk-cache"
      web_risk_cache_table_arn          = "arn:aws:dynamodb:us-east-1:107827791950:table/web-risk-cache"
    } } }
  }
  assert {
    condition = (
      length(aws_iam_role_policy.device_recovery_control) == 0 &&
      length(aws_apigatewayv2_route.device_self_recovery) == 0 &&
      one([for statement in data.aws_iam_policy_document.device_identity[0].statement : statement if statement.sid == "SerializeExistingActivePointer"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
      aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_SELF_RECOVERY_ENABLED"] == "false"
    )
    error_message = "A corrected operator candidate needs pointer transaction permission even when consumer storage and routing remain disabled."
  }
}

run "consumer_recovery_cannot_leave_old_readers_deployed" {
  command = plan
  variables {
    device_self_recovery_enabled = true
    device_recovery_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        recovery     = { object_version = "recovery-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        registration = { object_version = "registration-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
      }
    }
  }
  expect_failures = [var.device_self_recovery_enabled]
}

run "disabled_operator_endpoint_creates_no_recovery_route" {
  command = plan
  variables { enable_device_recovery = false }
  assert {
    condition = (
      length(aws_apigatewayv2_route.device_recovery) == 0 &&
      length(aws_lambda_permission.allow_api_gateway_invoke_device_recovery) == 0 &&
      output.device_recovery_backend_settings == null &&
      output.device_recovery_endpoint_path == null &&
      output.device_recovery_endpoint_url == null
    )
    error_message = "An unprovisioned operator endpoint must not advertise or grant recovery access."
  }
}

run "generic_environment_cannot_activate_consumers_or_weaken_reauthentication" {
  command = plan
  variables {
    device_recovery_lambda_env = {
      DEVICE_SELF_RECOVERY_ENABLED           = "true"
      DEVICE_RECOVERY_POLICY_STATUS          = "approved"
      DEVICE_RECOVERY_MAX_REAUTH_AGE_SECONDS = "86400"
      DEVICE_RECOVERY_RATE_MAX_REQUESTS      = "999"
    }
  }
  assert {
    condition = (
      length(aws_apigatewayv2_route.device_self_recovery) == 0 &&
      length(aws_lambda_permission.device_self_recovery) == 0 &&
      !output.device_self_recovery_contract.enabled &&
      !output.device_self_recovery_contract.acceptance_approved &&
      output.device_self_recovery_contract.contract_version == null &&
      output.device_self_recovery_contract.contract_sha256 == null &&
      aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_SELF_RECOVERY_ENABLED"] == "false" &&
      aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_RECOVERY_MAX_REAUTH_AGE_SECONDS"] == "300" &&
      aws_lambda_function.device_recovery[0].environment[0].variables["DEVICE_RECOVERY_RATE_MAX_REQUESTS"] == "3"
    )
    error_message = "Generic environment overrides must not expose consumer recovery, advertise acceptance, or relax its authentication/rate policy."
  }
  assert {
    condition = (
      aws_apigatewayv2_route.device_registration.route_key == "POST /device-registration" &&
      aws_apigatewayv2_route.device_registration.authorization_type == "JWT" &&
      !contains(keys(aws_lambda_function.device_registration.environment[0].variables), "DEVICE_SELF_RECOVERY_ENABLED") &&
      !contains(keys(aws_lambda_function.device_registration.environment[0].variables), "DEVICE_RECOVERY_MAX_REAUTH_AGE_SECONDS")
    )
    error_message = "Consumer recovery controls must not change automatic normal registration's route or introduce a global step-up requirement."
  }
}

run "coordinated_packages_do_not_imply_security_acceptance" {
  command = plan
  variables {
    device_self_recovery_enabled = true
    history_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        read     = { object_version = "read-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        mutation = { object_version = "mutation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
        analysis = { object_version = "analysis-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
      }
    }
    device_recovery_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        recovery     = { object_version = "recovery-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        registration = { object_version = "registration-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
      }
    }
  }
  expect_failures = [var.device_self_recovery_enabled]
}

run "acceptance_for_another_release_cannot_activate_consumers" {
  command = plan
  variables {
    device_self_recovery_enabled = true
    device_self_recovery_acceptance = {
      approved                        = true
      release_id                      = "different-release"
      contract_version                = "1.0.0"
      contract_sha256                 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference              = "synthetic-test-not-owner-approval"
      security_verification_reference = "synthetic-test-not-live-acceptance"
    }
    history_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        read     = { object_version = "read-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        mutation = { object_version = "mutation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
        analysis = { object_version = "analysis-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
      }
    }
    device_recovery_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        recovery     = { object_version = "recovery-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        registration = { object_version = "registration-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
      }
    }
  }
  expect_failures = [var.device_self_recovery_enabled]
}

run "contract_acceptance_rejects_malformed_or_missing_evidence" {
  command = plan
  variables {
    device_self_recovery_acceptance = {
      approved                        = true
      release_id                      = "synthetic-release"
      contract_version                = "draft"
      contract_sha256                 = "not-a-sha256"
      approval_reference              = " "
      security_verification_reference = ""
    }
  }
  expect_failures = [var.device_self_recovery_acceptance]
}

run "review_references_without_approval_do_not_activate_consumers" {
  command = plan
  variables {
    device_self_recovery_enabled = true
    device_self_recovery_acceptance = {
      approved                        = false
      release_id                      = "synthetic-release"
      contract_version                = "1.0.0"
      contract_sha256                 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      approval_reference              = "synthetic-pending-review"
      security_verification_reference = "synthetic-pending-security-review"
    }
    history_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        read     = { object_version = "read-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        mutation = { object_version = "mutation-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
        analysis = { object_version = "analysis-version", source_hash = "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" }
      }
    }
    device_recovery_deployment = {
      release_id         = "synthetic-release"
      approval_reference = "synthetic-test-not-deployment-approval"
      promotion_approved = false
      artifacts = {
        recovery     = { object_version = "recovery-version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
        registration = { object_version = "registration-version", source_hash = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" }
      }
    }
  }
  expect_failures = [var.device_self_recovery_enabled]
}

run "play_route_throttle_is_bounded" {
  command = plan
  variables { play_verification_route_throttle_enabled = true }
  assert {
    condition     = length([for route in aws_apigatewayv2_stage.age_attestation.route_settings : route if route.route_key == "POST /v1/purchases/google-play/verify" && route.throttling_burst_limit == 4 && route.throttling_rate_limit == 2 && route.detailed_metrics_enabled]) == 1
    error_message = "The Play route requires a dedicated bounded throttle."
  }
}
