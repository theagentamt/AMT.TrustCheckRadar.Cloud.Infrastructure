mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::107827791950:role/synthetic-history-lifecycle" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-history-lifecycle" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:/aws/lambda/trustcheckradar-dev-history-lifecycle" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:107827791950:rule/trustcheckradar-dev-history-lifecycle-sweep" }
  }
}

override_data {
  target = data.terraform_remote_state.upstream["foundation"]
  values = {
    outputs = { downstream_contract = {
      schema_version                    = 1
      artifact_bucket_name              = "synthetic-dev-artifacts"
      device_bindings_table_name        = "trustcheckradar-dev-device-bindings"
      analysis_abuse_control_table_name = "trustcheckradar-dev-analysis-abuse-control"
      analysis_abuse_control_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-analysis-abuse-control"
    } }
  }
}

override_data {
  target = data.terraform_remote_state.upstream["history-data"]
  values = {
    outputs = { downstream_contract = {
      schema_version        = 1
      environment           = "dev"
      enabled               = true
      content_table_name    = "trustcheckradar-dev-history-content"
      content_table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-content"
      control_table_name    = "trustcheckradar-dev-history-control"
      control_table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-control"
      expiration_index_name = "ExpirationIndex"
      lifecycle_index_name  = "PendingLifecycleIndex"
      storage_policy = {
        approved                = true
        dedup_retention_seconds = 7948800
      }
    } }
  }
}

variables {
  aws_region          = "us-east-1"
  project_name        = "trustcheckradar"
  environment         = "dev"
  state_bucket_name   = "synthetic-state"
  state_bucket_region = "us-east-1"
  artifact = {
    release_id     = "synthetic-test-only"
    object_version = "synthetic-version"
    source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  }
  runtime_policy = {
    acceptance_approved             = true
    approval_reference              = "synthetic-test-only-not-a-policy-decision"
    mutation_retention_days         = 2
    start_epoch_hour                = 0
    max_items_per_sweep             = 100
    max_bucket_queries_per_sweep    = 100
    expiration_reconciliation_hours = 24
    erasure_batch_size              = 25
    completion_stuck_seconds        = 3600
    completion_recheck_seconds      = 300
  }
}

run "disabled_creates_no_resources_or_remote_dependencies" {
  command = plan
  variables {
    artifact       = null
    runtime_policy = null
  }
  assert {
    condition = (
      !output.lifecycle_contract.deployed && !output.lifecycle_contract.active &&
      length(data.terraform_remote_state.upstream) == 0 &&
      length(aws_lambda_function.lifecycle) == 0 && length(aws_iam_role.lifecycle) == 0 &&
      length(aws_cloudwatch_log_group.lifecycle) == 0 && length(aws_cloudwatch_event_rule.sweep) == 0 &&
      length(aws_cloudwatch_metric_alarm.lifecycle) == 0 && length(aws_cloudwatch_metric_alarm.function) == 0
    )
    error_message = "Disabled environments must create no paid resources, IAM, schedules or remote-state dependencies."
  }
}

run "artifact_required_for_deployment" {
  command = plan
  variables {
    lifecycle_deployment_enabled = true
    artifact                     = null
  }
  expect_failures = [var.lifecycle_deployment_enabled]
}

run "artifact_must_be_immutable_and_hashed" {
  command = plan
  variables {
    artifact = { release_id = "../latest", object_version = "null", source_hash = "not-a-hash" }
  }
  expect_failures = [var.artifact]
}

run "uat_requires_promotion" {
  command = plan
  variables {
    lifecycle_deployment_enabled = true
    environment                  = "uat"
  }
  expect_failures = [var.lifecycle_deployment_enabled]
}

run "prod_requires_promotion" {
  command = plan
  variables {
    lifecycle_deployment_enabled = true
    environment                  = "prod"
  }
  expect_failures = [var.lifecycle_deployment_enabled]
}

run "deployment_does_not_activate_sweeps_or_other_features" {
  command = apply
  variables {
    lifecycle_deployment_enabled = true
  }
  assert {
    condition = (
      aws_cloudwatch_event_rule.sweep[0].state == "DISABLED" &&
      length(aws_cloudwatch_metric_alarm.lifecycle) == 0 &&
      aws_lambda_function.lifecycle[0].environment[0].variables.HISTORY_LIFECYCLE_ENABLED == "false" &&
      alltrue([for key in ["HISTORY_READS_ENABLED", "HISTORY_WRITES_ENABLED", "HISTORY_DURABLE_REPLAY_ENABLED", "HISTORY_MUTATIONS_ENABLED", "RECOGNITION_ENABLED"] :
        aws_lambda_function.lifecycle[0].environment[0].variables[key] == "false"
      ])
    )
    error_message = "Provisioning must never activate scheduled cleanup or unrelated API/producer gates."
  }
  assert {
    condition = (
      aws_lambda_function.lifecycle[0].s3_bucket == "synthetic-dev-artifacts" &&
      aws_lambda_function.lifecycle[0].s3_key == "releases/synthetic-test-only/history_lifecycle.zip" &&
      aws_lambda_function.lifecycle[0].s3_object_version == var.artifact.object_version &&
      aws_lambda_function.lifecycle[0].source_code_hash == var.artifact.source_hash &&
      aws_lambda_function.lifecycle[0].reserved_concurrent_executions == 1 &&
      aws_lambda_function.lifecycle[0].timeout == 60 && aws_lambda_function.lifecycle[0].memory_size == 256 &&
      aws_lambda_function.lifecycle[0].handler == "app.lambda_handler" &&
      aws_lambda_function.lifecycle[0].runtime == "python3.12" &&
      aws_lambda_function.lifecycle[0].environment[0].variables.HISTORY_DEDUP_RETENTION_DAYS == "92" &&
      aws_lambda_function.lifecycle[0].environment[0].variables.HISTORY_EXPIRATION_RECONCILIATION_HOURS == "24"
    )
    error_message = "Artifact pinning, runtime limits and exact policy conversion must match the handback."
  }
  assert {
    condition = (
      length(data.aws_iam_policy_document.runtime[0].statement) == 5 &&
      alltrue([for statement in data.aws_iam_policy_document.runtime[0].statement :
        !contains(statement.actions, "dynamodb:Scan") && !contains(statement.actions, "dynamodb:TransactWriteItems") &&
        !contains(statement.resources, "*") &&
        alltrue([for action in statement.actions : startswith(action, "dynamodb:") || startswith(action, "logs:")])
      ]) &&
      alltrue([for statement in data.aws_iam_policy_document.runtime[0].statement :
        statement.sid != "BoundedLifecycleIndexQueries" ? true :
        toset(statement.actions) == toset(["dynamodb:Query"]) && toset(statement.resources) == toset([
          "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-content/index/ExpirationIndex",
          "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-control/index/ExpirationIndex",
          "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-control/index/PendingLifecycleIndex",
          ]) && alltrue([for condition in statement.condition :
          condition.test == "ForAllValues:StringLike" && condition.variable == "dynamodb:LeadingKeys" &&
          toset(condition.values) == toset(["HISTORY#*", "CONTROL#*", "PENDING#*"])
        ])
      ]) &&
      alltrue([for statement in data.aws_iam_policy_document.runtime[0].statement :
        statement.sid != "ReplayContentErasure" ? true :
        toset(statement.actions) == toset(["dynamodb:Query", "dynamodb:UpdateItem"]) &&
        toset(statement.resources) == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-analysis-abuse-control"])
      ]) &&
      alltrue([for statement in data.aws_iam_policy_document.runtime[0].statement :
        statement.sid != "ControlJobsAndCheckpoints" ? true :
        toset(statement.actions) == toset(["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem"]) &&
        alltrue([for condition in statement.condition : toset(condition.values) == toset(["USER#*", "CURSOR#*", "LIFECYCLE#dev"])])
      ])
    )
    error_message = "Lifecycle IAM must stay exact-index, bounded-leading-key and replay-cleanup scoped without Scan or service wildcards."
  }
}

run "activation_requires_runtime_and_notifications" {
  command = plan
  variables {
    lifecycle_deployment_enabled = true
    lifecycle_active             = true
    runtime_policy               = null
  }
  expect_failures = [var.lifecycle_active]
}

run "activation_requires_explicit_acceptance" {
  command = plan
  variables {
    lifecycle_deployment_enabled = true
    lifecycle_active             = true
    alarm_topic_arn              = "arn:aws:sns:us-east-1:107827791950:synthetic"
    runtime_policy = {
      acceptance_approved             = false, approval_reference = "", mutation_retention_days = 2,
      start_epoch_hour                = 0, max_items_per_sweep = 100, max_bucket_queries_per_sweep = 100,
      expiration_reconciliation_hours = 24, erasure_batch_size = 25,
      completion_stuck_seconds        = 3600, completion_recheck_seconds = 300
    }
  }
  expect_failures = [var.lifecycle_active]
}

run "runtime_bounds_are_not_silently_defaulted" {
  command = plan
  variables {
    runtime_policy = {
      acceptance_approved             = true, approval_reference = "synthetic", mutation_retention_days = 1.5,
      start_epoch_hour                = 1, max_items_per_sweep = 1001, max_bucket_queries_per_sweep = 39,
      expiration_reconciliation_hours = 169, erasure_batch_size = 26,
      completion_stuck_seconds        = 0, completion_recheck_seconds = 0
    }
  }
  expect_failures = [var.runtime_policy]
}

run "notification_region_must_match" {
  command = plan
  variables {
    alarm_topic_arn = "arn:aws:sns:us-west-2:107827791950:synthetic"
  }
  expect_failures = [var.alarm_topic_arn]
}

run "cross_environment_state_rejected_even_with_promotion" {
  command = plan
  variables {
    lifecycle_deployment_enabled = true
    promotion_approved           = true
    environment                  = "uat"
  }
  expect_failures = [aws_lambda_function.lifecycle]
}

run "cross_account_arns_rejected" {
  command = plan
  variables {
    lifecycle_deployment_enabled = true
  }
  override_data {
    target = data.aws_caller_identity.current[0]
    values = { account_id = "000000000000" }
  }
  expect_failures = [aws_lambda_function.lifecycle]
}

run "locator_retention_must_cover_content_and_cleanup" {
  command = plan
  variables {
    lifecycle_deployment_enabled = true
  }
  override_data {
    target = data.terraform_remote_state.upstream["history-data"]
    values = {
      outputs = { downstream_contract = {
        schema_version        = 1
        environment           = "dev"
        enabled               = true
        content_table_name    = "trustcheckradar-dev-history-content"
        content_table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-content"
        control_table_name    = "trustcheckradar-dev-history-control"
        control_table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-history-control"
        expiration_index_name = "ExpirationIndex"
        lifecycle_index_name  = "PendingLifecycleIndex"
        storage_policy = {
          approved                = true
          dedup_retention_seconds = 7776000
        }
      } }
    }
  }
  expect_failures = [aws_lambda_function.lifecycle]
}

run "active_schedule_has_exact_input_and_observable_failures" {
  command = apply
  variables {
    lifecycle_deployment_enabled = true
    lifecycle_active             = true
    alarm_topic_arn              = "arn:aws:sns:us-east-1:107827791950:synthetic"
  }
  assert {
    condition = (
      aws_cloudwatch_event_rule.sweep[0].state == "ENABLED" &&
      aws_cloudwatch_event_rule.sweep[0].schedule_expression == "rate(5 minutes)" &&
      aws_cloudwatch_event_target.sweep[0].input == jsonencode({ schemaVersion = 1, operation = "sweep" }) &&
      aws_lambda_permission.schedule[0].source_arn == aws_cloudwatch_event_rule.sweep[0].arn &&
      aws_lambda_permission.schedule[0].principal == "events.amazonaws.com" &&
      aws_lambda_function_event_invoke_config.lifecycle[0].maximum_retry_attempts == 1 &&
      aws_lambda_function_event_invoke_config.lifecycle[0].maximum_event_age_in_seconds == 300
    )
    error_message = "The scheduled invocation must be source-restricted, content-free and retry-bounded."
  }
  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.lifecycle) == 6 && length(aws_cloudwatch_metric_alarm.function) == 2 &&
      aws_cloudwatch_metric_alarm.lifecycle["heartbeat"].treat_missing_data == "breaching" &&
      aws_cloudwatch_metric_alarm.lifecycle["heartbeat"].evaluation_periods == 2 &&
      aws_cloudwatch_metric_alarm.lifecycle["heartbeat"].threshold == 1 &&
      aws_cloudwatch_metric_alarm.lifecycle["expiry_sla"].unit == "Seconds" &&
      aws_cloudwatch_metric_alarm.lifecycle["expiry_sla"].threshold == 86400 &&
      alltrue([for alarm in aws_cloudwatch_metric_alarm.lifecycle :
        alarm.namespace == "AMT/TrustCheckRadar/History" && alarm.period == 300 &&
        alarm.dimensions == tomap({ Environment = "dev" }) &&
        toset(alarm.alarm_actions) == toset([var.alarm_topic_arn]) &&
        toset(alarm.ok_actions) == toset([var.alarm_topic_arn])
      ])
    )
    error_message = "Heartbeat, backlog, SLA and Lambda failures must alert without personal metric dimensions."
  }
}
