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
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/28b4da19f321e6dc98ce2fc8b4e71632451b4362/url_consumer.zip"
      object_version = "xVQqzGgyqoGBisfRfRZWiEyyTfHflnKg"
      source_hash    = "sqegscbAtUFrWUForrB2v+wpJ7IsnyxmpjEabb/0ZRI="
    },
    recovery = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/28b4da19f321e6dc98ce2fc8b4e71632451b4362/url_lease_recovery.zip"
      object_version = "ibnXKj0vHg38E6kKr6JKXHYW3aI76df4"
      source_hash    = "ofu2Qeq8ZpPxlSiKo1eBDTLTSpq5b78SSOBlhXvBtAA="
    },
    entitlements = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/28b4da19f321e6dc98ce2fc8b4e71632451b4362/v1_entitlements.zip"
      object_version = "iz7t7.FQr.z0a.pjA9_p4hgqq7cRr71S"
      source_hash    = "3B9co1bUw2EBnhK4943dPTvxVgBXvowNY2LymfoNHr4="
    },
    deletion = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/28b4da19f321e6dc98ce2fc8b4e71632451b4362/v1_authority_deletion.zip"
      object_version = "h15XlWwddxXStuY6t.xIFr4zWqksuaqH"
      source_hash    = "YvEH0qhhvMSO4MCdj4J0fsV9sL5Zg+VTm3VozIDzzC0="
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
