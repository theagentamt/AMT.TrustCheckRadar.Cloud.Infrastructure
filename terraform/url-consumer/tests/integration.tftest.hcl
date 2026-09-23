mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::107827791950:role/candidate" } }
  mock_resource "aws_secretsmanager_secret" { defaults = { arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-ABC123" } }
  mock_resource "aws_lambda_function" { defaults = { version = "1" } }
  mock_resource "aws_lambda_alias" { defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:mock:live", invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:107827791950:function:mock:live/invocations" } }
  mock_resource "aws_cloudwatch_event_rule" { defaults = { arn = "arn:aws:events:us-east-1:107827791950:rule/mock" } }
}
variables {
  aws_region   = "us-east-1"
  project_name = "trustcheckradar"
  environment  = "dev"
  enabled      = true
  deployment = {
    "artifacts" : {
      "consumer" : {
        "bucket" : "trustcheckradar-dev-107827791950-artifacts",
        "key" : "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/url_consumer.zip",
        "object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi",
        "source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM="
      },
      "recovery" : {
        "bucket" : "trustcheckradar-dev-107827791950-artifacts",
        "key" : "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/url_lease_recovery.zip",
        "object_version" : "tkwzppvVK_nMdKHgxzFw6DeYsVu3E8X8",
        "source_hash" : "W1nhRs6tjdVEYhreS0NwSSh2ZwNlAzdkw52vGOzWrtE="
      },
      "entitlements" : {
        "bucket" : "trustcheckradar-dev-107827791950-artifacts",
        "key" : "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/v1_entitlements.zip",
        "object_version" : "gR1q8yYMmdsD9.tEZpi8XBwkRLouvsgK",
        "source_hash" : "aIRFixV+H/phUTWYWWQrsz6ruzMaNkptStthsvN5U/8="
      },
      "deletion" : {
        "bucket" : "trustcheckradar-dev-107827791950-artifacts",
        "key" : "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/v1_authority_deletion.zip",
        "object_version" : "test-deletion-version",
        "source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM="
      }
    },
    "users_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users",
    "devices_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings",
    "deletion_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger",
    "authority_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements",
    "assessment_alias_arn" : "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live",
    "cognito_issuer" : "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_TestPool",
    "cognito_app_client_id" : "testclient"
  }
  deletion_stream_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-06T23:20:47.091"
  api_gateway = {
    "api_id" : "abcdefghij",
    "execution_arn" : "arn:aws:execute-api:us-east-1:107827791950:abcdefghij"
  }
  alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
  authority_configuration = {
    "operation_validity_seconds" : 300,
    "worker_settlement_seconds" : 60,
    "reconciliation_seconds" : 3600,
    "counter_retention_seconds" : 604800
  }
}
run "routes_and_cleanup_default_inactive" {
  command = apply
  assert {
    condition     = jsondecode(aws_cloudwatch_event_target.maintenance["recovery"].input) == { schemaVersion = 1 } && jsondecode(aws_cloudwatch_event_target.maintenance["deletion"].input) == { schemaVersion = 1, operation = "reconcile-v1-authority-deletion" }
    error_message = "Maintenance payloads must preserve the exact numeric schemaVersion required by the runtime."
  }
  assert {
    condition     = length(aws_apigatewayv2_route.v1) == 5 && alltrue([for r in aws_apigatewayv2_route.v1 : r.authorization_type == "JWT" && r.authorization_scopes == toset(["aws.cognito.signin.user.admin"])])
    error_message = "Every V1 route must require the configured access-token JWT scope."
  }
  assert {
    condition     = alltrue([for p in aws_lambda_permission.v1 : p.qualifier == "live" && p.source_account == "107827791950" && startswith(p.source_arn, "arn:aws:execute-api:us-east-1:107827791950:abcdefghij/*/") && !endswith(p.source_arn, "/*")])
    error_message = "Gateway invoke permission must bind same-account API, alias, method and path."
  }
  assert {
    condition     = alltrue([for rule in aws_cloudwatch_event_rule.maintenance : rule.state == "DISABLED"]) && !aws_lambda_event_source_mapping.v1_deletion[0].enabled && aws_lambda_function.runtime["deletion"].environment[0].variables.V1_AUTHORITY_DELETION_ENABLED == "false" && !output.candidate_contract.general_customer_access
    error_message = "Provisioning routes and cleanup must not activate customer access or scheduled writes."
  }
  assert {
    condition     = anytrue([for statement in jsondecode(aws_iam_role_policy.deletion[0].policy).Statement : statement.Effect == "Deny" && try(contains(statement.Action, "lambda:InvokeFunction"), false)]) && aws_lambda_function.runtime["deletion"].timeout == 30 && aws_lambda_function.runtime["deletion"].reserved_concurrent_executions == 1
    error_message = "Deletion must be bounded and cannot call providers."
  }
}
run "inventory_markers_are_not_mutable" {
  command = apply
  assert {
    condition = alltrue([for policy in [aws_iam_role_policy.consumer[0].policy, aws_iam_role_policy.entitlements[0].policy, aws_iam_role_policy.deletion[0].policy, aws_iam_role_policy.recovery[0].policy] : alltrue([
      for statement in jsondecode(policy).Statement :
      statement.Effect != "Allow" || statement.Resource != var.deployment.authority_table_arn ||
      !anytrue([for action in ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"] : try(contains(statement.Action, action), false)]) ||
      try(statement.Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"] == ["V1#*#*"], false) ||
      try(statement.Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"] == ["V1#CHECKPOINT"] && statement.Action == ["dynamodb:UpdateItem"], false)
    ])])
    error_message = "Ordinary writes must exclude inventory; recovery may update only its separate checkpoint partition."
  }
  assert {
    condition = alltrue([for statement in jsondecode(aws_iam_role_policy.deletion[0].policy).Statement :
      statement.Effect != "Allow" || statement.Resource != var.deployment.deletion_table_arn ||
      !anytrue([for action in ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"] : try(contains(statement.Action, action), false)]) ||
      try(statement.Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"] == ["ACCOUNT#*"], false) ||
      try(statement.Action == ["dynamodb:UpdateItem"] && statement.Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"] == ["V1#CONTROL"] &&
      statement.Condition["ForAllValues:StringEquals"]["dynamodb:Attributes"] == ["PK", "SK", "cursor", "revision", "scanStartedAtEpoch", "lastFullPassAtEpoch"], false)
    ])
    error_message = "Deletion ledger inventory must remain excluded from writes; its cursor accepts only progress fields."
  }
}
run "engineering_requires_subjects" {
  command = plan
  variables { activate_engineering = true }
  expect_failures = [var.activate_engineering]
}
run "engineering_restricted_and_policy_pinned" {
  command = apply
  variables {
    activate_engineering = true
    engineering_subjects = ["00000000-0000-4000-8000-000000000001"]
  }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].environment[0].variables.RECEIPT_RETENTION_SECONDS == "604800" && aws_lambda_function.runtime["entitlements"].environment[0].variables.TRIAL_AUTHORITY_RETENTION_APPROVED == "true" && aws_lambda_function.runtime["deletion"].environment[0].variables.DEV_SUBJECT_ALLOWLIST_JSON == jsonencode(["00000000-0000-4000-8000-000000000001"]) && !output.candidate_contract.general_customer_access
    error_message = "Engineering must preserve approved retention and exact-subject restriction."
  }
  assert {
    condition     = alltrue([for rule in aws_cloudwatch_event_rule.maintenance : rule.state == "ENABLED"]) && aws_lambda_event_source_mapping.v1_deletion[0].enabled && alltrue([for alarm in aws_cloudwatch_metric_alarm.worker_heartbeat : alarm.actions_enabled && alarm.treat_missing_data == "breaching"])
    error_message = "Engineering activation requires recovery/deletion continuity and heartbeat alarms."
  }
}
run "invalid_subject_rejected" {
  command = plan
  variables { engineering_subjects = ["*"] }
  expect_failures = [var.engineering_subjects]
}

run "access_only_requires_recorded_readiness_and_subject" {
  command = plan
  variables { activate_access_engineering = true }
  expect_failures = [var.activate_access_engineering]
}
run "access_only_rejects_missing_readiness" {
  command = plan
  variables {
    activate_access_engineering = true
    engineering_subjects        = ["00000000-0000-4000-8000-000000000001"]
  }
  expect_failures = [var.activate_access_engineering]
}
run "access_only_keeps_providers_and_trial_closed" {
  command = apply
  variables {
    activate_access_engineering    = true
    engineering_subjects           = ["00000000-0000-4000-8000-000000000001"]
    access_qualification_reference = "synthetic test evidence, not operational approval"
  }
  assert {
    condition = (
      aws_lambda_function.runtime["consumer"].environment[0].variables.CONSUMER_ENABLED == "false" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.AUTHORITY_ENABLED == "false" &&
      aws_lambda_function.runtime["consumer"].environment[0].variables.V1_ENTITLEMENTS_ENABLED == "false" &&
      aws_lambda_function.runtime["entitlements"].environment[0].variables.CONSUMER_ENABLED == "false" &&
      aws_lambda_function.runtime["entitlements"].environment[0].variables.AUTHORITY_ENABLED == "true" &&
      aws_lambda_function.runtime["entitlements"].environment[0].variables.V1_ENTITLEMENTS_ENABLED == "true" &&
      aws_lambda_function.runtime["entitlements"].environment[0].variables.TRIAL_AUTHORITY_RETENTION_APPROVED == "false" &&
      aws_lambda_function.runtime["entitlements"].environment[0].variables.DEV_SUBJECT_ALLOWLIST_JSON == jsonencode(["00000000-0000-4000-8000-000000000001"]) &&
      output.candidate_contract.access_enabled && !output.candidate_contract.consumer_enabled &&
      !output.candidate_contract.trial_activation_enabled && !output.candidate_contract.general_customer_access
    )
    error_message = "Access-only mode must enable exact-subject snapshots without URL execution, a provider call, or trial activation."
  }
  assert {
    condition = (
      aws_lambda_function.runtime["recovery"].environment[0].variables.LEASE_SWEEP_ENABLED == "true" &&
      aws_lambda_function.runtime["deletion"].environment[0].variables.V1_AUTHORITY_DELETION_ENABLED == "true" &&
      alltrue([for rule in aws_cloudwatch_event_rule.maintenance : rule.state == "ENABLED"]) &&
      aws_lambda_event_source_mapping.v1_deletion[0].enabled &&
      alltrue([for alarm in aws_cloudwatch_metric_alarm.worker_heartbeat : alarm.actions_enabled && alarm.treat_missing_data == "breaching"]) &&
      aws_cloudwatch_metric_alarm.deletion_full_pass_age[0].actions_enabled
    )
    error_message = "Access-only mode must retain monitored scheduled expiry, lease recovery and subject-scoped deletion."
  }
}
run "access_only_and_full_modes_cannot_overlap" {
  command = plan
  variables {
    activate_engineering          = true
    activate_access_engineering   = true
    engineering_subjects          = ["00000000-0000-4000-8000-000000000001"]
    access_qualification_reference = "synthetic test evidence"
  }
  expect_failures = [var.activate_access_engineering]
}
