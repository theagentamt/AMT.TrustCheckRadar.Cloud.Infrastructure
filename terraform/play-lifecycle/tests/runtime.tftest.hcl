mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" { defaults = { account_id = "107827791950" } }
  mock_resource "aws_dynamodb_table" { defaults = { arn = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-play-tokens" } }
  mock_resource "aws_kms_key" { defaults = { arn = "arn:aws:kms:us-east-1:107827791950:key/11111111-1111-1111-1111-111111111111" } }
  mock_resource "aws_cloudwatch_log_group" { defaults = { arn = "arn:aws:logs:us-east-1:107827791950:log-group:synthetic" } }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::107827791950:role/synthetic", id = "synthetic" } }
  mock_resource "aws_lambda_function" { defaults = { version = "1" } }
}
variables {
  environment = "dev"
  enabled     = true
  deployment = {
    artifacts = {
      ingress  = { bucket = "trustcheckradar-dev-107827791950-artifacts", key = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/play_lifecycle_ingress.zip", object_version = "test", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      worker   = { bucket = "trustcheckradar-dev-107827791950-artifacts", key = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/play_lifecycle_worker.zip", object_version = "test", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
      deletion = { bucket = "trustcheckradar-dev-107827791950-artifacts", key = "releases/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/play_token_deletion.zip", object_version = "test", source_hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" }
    }
    authority_hmac_secret_arn = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/v1-authority-hmac-AbC123"
    google_play_secret_arn    = "arn:aws:secretsmanager:us-east-1:107827791950:secret:trustcheckradar/dev/google-play-service-account-AbC123"
    deletion_stream_arn       = "arn:aws:dynamodb:us-east-1:107827791950:table/trustcheckradar-dev-deletion-ledger/stream/2026-09-21T00:00:00.000"
    cognito_issuer            = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_wzN0wUSdQ"
    cognito_app_client_id     = "5kvl9a8jo4fr1qqnci27tdabk4"
  }
}
run "closed_runtimes_and_cleanup" {
  command = plan
  assert {
    condition     = length(aws_lambda_function.runtime) == 3 && alltrue([for f in aws_lambda_function.runtime : f.runtime == "python3.14" && f.architectures == tolist(["arm64"]) && f.environment[0].variables.PLAY_LIFECYCLE_ENABLED == "false" && f.environment[0].variables.PLAY_TOKEN_CLEANUP_ENABLED == "false" && f.environment[0].variables.PLAY_CHECKPOINT_POLICY_APPROVED == "false" && f.environment[0].variables.PLAY_PREPARATION_ENABLED == "false" && f.environment[0].variables.AUTHORITY_ENABLED == "false" && f.environment[0].variables.DEV_SUBJECT_ALLOWLIST_JSON == "[]"])
    error_message = "Runtime provision must not enable paid access, writes, cleanup or preparation."
  }
  assert {
    condition     = alltrue([for s in aws_scheduler_schedule.lifecycle : s.state == "DISABLED" && s.target[0].retry_policy[0].maximum_retry_attempts == 0]) && !aws_lambda_event_source_mapping.deletion[0].enabled && length(aws_apigatewayv2_api.notification) == 0
    error_message = "Candidate must not consume notifications or deletion work before qualification."
  }
  assert {
    condition     = alltrue([for f in aws_lambda_function_event_invoke_config.runtime : f.maximum_retry_attempts == 0 && f.maximum_event_age_in_seconds == 60])
    error_message = "No implicit raw notification retries/destinations may be configured."
  }
  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_role_policy.runtime["deletion"].policy).Statement : s.Effect != "Allow" || !strcontains(jsonencode(s.Action), "kms:")]) && !contains(keys(aws_lambda_function.runtime["deletion"].environment[0].variables), "GOOGLE_PLAY_SERVICE_ACCOUNT_SECRET_ARN")
    error_message = "Deletion must operate without decrypting or calling the store provider."
  }
  assert {
    condition = alltrue([for s in jsondecode(aws_iam_role_policy.runtime["deletion"].policy).Statement : s.Effect != "Deny" || !strcontains(jsonencode(s.Action), "kms:") || s.Resource == aws_kms_key.tokens[0].arn])
    error_message = "Token cryptography denial must not block Secrets Manager decryption of the required HMAC secret."
  }
  assert {
    condition     = alltrue(flatten([for p in aws_iam_role_policy.runtime : [for s in jsondecode(p.policy).Statement : s.Effect != "Allow" || !try(contains(s.Action, "dynamodb:PutItem") || contains(s.Action, "dynamodb:UpdateItem") || contains(s.Action, "dynamodb:DeleteItem"), false) || s.Condition["ForAnyValue:StringEquals"]["dynamodb:EnclosingOperation"] == ["TransactWriteItems"]]]))
    error_message = "Every write must be transactional and retain coupled state fences."
  }
  assert {
    condition     = alltrue([for p in aws_iam_role_policy.runtime : alltrue([for s in jsondecode(p.policy).Statement : s.Effect != "Allow" || !try(contains(s.Action, "dynamodb:PutItem"), false) || !contains(try(s.Condition["ForAllValues:StringLike"]["dynamodb:LeadingKeys"], s.Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"]), "PURCHASE#CONTROL")])])
    error_message = "No runtime may initialize or alter inventory controls."
  }
  assert {
    condition     = alltrue([for role in ["ingress", "worker"] : alltrue([for s in jsondecode(aws_iam_role_policy.runtime[role].policy).Statement : !contains(["TokenDataKey", "TokenDecrypt"], s.Sid) || (s.Condition.StringEquals["kms:EncryptionContext:purpose"] == "google-play-reconciliation" && s.Condition.StringEquals["kms:EncryptionContext:environment"] == "dev" && toset(s.Condition["ForAllValues:StringEquals"]["kms:EncryptionContextKeys"]) == toset(["purpose", "environment"]))])])
    error_message = "KMS must use fixed privacy-safe purpose/environment and exact key."
  }
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.runtime) == 6 && alltrue([for a in aws_cloudwatch_metric_alarm.runtime : a.alarm_actions == toset([var.alert_topic_arn])])
    error_message = "Every runtime must report native errors and throttles to existing support alerts."
  }
  assert {
    condition = alltrue([for schedule in aws_scheduler_schedule.lifecycle : schedule.schedule_expression == "rate(1 minute)"]) && aws_lambda_event_source_mapping.deletion[0].batch_size == 5
    error_message = "Cleanup continuation needs sub-five-minute cadence; stream batches must fit the handler limit."
  }
  assert {
    condition = !contains(keys(aws_cloudwatch_metric_alarm.operational), "ingress-heartbeat") && !aws_cloudwatch_metric_alarm.operational["worker-heartbeat"].actions_enabled && !aws_cloudwatch_metric_alarm.operational["deletion-heartbeat"].actions_enabled
    error_message = "Event-driven ingress has no expected heartbeat; scheduled heartbeats stay disarmed while schedules are disabled."
  }
  assert {
    condition = alltrue([for role in ["worker", "deletion"] : alltrue([for statement in jsondecode(aws_iam_role_policy.runtime[role].policy).Statement : statement.Sid != "LifecycleCheckpointWrite" || (statement.Condition["ForAllValues:StringEquals"]["dynamodb:LeadingKeys"] == ["PLAY#CONTROL"] && toset(statement.Condition["ForAllValues:StringEquals"]["dynamodb:Attributes"]) == toset(["PK", "SK", "schemaVersion", "revision", "cursor", "expiresAt", "scanStartedAtEpoch", "lastFullPassAtEpoch"]))])]) && alltrue([for statement in jsondecode(aws_iam_role_policy.runtime["ingress"].policy).Statement : !startswith(statement.Sid, "LifecycleCheckpoint")])
    error_message = "Only the cleanup worker/deletion roles may maintain the minimized lifecycle checkpoint."
  }

  assert {
    condition = alltrue([for role in ["ingress", "worker"] : alltrue([for statement in jsondecode(aws_iam_role_policy.runtime[role].policy).Statement : statement.Sid != "TokenDataKey" || (statement.Condition.StringEquals["kms:EncryptionAlgorithm"] == "SYMMETRIC_DEFAULT" && !contains(keys(statement.Condition.StringEquals), "kms:DataKeySpec"))])])
    error_message = "Data key permission must use supported KMS conditions; AES_256 is enforced by the runtime request."
  }

}
run "authenticated_notification_route" {
  command = plan
  variables {
    pubsub_identity = { audience = "https://api-dev.andmorethings.net/v1/notifications/google-play", subscription = "projects/trustcheck-radar/subscriptions/trustcheckradar-dev-play-lifecycle", service_account_email = "tcr-dev-play-push@trustcheck-radar.iam.gserviceaccount.com", service_account_subject = "123456789012345678901" }
  }
  assert {
    condition     = aws_apigatewayv2_route.notification[0].authorization_type == "JWT" && aws_apigatewayv2_authorizer.notification[0].jwt_configuration[0].issuer == "https://accounts.google.com" && aws_apigatewayv2_authorizer.notification[0].jwt_configuration[0].audience == toset([var.pubsub_identity.audience]) && aws_lambda_permission.notification[0].source_account == "107827791950" && aws_lambda_permission.notification[0].qualifier == "live"
    error_message = "Only the exact authenticated Google audience and live callback may be invoked."
  }
  assert {
    condition     = toset(keys(jsondecode(aws_apigatewayv2_stage.notification[0].access_log_settings[0].format))) == toset(["requestId", "routeKey", "status", "integrationLatency"]) && aws_apigatewayv2_stage.notification[0].default_route_settings[0].throttling_burst_limit == 4 && aws_apigatewayv2_stage.notification[0].default_route_settings[0].throttling_rate_limit == 2
    error_message = "Callback logs cannot contain payload/token/header/account data; throttle requests."
  }
}
run "reject_other_push_identity" {
  command = plan
  variables {
    pubsub_identity = { audience = "urn:other", subscription = "projects/trustcheck-radar/subscriptions/trustcheckradar-dev-play-lifecycle", service_account_email = "tcr-dev-play-push@trustcheck-radar.iam.gserviceaccount.com", service_account_subject = "123456789012345678901" }
  }
  expect_failures = [var.pubsub_identity]
}
