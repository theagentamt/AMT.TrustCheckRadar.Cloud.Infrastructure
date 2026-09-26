# Manual Dev engineering integration; execution stays disabled outside bounded synthetic tests.
aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"
enabled      = true
tags = {
  Application = "TrustCheckRadar",
  Owner       = "AMT",
  Environment = "dev",
  ManagedBy   = "terraform",
  Stack       = "url-consumer"
}
deployment = {
  artifacts = {
    consumer = {
      "bucket" : "trustcheckradar-dev-107827791950-artifacts",
      "key" : "releases/39cce61623794a123e61d25f5248b0c081eccf4a/url_consumer.zip",
      "object_version" : "QMq0XD1xRogqUM51iPjD71XQD7liaiPw",
      "source_hash" : "Y8iJQMYB8aWOXieJBMaJLrOpBop3sLpbg09Gy+PnVbA="
    },
    recovery = {
      "bucket" : "trustcheckradar-dev-107827791950-artifacts",
      "key" : "releases/39cce61623794a123e61d25f5248b0c081eccf4a/url_lease_recovery.zip",
      "object_version" : "b7u.Gz0sGsE6Ou2DhuMcDTzBUBf4vm63",
      "source_hash" : "a5uouU5vy1ZJMuWpjQY4GUQ236d4jpRS23yTmaP5K+Y="
    },
    entitlements = {
      "bucket" : "trustcheckradar-dev-107827791950-artifacts",
      "key" : "releases/39cce61623794a123e61d25f5248b0c081eccf4a/v1_entitlements.zip",
      "object_version" : "4v213SSYD50qrijRyBRDNW54IcRTww92",
      "source_hash" : "xFuy0ylGhHpfHsJBEFZsYcxhpdish1Qx4a5UcF0ZOhM="
    },
    deletion = {
      "bucket" : "trustcheckradar-dev-107827791950-artifacts",
      "key" : "releases/39cce61623794a123e61d25f5248b0c081eccf4a/v1_authority_deletion.zip",
      "object_version" : "yG9KvplPKb.k9EYNjiFt7OQei49b7scw",
      "source_hash" : "5RxJQ2QKI098vtL5TK35SaMhwManF70SxcGEmOM7GMc="
    },
  },
  users_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users",
  devices_table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings",
  deletion_table_arn    = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger",
  authority_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements",
  assessment_alias_arn  = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live",
  cognito_issuer        = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ",
  cognito_app_client_id = "5kvl9a8jo4fr1qqnci27tdabk4"
}

# Approved retention; exact temporary subjects are supplied only by a local test override.
activate_engineering = false
engineering_subjects = []
authority_configuration = {
  operation_validity_seconds = 300
  worker_settlement_seconds  = 60
  reconciliation_seconds     = 3600
  counter_retention_seconds  = 604800
}
deletion_stream_arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-06T23:20:47.091"
api_gateway = {
  api_id        = "icuak34th9"
  execution_arn = "arn:aws:execute-api:us-east-1:107827791950:icuak34th9"
}
alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"

# Reviewed cleanup-only Dev qualification; all unrelated admission stays closed.
deletion_activation = {
  "source_sha" : "39cce61623794a123e61d25f5248b0c081eccf4a",
  "subjects" : [
    "f42804a8-60b1-706e-eac4-113371eab1ee"
  ],
  "inventory_reference" : "docs/evidence/live-account-deletion-2026-09-26/account-qualified-manifest.json",
  "runtime_reference" : "docs/evidence/live-account-deletion-2026-09-26/all-component-runtime.json",
  "permissions_reference" : "docs/evidence/live-account-deletion-2026-09-26/account-writer-binding-review.md"
}
