mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "107827791950" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  project_name                    = "trustcheckradar"
  environment                     = "dev"
  aws_region                      = "us-east-1"
  backend_assume_role_principals  = ["lambda.amazonaws.com"]
  deletion_assume_role_principals = ["lambda.amazonaws.com"]
}

run "recovery_storage_is_opt_in" {
  command = plan
  assert {
    condition     = length(aws_dynamodb_table.device_recovery_control) == 0 && !output.device_recovery_control_contract.enabled
    error_message = "Default foundation deployment must not create new recovery data or imply policy approval."
  }
}

run "recovery_storage_requires_its_own_policy" {
  command = plan
  variables {
    device_recovery_control_enabled = true
    device_recovery_policy          = null
  }
  expect_failures = [var.device_recovery_control_enabled]
}

run "policy_approval_does_not_provision_recovery_storage" {
  command = plan
  variables {
    device_recovery_control_enabled = false
    device_recovery_policy = {
      approved               = true
      approval_reference     = "docs/ACCOUNT-DATA-POLICY-DECISIONS.md#owner-approval-2026-09-14"
      audit_retention_days   = 90
      receipt_retention_days = 7
      rate_retention_hours   = 24
      pitr_days              = 7
    }
  }
  assert {
    condition = (
      length(aws_dynamodb_table.device_recovery_control) == 0 &&
      !output.device_recovery_control_contract.enabled &&
      output.device_recovery_control_contract.policy == null
    )
    error_message = "Approved retention must not create recovery storage or advertise an active recovery policy to consumers."
  }
}

run "recovery_storage_has_exact_keys_retention_and_cost_caps" {
  command = plan
  variables {
    device_recovery_control_enabled = true
    device_recovery_policy = {
      approved             = true, approval_reference = "synthetic-test-not-user-approval"
      audit_retention_days = 90, receipt_retention_days = 7, rate_retention_hours = 24, pitr_days = 7
    }
  }
  assert {
    condition = (
      aws_dynamodb_table.device_recovery_control[0].name == "trustcheckradar-dev-device-recovery-control" &&
      aws_dynamodb_table.device_recovery_control[0].hash_key == "PK" &&
      aws_dynamodb_table.device_recovery_control[0].range_key == "SK" &&
      aws_dynamodb_table.device_recovery_control[0].billing_mode == "PAY_PER_REQUEST" &&
      aws_dynamodb_table.device_recovery_control[0].ttl[0].enabled &&
      aws_dynamodb_table.device_recovery_control[0].ttl[0].attribute_name == "expiresAt" &&
      aws_dynamodb_table.device_recovery_control[0].point_in_time_recovery[0].recovery_period_in_days == 7 &&
      aws_dynamodb_table.device_recovery_control[0].on_demand_throughput[0].max_read_request_units == 25 &&
      aws_dynamodb_table.device_recovery_control[0].on_demand_throughput[0].max_write_request_units == 10 &&
      !aws_dynamodb_table.device_recovery_control[0].stream_enabled &&
      output.device_recovery_control_contract.policy.audit_retention_days == 90
    )
    error_message = "Recovery security storage must stay environment-scoped, expiring, bounded and consistent with its own approved policy."
  }
}

run "recovery_storage_requires_separate_production_promotion" {
  command = plan
  variables {
    environment                     = "prod"
    device_recovery_control_enabled = true
    device_recovery_policy = {
      approved             = true, approval_reference = "synthetic-test-not-user-approval"
      audit_retention_days = 90, receipt_retention_days = 7, rate_retention_hours = 24, pitr_days = 7
    }
  }
  expect_failures = [var.device_recovery_control_enabled]
}
