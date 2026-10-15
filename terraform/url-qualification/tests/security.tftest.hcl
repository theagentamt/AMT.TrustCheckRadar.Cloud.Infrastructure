mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-url-qualification" }
  }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::107827791950:role/qualification-cleanup" } }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:/aws/lambda/trustcheckradar-dev-url-qualification-cleanup" }
  }
  mock_resource "aws_lambda_function" { defaults = { version = "1" } }
  mock_resource "aws_lambda_alias" {
    defaults = { arn = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-qualification-cleanup:live" }
  }
  mock_resource "aws_scheduler_schedule_group" {
    defaults = { arn = "arn:aws:scheduler:us-east-1:107827791950:schedule-group/trustcheckradar-dev-url-qualification" }
  }
}

run "default_is_resource_and_execution_free" {
  command = plan
  assert {
    condition = (
      length(aws_dynamodb_table.qualification) == 0 && length(aws_lambda_function.cleanup) == 0 &&
      length(aws_iam_role.cleanup) == 0 && length(aws_iam_role.scheduler) == 0 &&
      length(aws_scheduler_schedule_group.cleanup) == 0 && length(aws_scheduler_schedule.cleanup) == 0 &&
      length(aws_lambda_alias.cleanup) == 0 && length(aws_lambda_function_event_invoke_config.cleanup) == 0 &&
      length(aws_cloudwatch_log_group.cleanup) == 0 && length(aws_cloudwatch_metric_alarm.cleanup) == 0 &&
      !output.qualification_store.provisioned && !output.qualification_store.new_admission_enabled &&
      !output.qualification_store.provider_enabled && !output.qualification_store.history_expansion
    )
    error_message = "Local source defaults must provision nothing and enable no capability."
  }
}
run "future_store_has_no_backups_or_identity_payload_indexes" {
  command = plan
  variables { enabled = true }
  assert {
    condition = (
      aws_dynamodb_table.qualification[0].billing_mode == "PAY_PER_REQUEST" &&
      aws_dynamodb_table.qualification[0].deletion_protection_enabled &&
      aws_dynamodb_table.qualification[0].server_side_encryption[0].enabled &&
      !aws_dynamodb_table.qualification[0].point_in_time_recovery[0].enabled &&
      aws_dynamodb_table.qualification[0].ttl[0].attribute_name == "expiresAt" &&
      aws_dynamodb_table.qualification[0].ttl[0].enabled &&
      length(aws_dynamodb_table.qualification[0].global_secondary_index) == 1 &&
      one(aws_dynamodb_table.qualification[0].global_secondary_index).projection_type == "INCLUDE" &&
      one(aws_dynamodb_table.qualification[0].global_secondary_index).non_key_attributes == toset(["expiresAt"]) &&
      length(aws_lambda_function.cleanup) == 0
    )
    error_message = "Synthetic expiry metadata only; no copied payload, backup or automatic runtime."
  }
}
run "cleanup_installation_is_closed_and_separated" {
  command = plan
  variables {
    enabled         = true
    alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
    cleanup_artifact = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/0000000000000000000000000000000000000000/url_qualification_cleanup.zip"
      object_version = "synthetic-immutable"
      source_hash    = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    }
  }
  assert {
    condition = (
      aws_lambda_function.cleanup[0].runtime == "python3.14" &&
      aws_lambda_function.cleanup[0].architectures == tolist(["arm64"]) &&
      aws_lambda_function.cleanup[0].environment[0].variables.URL_CLEANUP_ENABLED == "false" &&
      aws_lambda_function.cleanup[0].environment[0].variables.URL_RETENTION_APPROVED == "false" &&
      aws_scheduler_schedule.cleanup[0].state == "DISABLED" &&
      aws_scheduler_schedule.cleanup[0].schedule_expression == "rate(5 minutes)" &&
      alltrue([for alarm in aws_cloudwatch_metric_alarm.cleanup : !alarm.actions_enabled]) &&
      aws_lambda_function_event_invoke_config.cleanup[0].maximum_retry_attempts == 0
    )
    error_message = "Installing a pinned cleanup artifact must never activate execution or alarms."
  }
  assert {
    condition = (
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[1].Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"] == ["URL_QUALIFICATION_EXPIRING"] &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[2].Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"] == ["RUN#*"] &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[3].Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"] == ["CONTROL"] &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[4].Effect == "Deny" &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[6].Effect == "Deny" &&
      jsondecode(aws_iam_role_policy.scheduler[0].policy).Statement[0].Resource == aws_lambda_alias.cleanup[0].arn
    )
    error_message = "Cleanup may touch only synthetic run expiry/control, never authority, identity or providers."
  }
  assert {
    condition = (
      length(jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement) == 7 &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[1].Action == "dynamodb:Query" &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[1].Resource == "${aws_dynamodb_table.qualification[0].arn}/index/GSI1" &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[2].Action == "dynamodb:DeleteItem" &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[2].Resource == aws_dynamodb_table.qualification[0].arn &&
      toset(jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[3].Action) == toset(["dynamodb:GetItem", "dynamodb:UpdateItem"]) &&
      jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[3].Resource == aws_dynamodb_table.qualification[0].arn &&
      toset(jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[4].NotResource) == toset([aws_dynamodb_table.qualification[0].arn, "${aws_dynamodb_table.qualification[0].arn}/index/GSI1"]) &&
      alltrue([for i in [4, 5, 6] : jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[i].Effect == "Deny"]) &&
      alltrue([for action in ["dynamodb:Scan", "dynamodb:CreateBackup", "backup:*"] : contains(jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[5].Action, action)]) &&
      alltrue([for action in ["lambda:InvokeFunction", "secretsmanager:*", "cognito-idp:*", "sts:AssumeRole"] : contains(jsondecode(aws_iam_role_policy.cleanup[0].policy).Statement[6].Action, action)]) &&
      jsondecode(aws_iam_role.scheduler[0].assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"] == "107827791950" &&
      jsondecode(aws_iam_role.scheduler[0].assume_role_policy).Statement[0].Condition.ArnEquals["aws:SourceArn"] == aws_scheduler_schedule_group.cleanup[0].arn
    )
    error_message = "Cleanup must retain exact index/item actions and explicit identity/provider/backup denies, with a confused-deputy fence on the scheduler."
  }
}
run "unapproved_retention_cannot_run_cleanup" {
  command = plan
  variables { cleanup_enabled = true }
  expect_failures = [var.cleanup_enabled]
}
run "unrecorded_retention_approval_rejected" {
  command = plan
  variables { retention_approved = true }
  expect_failures = [var.retention_approval_reference]
}
run "uat_is_not_a_qualification_target" {
  command = plan
  variables { environment = "uat" }
  expect_failures = [var.environment]
}
run "different_alert_destination_rejected" {
  command = plan
  variables { alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:another-recipient" }
  expect_failures = [var.alert_topic_arn]
}
run "different_region_is_rejected" {
  command = plan
  variables { aws_region = "us-west-2" }
  expect_failures = [var.aws_region]
}
run "different_account_cannot_provision_store" {
  command = plan
  variables { enabled = true }
  override_data {
    target = data.aws_caller_identity.current
    values = { account_id = "999999999999" }
  }
  expect_failures = [aws_dynamodb_table.qualification]
}
