mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/test-history" }
  }
}

variables {
  aws_region          = "us-east-1"
  project_name        = "trustcheckradar"
  environment         = "dev"
  state_bucket_name   = "terraform-state-example"
  state_bucket_region = "us-east-1"
  artifact_release    = "existing-release"
  openai_secret_arn   = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/openai-ABC123"
  history_deployment = {
    release_id         = "history-candidate"
    approval_reference = "test-only"
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

run "disabled_leaves_existing_analysis_untouched" {
  command = plan
  variables { history_deployment = null }
  assert {
    condition = (
      length(aws_lambda_function.history_api) == 0 &&
      length(aws_apigatewayv2_route.history) == 0 &&
      length(data.terraform_remote_state.history_data) == 0 &&
      length(aws_iam_role_policy.history_analysis) == 0 &&
      length(aws_secretsmanager_secret.history_cursor) == 0 &&
      aws_lambda_function.analysis.s3_key == "releases/existing-release/conversation_analysis.zip" &&
      !contains(keys(aws_lambda_function.analysis.environment[0].variables), "HISTORY_WRITES_ENABLED")
    )
    error_message = "Without an approved deployment, History must not alter analysis or create resources."
  }
}

run "candidate_is_pinned_disabled_and_access_token_only" {
  command = plan
  assert {
    condition = (
      length(aws_apigatewayv2_route.history) == 8 &&
      alltrue([for route in aws_apigatewayv2_route.history :
        route.authorization_type == "JWT" && toset(route.authorization_scopes) == toset(["aws.cognito.signin.user.admin"])
      ]) &&
      toset([for route in aws_apigatewayv2_route.history : route.route_key]) == toset([
        "POST /v1/users/history/bootstrap", "GET /v1/users/history", "GET /v1/users/history/{requestId}",
        "GET /v1/users/history/export", "GET /v1/users/progress", "DELETE /v1/users/history/{requestId}",
        "DELETE /v1/users/history", "POST /v1/users/progress/reset"
      ])
    )
    error_message = "Every History route must require a Cognito access-token scope and must not expose a caller-selected user or fake full-account deletion."
  }
  assert {
    condition = (
      aws_lambda_function.analysis.s3_key == "releases/history-candidate/conversation_analysis.zip" &&
      aws_lambda_function.analysis.s3_object_version == "analysis-version" &&
      aws_lambda_function.analysis.source_code_hash == var.history_deployment.artifacts.analysis.source_hash &&
      aws_lambda_function.history_api["read"].s3_object_version == "read-version" &&
      aws_lambda_function.history_api["mutation"].s3_object_version == "mutation-version" &&
      aws_lambda_function.age_attestation.s3_key == "releases/existing-release/age_attestation.zip"
    )
    error_message = "History must pin only its own artifacts, including analysis, without replacing unrelated Lambda packages."
  }
  assert {
    condition = (
      aws_lambda_function.history_api["read"].environment[0].variables.COGNITO_ISSUER == "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_example" &&
      aws_lambda_function.history_api["read"].environment[0].variables.COGNITO_APP_CLIENT_ID == "client-example" &&
      aws_lambda_function.history_api["read"].environment[0].variables.COGNITO_REQUIRED_SCOPE == "aws.cognito.signin.user.admin" &&
      aws_lambda_function.history_api["read"].environment[0].variables.HISTORY_READS_ENABLED == "false" &&
      aws_lambda_function.history_api["mutation"].environment[0].variables.HISTORY_MUTATIONS_ENABLED == "false" &&
      aws_lambda_function.analysis.environment[0].variables.HISTORY_WRITES_ENABLED == "false" &&
      aws_lambda_function.analysis.environment[0].variables.HISTORY_DURABLE_REPLAY_ENABLED == "false" &&
      aws_lambda_function.analysis.environment[0].variables.RECOGNITION_ENABLED == "false"
    )
    error_message = "Deploying a candidate must not activate any feature or omit issuer/client validation settings."
  }
  assert {
    condition = alltrue([for permission in aws_lambda_permission.history_gateway :
      permission.principal == "apigateway.amazonaws.com" && permission.action == "lambda:InvokeFunction"
    ])
    error_message = "Only the API Gateway integration may invoke the public handlers through resource policies."
  }
  assert {
    condition = sum([for key, value in aws_lambda_function.analysis.environment[0].variables :
      (length(base64encode(key)) + length(base64encode(value))) * 3 / 4 -
      length(regexall("=", base64encode(key))) - length(regexall("=", base64encode(value)))
    ]) <= 4096
    error_message = "The combined existing analysis and History environment must fit Lambda's 4096-byte limit."
  }
}

run "runtime_permissions_are_scoped" {
  command = plan
  # Resolve generated ARNs so the complete resource boundary is testable at plan.
  override_resource {
    target          = aws_cloudwatch_log_group.history_api["read"]
    override_during = plan
    values          = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:/aws/lambda/test-history-read" }
  }
  override_resource {
    target          = aws_cloudwatch_log_group.history_api["mutation"]
    override_during = plan
    values          = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:/aws/lambda/test-history-mutation" }
  }
  override_resource {
    target          = aws_secretsmanager_secret.history_cursor[0]
    override_during = plan
    values          = { arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:test-history-cursor-ABC123" }
  }
  assert {
    condition = alltrue([for policy in data.aws_iam_policy_document.history_api : length([
      for statement in policy.statement : statement if statement.sid == "ReadAuthoritativeDeviceBinding" &&
      toset(statement.actions) == toset(["dynamodb:GetItem"]) &&
      toset(statement.resources) == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/device-bindings"]) &&
      length(statement.condition) == 1 &&
      alltrue([for condition in statement.condition :
        condition.test == "ForAllValues:StringLike" &&
        condition.variable == "dynamodb:LeadingKeys" &&
        toset(condition.values) == toset(["USER#*"])
      ])
    ]) == 1])
    error_message = "Both History handlers must read the authoritative ACTIVE_BINDING pointer and DEVICE row only in user-keyed device bindings."
  }
  assert {
    condition = alltrue([for policy in data.aws_iam_policy_document.history_api : length([
      for statement in policy.statement : statement if statement.sid == "VerifyActiveDeviceBinding" &&
      toset(statement.actions) == toset(["dynamodb:Query"]) &&
      toset(statement.resources) == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/device-bindings/index/GSI1"]) &&
      length(statement.condition) == 1 &&
      alltrue([for condition in statement.condition :
        condition.test == "ForAllValues:StringLike" &&
        condition.variable == "dynamodb:LeadingKeys" &&
        toset(condition.values) == toset(["USER#*#ACTIVE"])
      ])
    ]) == 1])
    error_message = "Both handlers must retain Query only on the legacy active-device index with active-user keys."
  }
  assert {
    condition = alltrue([for policy in data.aws_iam_policy_document.history_api :
      length([for statement in policy.statement : statement if
        anytrue([for resource in statement.resources : strcontains(resource, "device-bindings")])
      ]) == 2 &&
      alltrue([for statement in policy.statement :
        !contains(statement.resources, "*") &&
        alltrue([for resource in statement.resources : !strcontains(resource, "device-bindings") ||
          !strcontains(resource, "*")
        ])
      ])
    ])
    error_message = "History binding access must contain exactly the scoped table read and index query, without wildcard resource grants."
  }
  assert {
    condition = length([for statement in data.aws_iam_policy_document.history_api["mutation"].statement : statement
      if statement.sid == "CheckDeletionFenceAtomically" &&
      toset(statement.actions) == toset(["dynamodb:ConditionCheckItem"]) &&
      toset(statement.resources) == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/deletion-ledger"]) &&
      anytrue([for condition in statement.condition : condition.variable == "dynamodb:LeadingKeys" && toset(condition.values) == toset(["ACCOUNT#*"])]) &&
      anytrue([for condition in statement.condition : condition.variable == "dynamodb:EnclosingOperation" && toset(condition.values) == toset(["TransactWriteItems"])])
    ]) == 1
    error_message = "Bootstrap must atomically check the authoritative account-deletion fence without permission to write that ledger."
  }
  assert {
    condition = length([for statement in data.aws_iam_policy_document.history_api["read"].statement : statement
      if statement.sid == "CreateOnlyOpaqueCursors" && toset(statement.actions) == toset(["dynamodb:PutItem"]) &&
      toset(statement.resources) == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-control"]) &&
      anytrue([for condition in statement.condition : condition.variable == "dynamodb:LeadingKeys" && toset(condition.values) == toset(["CURSOR#*"])])
    ]) == 1
    error_message = "The read handler may create cursors but must not change user state."
  }
  assert {
    condition = length([for statement in data.aws_iam_policy_document.history_analysis[0].statement : statement
      if statement.sid == "AtomicHistoryCompletion" &&
      toset(statement.actions) == toset(["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:ConditionCheckItem"]) &&
      toset(statement.resources) == toset([
        "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-content",
        "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-control"
      ]) && anytrue([for condition in statement.condition : condition.variable == "dynamodb:EnclosingOperation" && toset(condition.values) == toset(["TransactWriteItems"])])
    ]) == 1
    error_message = "The producer must use table-scoped atomic writes, never broad DynamoDB permissions."
  }
  assert {
    condition = alltrue(flatten([for policy in data.aws_iam_policy_document.history_api : [for statement in policy.statement :
      !contains(statement.actions, "dynamodb:Scan") && !contains(statement.actions, "dynamodb:*") && !contains(statement.actions, "*")
    ]]))
    error_message = "History runtime must not have table scans or wildcard actions."
  }
}

run "activation_requires_active_cleanup" {
  command = plan
  variables {
    history_features = { reads = true, writes = true, mutations = true, recognition = true, durable_replay = true }
  }
  expect_failures = [aws_lambda_function.history_api]
}

run "writes_require_durable_replay" {
  command = plan
  variables {
    history_features = { reads = false, writes = true, mutations = false, recognition = false, durable_replay = false }
  }
  expect_failures = [var.history_features]
}

run "active_cleanup_allows_explicit_activation" {
  command = plan
  variables {
    history_features = { reads = true, writes = true, mutations = true, recognition = true, durable_replay = true }
  }
  override_data {
    target = data.terraform_remote_state.history_processing[0]
    values = { outputs = { lifecycle_contract = { schema_version = 1, environment = "dev", deployed = true, active = true, account_deletion_active = true } } }
  }
  assert {
    condition = (
      aws_lambda_function.analysis.environment[0].variables.HISTORY_WRITES_ENABLED == "true" &&
      aws_lambda_function.analysis.environment[0].variables.HISTORY_DURABLE_REPLAY_ENABLED == "true" &&
      aws_lambda_function.history_api["read"].environment[0].variables.RECOGNITION_ENABLED == "true" &&
      aws_lambda_function.history_api["mutation"].environment[0].variables.HISTORY_MUTATIONS_ENABLED == "true"
      && aws_lambda_function.history_api["mutation"].environment[0].variables.RECOGNITION_ENABLED == "true"
    )
    error_message = "Only an explicitly approved activation with active cleanup may enable the requested flows."
  }
}

run "active_sweeps_without_account_deletion_are_insufficient" {
  command = plan
  variables {
    history_features = { reads = true, writes = true, mutations = true, recognition = true, durable_replay = true }
  }
  override_data {
    target = data.terraform_remote_state.history_processing[0]
    values = { outputs = { lifecycle_contract = { schema_version = 1, environment = "dev", deployed = true, active = true, account_deletion_active = false } } }
  }
  expect_failures = [aws_lambda_function.history_api]
}

run "cross_environment_cleanup_is_rejected" {
  command = plan
  variables {
    history_features = { reads = true, writes = true, mutations = true, recognition = true, durable_replay = true }
  }
  override_data {
    target = data.terraform_remote_state.history_processing[0]
    values = { outputs = { lifecycle_contract = { schema_version = 1, environment = "prod", deployed = true, active = true } } }
  }
  expect_failures = [aws_lambda_function.history_api]
}

run "same_names_in_another_account_are_rejected" {
  command = plan
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
          content_table_arn           = "arn:aws:dynamodb:us-east-1:999999999999:table/trustcheckradar-dev-history-content"
          control_table_arn           = "arn:aws:dynamodb:us-east-1:999999999999:table/trustcheckradar-dev-history-control"
          history_retention_seconds   = 7776000
          active_deletion_sla_seconds = 86400
          expiration_index_name       = "ExpirationIndex"
          lifecycle_index_name        = "PendingLifecycleIndex"
          storage_policy              = { approved = true, dedup_retention_seconds = 10368000 }
        }
      }
    }
  }
  expect_failures = [aws_lambda_function.history_api]
}

run "shortened_dedup_retention_is_rejected" {
  command = plan
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
          storage_policy              = { approved = true, dedup_retention_seconds = 7776000 }
        }
      }
    }
  }
  expect_failures = [aws_lambda_function.history_api]
}
