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
run "null_preserves_all_baseline_artifacts" {
  command = plan
  variables {
  }
  assert {
    condition     = alltrue([for k, a in var.deployment.artifacts : aws_lambda_function.runtime[k].s3_key == a.key && aws_lambda_function.runtime[k].source_code_hash == a.source_hash])
    error_message = "Deletion correction must retain baseline scope and siblings."
  }
}
run "patch_selects_only_deletion_without_activation" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  assert {
    condition     = aws_lambda_function.runtime["deletion"].s3_key == var.deletion_artifact_override.artifact.key
    error_message = "Deletion correction must retain baseline scope and siblings."
  }
  assert {
    condition     = alltrue([for k, a in var.deployment.artifacts : aws_lambda_function.runtime[k].s3_key == a.key && aws_lambda_function.runtime[k].source_code_hash == a.source_hash if k != "deletion"])
    error_message = "Deletion correction must retain baseline scope and siblings."
  }
  assert {
    condition     = aws_lambda_function.runtime["deletion"].environment[0].variables.V1_AUTHORITY_DELETION_ENABLED == "false"
    error_message = "Deletion correction must retain baseline scope and siblings."
  }
}
run "refuse_stale_base_hash" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_stale_base_source" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "cccccccccccccccccccccccccccccccccccccccc", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_wrong_bucket" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "other-bucket", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_wrong_function" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/other.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_missing_version" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_null_version" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "null", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_missing_provenance" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_bad_patch_source" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "invalid", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_non_dev" {
  command = plan
  variables {
    environment                = "uat"
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deployment]
}
run "activation_requires_effective_patch_source" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
    deletion_activation        = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "subjects" : ["00000000-0000-4000-8000-000000000001"], "inventory_reference" : "synthetic; no approval", "runtime_reference" : "synthetic", "permissions_reference" : "synthetic" }
  }
  assert {
    condition     = aws_lambda_function.runtime["deletion"].s3_key == "releases/${var.deletion_activation.source_sha}/v1_authority_deletion.zip"
    error_message = "Deletion correction must retain baseline scope and siblings."
  }
  assert {
    condition     = aws_lambda_function.runtime["deletion"].environment[0].variables.DEV_SUBJECT_ALLOWLIST_JSON == jsonencode(["00000000-0000-4000-8000-000000000001"])
    error_message = "Deletion correction must retain baseline scope and siblings."
  }
}
run "refuse_old_activation_source" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_authority_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
    deletion_activation        = { "source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "subjects" : ["00000000-0000-4000-8000-000000000001"], "inventory_reference" : "synthetic; no approval", "runtime_reference" : "synthetic", "permissions_reference" : "synthetic" }
  }
  expect_failures = [var.deletion_activation]
}
