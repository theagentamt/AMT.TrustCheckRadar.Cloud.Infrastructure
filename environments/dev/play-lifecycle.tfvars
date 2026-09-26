# Reviewed immutable closed runtime selection; all activation flags remain false.
pubsub_identity = {
  audience                = "https://api-dev.andmorethings.net/v1/notifications/google-play"
  subscription            = "projects/trustcheck-radar/subscriptions/trustcheckradar-dev-play-lifecycle"
  service_account_email   = "tcr-dev-play-push@trustcheck-radar.iam.gserviceaccount.com"
  service_account_subject = "105021781538297478987"
}

aws_region        = "us-east-1"
project_name      = "trustcheckradar"
environment       = "dev"
enabled           = true
backup_role_names = []
tags = {
  Application = "TrustCheckRadar"
  Owner       = "AMT"
  Environment = "dev"
  ManagedBy   = "terraform"
  Stack       = "play-lifecycle"
}

deployment = {
  "artifacts" : {
    "ingress" : {
      "bucket" : "trustcheckradar-dev-107827791950-artifacts",
      "key" : "releases/39cce61623794a123e61d25f5248b0c081eccf4a/play_lifecycle_ingress.zip",
      "object_version" : "en3DZOtDjduMnzOYUepN9C6LEzMj439q",
      "source_hash" : "BocXkxw6VeJSHp4Ggtmc5wlz4lxetWhXpTbz+mYtrRo="
    },
    "worker" : {
      "bucket" : "trustcheckradar-dev-107827791950-artifacts",
      "key" : "releases/39cce61623794a123e61d25f5248b0c081eccf4a/play_lifecycle_worker.zip",
      "object_version" : "J3ewLvbGRxPXES3qKGESAyqN1Y4SK4bX",
      "source_hash" : "YdZv9rHFPAYScnVhJLFh9/NZ598R3SgaeEzi7A2Xgcs="
    },
    "deletion" : {
      "bucket" : "trustcheckradar-dev-107827791950-artifacts",
      "key" : "releases/39cce61623794a123e61d25f5248b0c081eccf4a/play_token_deletion.zip",
      "object_version" : "pObvgJkqm0o5KWpFtiQ8E6tmzqGUS5MZ",
      "source_hash" : "JaMBcLtTr7glPJXjNddsVSdTH66g9kTHM7Esxc/i2hQ="
    }
  },
  "authority_hmac_secret_arn" : "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-C7v1hG",
  "google_play_secret_arn" : "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/google-play-service-account-F89Y5G",
  "deletion_stream_arn" : "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-06T23:20:47.091",
  "cognito_issuer" : "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ",
  "cognito_app_client_id" : "5kvl9a8jo4fr1qqnci27tdabk4"
}

# Reviewed cleanup-only Dev qualification; all unrelated admission stays closed.
deletion_activation = {
  "source_sha" : "39cce61623794a123e61d25f5248b0c081eccf4a",
  "subjects" : [
    "a458f4f8-0061-702a-eaf2-ba30e7cfbbf8"
  ],
  "inventory_reference" : "docs/evidence/live-account-deletion-2026-09-26/account-qualified-manifest.json",
  "runtime_reference" : "docs/evidence/live-account-deletion-2026-09-26/all-component-runtime.json",
  "permissions_reference" : "docs/evidence/live-account-deletion-2026-09-26/account-writer-binding-review.md"
}
