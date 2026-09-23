# Authenticated Dev route only; runtime gates stay closed. No credentials stored here.
aws_region           = "us-east-1"
project_name         = "trustcheckradar"
environment          = "dev"
enabled              = true
catalog_p1m_verified = true
tags = {
  "Application" : "TrustCheckRadar",
  "Owner" : "AMT",
  "Environment" : "dev",
  "ManagedBy" : "terraform",
  "Stack" : "play-verification"
}
deployment = {
  "artifact" : {
    "bucket" : "trustcheckradar-dev-107827791950-artifacts",
    "key" : "releases/28b4da19f321e6dc98ce2fc8b4e71632451b4362/v1_play_handoff.zip",
    "object_version" : "pLLnpT50xdObhmAne64pzqysd4YaTHoo",
    "source_hash" : "lCFJyf2hIG/WbhrxySRVTCxERwdnP4IWc/nAKyf7l/I="
  },
  "authority_hmac_secret_arn" : "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-C7v1hG",
  "google_play_secret_arn" : "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/google-play-service-account-F89Y5G",
  "cognito_issuer" : "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ",
  "cognito_app_client_id" : "5kvl9a8jo4fr1qqnci27tdabk4",
  "package_name" : "com.andmorethings.trustcheckradar",
  "product_id" : "trustcheck_radar_pro_monthly",
  "base_plan_id" : "pro-monthly",
  "users_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-users",
  "devices_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-device-bindings",
  "deletion_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger",
  "authority_table_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-purchase-entitlements"
}
api_gateway = {
  "api_id" : "icuak34th9",
  "execution_arn" : "arn:aws:execute-api:us-east-1:107827791950:icuak34th9",
  "stage_name" : "$default"
}
alert_topic_arn = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
