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
      key            = "releases/0b0c9377e30bfc5110af0a9a4d0425916d9a0d74/message_consumer.zip"
      object_version = "PnlLzmrnMBaku8RyH_DahcbNxI_Rpzpw"
      source_hash    = "rRCVbCQrYHc8vzLTwC2BnbZup5+GVnFcYQ5Fax2fzKI="
    }
    evaluator = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts"
      key            = "releases/0b0c9377e30bfc5110af0a9a4d0425916d9a0d74/message_evaluator.zip"
      object_version = "KX9llP181KpIdiPKyHO_JSSpVj96LJR6"
      source_hash    = "b4QrkkFrndq4kmlMSO+7crginia4qqzR5dTwcJGyEyU="
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
