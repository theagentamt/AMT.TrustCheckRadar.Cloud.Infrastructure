mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_resource "aws_dynamodb_table" { defaults = { arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens" } }
  mock_resource "aws_kms_key" { defaults = { arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111" } }
  mock_resource "aws_cloudwatch_log_group" { defaults = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:synthetic" } }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::107827791950:role/synthetic", id = "synthetic" } }
  mock_resource "aws_lambda_function" { defaults = { version = "1" } }
}
variables {
  environment = "dev"
  enabled     = true
  deployment = {
    artifacts = {
      ingress  = { bucket = "trustcheckradar-dev-107827791950-artifacts", key = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/play_lifecycle_ingress.zip", object_version = "test", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      worker   = { bucket = "trustcheckradar-dev-107827791950-artifacts", key = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/play_lifecycle_worker.zip", object_version = "test", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      deletion = { bucket = "trustcheckradar-dev-107827791950-artifacts", key = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/play_token_deletion.zip", object_version = "test", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
    }
    authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-AbC123"
    google_play_secret_arn    = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/google-play-service-account-AbC123"
    deletion_stream_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-21T00:00:00.000"
    cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ"
    cognito_app_client_id     = "5kvl9a8jo4fr1qqnci27tdabk4"
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
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
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
    condition     = aws_lambda_function.runtime["deletion"].environment[0].variables.PLAY_TOKEN_CLEANUP_ENABLED == "false"
    error_message = "Deletion correction must retain baseline scope and siblings."
  }
}
run "refuse_stale_base_hash" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_stale_base_source" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "cccccccccccccccccccccccccccccccccccccccc", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_wrong_bucket" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "other-bucket", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_wrong_function" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/other.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_missing_version" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_null_version" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "null", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_missing_provenance" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_bad_patch_source" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "invalid", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.deletion_artifact_override]
}
run "refuse_non_dev" {
  command = plan
  variables {
    environment                = "uat"
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
  }
  expect_failures = [var.enabled]
}
run "activation_requires_effective_patch_source" {
  command = plan
  variables {
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
    deletion_activation        = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "subjects" : ["00000000-0000-4000-8000-000000000001"], "inventory_reference" : "synthetic; no approval", "runtime_reference" : "synthetic", "permissions_reference" : "synthetic" }
  }
  assert {
    condition     = aws_lambda_function.runtime["deletion"].s3_key == "releases/${var.deletion_activation.source_sha}/play_token_deletion.zip"
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
    deletion_artifact_override = { "source_sha" : "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "baseline_source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "baseline_source_hash" : "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "provenance_reference" : "docs/evidence/sec332-synthetic-test.json", "artifact" : { "bucket" : "trustcheckradar-dev-107827791950-artifacts", "key" : "releases/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb/play_token_deletion.zip", "object_version" : "patched-version", "source_hash" : "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" } }
    deletion_activation        = { "source_sha" : "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "subjects" : ["00000000-0000-4000-8000-000000000001"], "inventory_reference" : "synthetic; no approval", "runtime_reference" : "synthetic", "permissions_reference" : "synthetic" }
  }
  expect_failures = [var.deletion_activation]
}
