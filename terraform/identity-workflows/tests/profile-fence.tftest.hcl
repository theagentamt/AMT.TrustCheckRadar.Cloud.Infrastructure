mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_data "aws_iam_policy_document" { defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" } }
}

# Mock providers cannot import; override the adopted group while retaining
# assertions against configured retention in each plan.
override_resource {
  target = aws_cloudwatch_log_group.post_confirmation
}

variables {
  aws_region          = "us-east-1"
  environment         = "dev"
  project_name        = "trustcheckradar"
  state_bucket_name   = "synthetic-state"
  state_bucket_region = "us-east-1"
  artifact_release    = "existing-release"
}

override_data {
  target = data.terraform_remote_state.foundation
  values = { outputs = { downstream_contract = {
    schema_version             = 1
    artifact_bucket_name       = "synthetic-artifacts"
    cognito_user_pool_id       = "us-east-1_example"
    users_table_arn            = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
    deletion_ledger_table_name = "trustcheckradar-dev-deletion-ledger"
    deletion_ledger_table_arn  = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
  } } }
}

run "default_preserves_existing_writer_and_log_retention" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.post_confirmation.s3_key == "releases/existing-release/post_confirmation.zip" &&
      length(aws_cloudwatch_log_group.post_confirmation) == 0 &&
      length(data.aws_iam_policy_document.post_confirmation_dynamodb.statement) == 1 &&
      !output.profile_fence_contract.post_confirmation_fenced &&
      output.profile_fence_contract.log_retention_days == null
    )
    error_message = "Default inputs must preserve the currently deployed package, IAM and unmanaged log retention."
  }
}

run "fenced_candidate_requires_explicit_log_policy" {
  command = plan
  variables {
    profile_fence_deployment = {
      release_id         = "candidate", object_version = "version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = false
    }
  }
  expect_failures = [var.profile_fence_deployment]
}

run "candidate_pins_writer_and_transactional_fence" {
  command = plan
  variables {
    profile_fence_deployment = {
      release_id         = "candidate", object_version = "version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = false
    }
    post_confirmation_log_policy = { retention_days = 14, approval_reference = "synthetic-test-not-user-approval" }
    post_confirmation_lambda_env = { DELETION_LEDGER_TABLE_NAME = "wrong-table" }
  }
  assert {
    condition = (
      aws_lambda_function.post_confirmation.s3_key == "releases/candidate/post_confirmation.zip" &&
      aws_lambda_function.post_confirmation.s3_object_version == "version" &&
      aws_lambda_function.post_confirmation.source_code_hash == var.profile_fence_deployment.source_hash &&
      aws_lambda_function.post_confirmation.environment[0].variables["DELETION_LEDGER_TABLE_NAME"] == "trustcheckradar-dev-deletion-ledger" &&
      aws_cloudwatch_log_group.post_confirmation[0].retention_in_days == 14 &&
      terraform_data.configure_user_pool_post_confirmation.triggers_replace.source_version == "version" &&
      !output.profile_fence_contract.account_deletion_activation_approved
    )
    error_message = "The corrected package, authoritative ledger and approved log policy must be selected together without approving account deletion."
  }
  assert {
    condition = (
      one([for statement in data.aws_iam_policy_document.post_confirmation_dynamodb.statement : statement if statement.sid == "UsersTableWrite"]).actions == toset(["dynamodb:PutItem"]) &&
      one([for statement in data.aws_iam_policy_document.post_confirmation_dynamodb.statement : statement if statement.sid == "PreventDeletedProfileRecreation"]).resources == toset(["arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"]) &&
      one([for statement in data.aws_iam_policy_document.post_confirmation_dynamodb.statement : statement if statement.sid == "PreventDeletedProfileRecreation"]).actions == toset(["dynamodb:ConditionCheckItem"]) &&
      alltrue([for statement in data.aws_iam_policy_document.post_confirmation_dynamodb.statement :
        anytrue([for condition in statement.condition : condition.variable == "dynamodb:EnclosingOperation" && toset(condition.values) == toset(["TransactWriteItems"])]) &&
        anytrue([for condition in statement.condition : condition.variable == "dynamodb:LeadingKeys"])
      ])
    )
    error_message = "Both the profile write and ledger absence check must be transaction-only, resource-scoped and partition-scoped."
  }
}

run "candidate_cannot_use_other_environment_tables" {
  command = plan
  variables {
    environment = "uat"
    profile_fence_deployment = {
      release_id         = "candidate", object_version = "version", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      approval_reference = "synthetic-test", promotion_approved = true
    }
    post_confirmation_log_policy = { retention_days = 14, approval_reference = "synthetic-test" }
  }
  expect_failures = [aws_lambda_function.post_confirmation]
}

run "unlimited_retention_is_not_a_finite_policy" {
  command = plan
  variables { post_confirmation_log_policy = { retention_days = 0, approval_reference = "synthetic-test" } }
  expect_failures = [var.post_confirmation_log_policy]
}
