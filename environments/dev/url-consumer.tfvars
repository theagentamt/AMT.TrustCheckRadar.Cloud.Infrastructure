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
      key            = "releases/84733306d62dd57df883b4425fa5305db6c4a62d/url_consumer.zip"
      object_version = "o57skQWWsoZ6CkEqcI1qtqij3Ii.t5GK"
      source_hash    = "u0xSsT8LDfmkJJeAtPMsyIwcbr/cM5W2FmIFxaFJZiI="
    },
    recovery = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/84733306d62dd57df883b4425fa5305db6c4a62d/url_lease_recovery.zip"
      object_version = "MhrsmGgKFDw3vAUm9VTqezRT.4cNwzPl"
      source_hash    = "Gu82oYXs8ptlxhp9W2QWNWMdgkwEovBjcuwzqH5aVco="
    },
    entitlements = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/84733306d62dd57df883b4425fa5305db6c4a62d/v1_entitlements.zip"
      object_version = "WzTDkdEeot1taiTyc7qckb3xyjHB8L0J"
      source_hash    = "zEzEhrDWhIPPvHvFbEf3X+IE39NiqiEn7hMOeR4nJIk="
    },
    deletion = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/84733306d62dd57df883b4425fa5305db6c4a62d/v1_authority_deletion.zip"
      object_version = "nZu4trNu12gDNKaPz8PB_7.h1PNTs5RI"
      source_hash    = "vCKb8pyg4Lgp54fFVV/ackQXIhXzqMYIEwa4tEXoCzo="
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
