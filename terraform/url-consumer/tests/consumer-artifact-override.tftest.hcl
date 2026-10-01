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

run "null_preserves_all_artifacts" {
  command = plan
  variables {

  }
  assert {
    condition     = alltrue([for k, a in var.deployment.artifacts : aws_lambda_function.runtime[k].s3_key == a.key && aws_lambda_function.runtime[k].s3_object_version == a.object_version && aws_lambda_function.runtime[k].source_code_hash == a.source_hash && aws_lambda_function.runtime[k].s3_bucket == a.bucket])
    error_message = "Consumer correction must preserve independent package pins and activation boundaries."
  }
}

run "consumer_only_keeps_workers_and_gates" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  assert {
    condition     = alltrue([for k, a in var.deployment.artifacts : aws_lambda_function.runtime[k].s3_key == a.key && aws_lambda_function.runtime[k].s3_object_version == a.object_version && aws_lambda_function.runtime[k].source_code_hash == a.source_hash && aws_lambda_function.runtime[k].s3_bucket == a.bucket if k != "consumer"])
    error_message = "Consumer correction must preserve independent package pins and activation boundaries."
  }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].s3_key == var.consumer_artifact_override.artifact.key && aws_lambda_function.runtime["consumer"].s3_object_version == var.consumer_artifact_override.artifact.object_version && aws_lambda_function.runtime["consumer"].source_code_hash == var.consumer_artifact_override.artifact.source_hash
    error_message = "Consumer correction must preserve independent package pins and activation boundaries."
  }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].environment[0].variables.CONSUMER_ENABLED == "false" && aws_lambda_function.runtime["consumer"].environment[0].variables.AUTHORITY_ENABLED == "false"
    error_message = "Consumer correction must preserve independent package pins and activation boundaries."
  }
  assert {
    condition     = aws_lambda_function.runtime["deletion"].environment[0].variables.V1_AUTHORITY_DELETION_ENABLED == "false"
    error_message = "Consumer correction must preserve independent package pins and activation boundaries."
  }
}

run "coexists_with_deletion_correction" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
    deletion_artifact_override = { "source_sha" : "cccccccccccccccccccccccccccccccccccccccc", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "provenance_reference" : "docs/evidence/sec332-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/cccccccccccccccccccccccccccccccccccccccc/v1_authority_deletion.zip", "object_version" : "deletion-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  assert {
    condition     = alltrue([for k, a in var.deployment.artifacts : aws_lambda_function.runtime[k].s3_key == a.key && aws_lambda_function.runtime[k].s3_object_version == a.object_version && aws_lambda_function.runtime[k].source_code_hash == a.source_hash && aws_lambda_function.runtime[k].s3_bucket == a.bucket if !contains(["consumer", "deletion"], k)])
    error_message = "Consumer correction must preserve independent package pins and activation boundaries."
  }
  assert {
    condition     = aws_lambda_function.runtime["consumer"].s3_key == var.consumer_artifact_override.artifact.key && aws_lambda_function.runtime["deletion"].s3_key == var.deletion_artifact_override.artifact.key
    error_message = "Consumer correction must preserve independent package pins and activation boundaries."
  }
  assert {
    condition     = aws_lambda_function.runtime["deletion"].s3_object_version == var.deletion_artifact_override.artifact.object_version && aws_lambda_function.runtime["deletion"].source_code_hash == var.deletion_artifact_override.artifact.source_hash
    error_message = "Consumer correction must preserve independent package pins and activation boundaries."
  }
}

run "reject_stale_hash" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_stale_source" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "cccccccccccccccccccccccccccccccccccccccc", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_stale_version" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "old-version", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_same_source" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_no_provenance" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_traversal_provenance" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/../other.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_other_bucket" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "other-bucket", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_other_function" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/v1_entitlements.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_no_version" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_null_version" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "null", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_bad_hash" {
  command = plan
  variables {
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "bad" } }
  }

  expect_failures = [var.consumer_artifact_override]
}

run "reject_without_enabled_dev" {
  command = plan
  variables {
    enabled                    = false
    deployment                 = null
    environment                = "uat"
    consumer_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d", "baseline_source_hash" : "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM=", "baseline_object_version" : "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi", "provenance_reference" : "docs/evidence/sec233-synthetic.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/url_consumer.zip", "object_version" : "consumer-patch-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }

  expect_failures = [var.consumer_artifact_override]
}
