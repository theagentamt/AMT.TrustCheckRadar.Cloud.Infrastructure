variable "deployment" {
  description = "Optional immutable closed lifecycle runtimes; no activation input."
  type = object({
    artifacts                 = map(object({ bucket = string, key = string, object_version = string, source_hash = string }))
    authority_hmac_secret_arn = string
    google_play_secret_arn    = string
    deletion_stream_arn       = string
    cognito_issuer            = string
    cognito_app_client_id     = string
  })
  default = null
  validation {
    condition = var.deployment == null ? true : try(
      var.enabled && toset(keys(var.deployment.artifacts)) == toset(["ingress", "worker", "deletion"]) &&
      length(toset([for a in values(var.deployment.artifacts) : split("/", a.key)[1]])) == 1 &&
      alltrue([for name, a in var.deployment.artifacts : a.bucket == "trustcheckradar-dev-107827791950-artifacts" && can(regex("^releases/[a-f0-9]{40}/${lookup({ ingress = "play_lifecycle_ingress", worker = "play_lifecycle_worker", deletion = "play_token_deletion" }, name, "invalid")}\\.zip$", a.key)) && length(trimspace(a.object_version)) > 0 && a.object_version != "null" && can(regex("^[A-Za-z0-9+/]{43}=$", a.source_hash))]) &&
      can(regex("^arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-[A-Za-z0-9]{6}$", var.deployment.authority_hmac_secret_arn)) &&
      can(regex("^arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/google-play-service-account-[A-Za-z0-9]{6}$", var.deployment.google_play_secret_arn)) &&
      can(regex("^arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/.+$", var.deployment.deletion_stream_arn)) &&
    var.deployment.cognito_issuer == "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ" && var.deployment.cognito_app_client_id == "5kvl9a8jo4fr1qqnci27tdabk4", false)
    error_message = "Use one immutable release of all three lifecycle artifacts and exact reviewed Dev dependencies."
  }
}
variable "pubsub_identity" {
  description = "Optional verified external push identity. Publishing a closed AWS route does not create/enable Google transport."
  type        = object({ audience = string, subscription = string, service_account_email = string, service_account_subject = string })
  default     = null
  validation {
    condition = var.pubsub_identity == null ? true : (
      var.deployment != null && var.pubsub_identity.audience == "https://api-dev.andmorethings.net/v1/notifications/google-play" &&
      var.pubsub_identity.subscription == "projects/trustcheck-radar/subscriptions/trustcheckradar-dev-play-lifecycle" &&
      var.pubsub_identity.service_account_email == "tcr-dev-play-push@trustcheck-radar.iam.gserviceaccount.com" &&
      can(regex("^[0-9]{10,30}$", var.pubsub_identity.service_account_subject))
    )
    error_message = "Use the verified dedicated Dev Google push identity and exact subscription/audience."
  }
}
variable "alert_topic_arn" {
  type    = string
  default = "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
  validation {
    condition     = var.alert_topic_arn == "arn:aws:sns:us-east-1:107827791950:trustcheckradar-dev-url-resolver-alerts"
    error_message = "Use the existing support@andmorethings.com alerts topic."
  }
}
