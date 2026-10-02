aws_region   = "us-east-1"
project_name = "trustcheckradar"
environment  = "dev"
enabled      = true

tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  Environment = "dev"
  ManagedBy   = "terraform"
  Stack       = "message-consumer"
}

# Install the reviewed immutable artifacts and authenticated routes. Runtime
# execution remains disabled until a separate bounded engineering activation.
deployment = {
  artifacts = {
    consumer = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/662fbf47e9e392468b6d24ff7dc69206fb09a864/message_consumer.zip"
      object_version = "gJfrIspOD0M7Ud.MiRROm9199iA4EbK5"
      source_hash    = "+tXpXkRzFMuubI1uVG+kIVe6djVRbySZa7i4BAX1Jd8="
    }
    evaluator = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/662fbf47e9e392468b6d24ff7dc69206fb09a864/message_evaluator.zip"
      object_version = "RTX2jkRXzUn88svNyvnzM4ksz7WOAJE9"
      source_hash    = "ivz7yHpaTI6Kk91zfI7ujfSK2u6BWRT0iWOU7oUZeo8="
    }
  }
  users_table_arn           = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users"
  devices_table_arn         = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings"
  deletion_table_arn        = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger"
  authority_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
  authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-C7v1hG"
  assessment_alias_arn      = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live"
  cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ"
  cognito_app_client_id     = "5kvl9a8jo4fr1qqnci27tdabk4"
}

engineering_subjects = []

authority_configuration = {
  operation_validity_seconds = 300
  worker_settlement_seconds  = 60
  reconciliation_seconds     = 3600
  counter_retention_seconds  = 604800
}

provider_budget = {
  window_seconds          = 3600
  max_attempts_per_window = 20
  max_failures_per_window = 5
}

api_gateway = {
  api_id        = "icuak34th9"
  execution_arn = "arn:aws:execute-api:us-east-1:107827791950:icuak34th9"
  authorizer_id = "itms4b"
}

activate_rules_engineering = false
