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
      key            = "releases/8700d234e17ac9155bf6566f9ddcbd5bc8341146/url_consumer.zip"
      object_version = "NqgnQE5VK2xa0iNnuRRmClg_8.SqScFP"
      source_hash    = "tWl/GeNA83Y3Eao+VnPXtadZXiVQd2QNgChqjB41eAg="
    },
    recovery = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/8700d234e17ac9155bf6566f9ddcbd5bc8341146/url_lease_recovery.zip"
      object_version = "WOSUu3I1AW2wSLSW8dF3E4k4WORd.0zM"
      source_hash    = "rmopw7xe3v6zvuYXWmAyVOonGoHFaSop5gtk8OdPs/U="
    },
    entitlements = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/8700d234e17ac9155bf6566f9ddcbd5bc8341146/v1_entitlements.zip"
      object_version = "YIerN78WKpg.sBNczBskLJhejmxuKSrB"
      source_hash    = "slCLqK11rLK2z2ofSCsMCTDIZJi6Ixjhl3prfCp4xZQ="
    },
    deletion = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/8700d234e17ac9155bf6566f9ddcbd5bc8341146/v1_authority_deletion.zip"
      object_version = "QtSEjX7n_uYWVPolacMHcH1YnDZdjkEZ"
      source_hash    = "Xm1fz2QyyF/cnagXYuFEteSSGUc4Zf/CqVAEV/UuK+I="
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
