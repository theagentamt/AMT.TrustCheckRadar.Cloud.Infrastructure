# Manual Dev provisioning only; runtime gates remain hard-disabled.
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
      bucket         = "trustcheckradar-dev-107827791950-artifacts",
      key            = "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/url_consumer.zip",
      object_version = "4yLr6n1mPs5GiOqQ4oHsuSd.rtgygOfi",
      source_hash    = "b8RoIWI0g8sN/309zOAW4Em2ZxT80jCUJVEzNxZ8efM="
    },
    recovery = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts",
      key            = "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/url_lease_recovery.zip",
      object_version = "tkwzppvVK_nMdKHgxzFw6DeYsVu3E8X8",
      source_hash    = "W1nhRs6tjdVEYhreS0NwSSh2ZwNlAzdkw52vGOzWrtE="
    },
    entitlements = {
      bucket         = "trustcheckradar-dev-107827791950-artifacts",
      key            = "releases/44bdf31bdeb150b13c2cc3732421acbdc5b7bf1d/v1_entitlements.zip",
      object_version = "gR1q8yYMmdsD9.tEZpi8XBwkRLouvsgK",
      source_hash    = "aIRFixV+H/phUTWYWWQrsz6ruzMaNkptStthsvN5U/8="
    }
  },
  users_table_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users",
  devices_table_arn     = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings",
  deletion_table_arn    = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger",
  authority_table_arn   = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements",
  assessment_alias_arn  = "arn:aws:lambda:us-east-1:107827791950:function:trustcheckradar-dev-url-assessment:live",
  cognito_issuer        = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ",
  cognito_app_client_id = "5kvl9a8jo4fr1qqnci27tdabk4"
}
