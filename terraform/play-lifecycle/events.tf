locals {
  schedules       = { for key, fn in local.functions : key => fn if key != "ingress" }
  ingress_enabled = var.enabled && var.deployment != null && var.pubsub_identity != null
}
resource "aws_scheduler_schedule_group" "lifecycle" {
  count = length(local.functions) > 0 ? 1 : 0
  name  = "${local.prefix}-play-lifecycle"
  tags  = var.tags
}
resource "aws_iam_role" "schedule" {
  for_each = local.schedules
  name     = "${local.prefix}-${each.value.suffix}-schedule"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Action = "sts:AssumeRole", Principal = { Service = "scheduler.amazonaws.com" },
    Condition = { StringEquals = { "aws:SourceAccount" = "107827791950" }, ArnEquals = { "aws:SourceArn" = aws_scheduler_schedule_group.lifecycle[0].arn } }
  }] })
  tags = var.tags
}
resource "aws_iam_role_policy" "schedule" {
  for_each = local.schedules
  name     = "invoke-exact-live-alias"
  role     = aws_iam_role.schedule[each.key].id
  policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_alias.runtime[each.key].arn }] })
}
resource "aws_scheduler_schedule" "lifecycle" {
  for_each            = local.schedules
  name                = "${local.prefix}-${each.value.suffix}"
  group_name          = aws_scheduler_schedule_group.lifecycle[0].name
  state               = "DISABLED"
  schedule_expression = "rate(1 minute)"
  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_lambda_alias.runtime[each.key].arn
    role_arn = aws_iam_role.schedule[each.key].arn
    input    = jsonencode({ schemaVersion = 1, operation = each.key == "worker" ? "reconcile-play-lifecycle" : "reconcile-play-token-deletion" })
    retry_policy {
      maximum_event_age_in_seconds = 60
      maximum_retry_attempts       = 0
    }
  }
}
resource "aws_lambda_event_source_mapping" "deletion" {
  count                          = length(local.functions) > 0 ? 1 : 0
  event_source_arn               = var.deployment.deletion_stream_arn
  function_name                  = aws_lambda_alias.runtime["deletion"].arn
  enabled                        = false
  starting_position              = "TRIM_HORIZON"
  batch_size                     = 5
  maximum_retry_attempts         = 2
  maximum_record_age_in_seconds  = 600
  bisect_batch_on_function_error = true
  function_response_types        = ["ReportBatchItemFailures"]
  filter_criteria {
    filter {
      pattern = jsonencode({ eventName = ["INSERT", "MODIFY"], dynamodb = { Keys = { SK = { S = ["ACCOUNT_DELETION"] } } } })
    }
  }
}
resource "aws_cloudwatch_metric_alarm" "runtime" {
  for_each            = { for pair in setproduct(keys(local.functions), ["Errors", "Throttles"]) : "${pair[0]}-${lower(pair[1])}" => { function = pair[0], metric = pair[1] } }
  alarm_name          = "${local.prefix}-${local.functions[each.value.function].suffix}-${lower(each.value.metric)}"
  namespace           = "AWS/Lambda"
  metric_name         = each.value.metric
  dimensions          = { FunctionName = aws_lambda_function.runtime[each.value.function].function_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]
  tags                = var.tags
}
# Dedicated HTTP API isolates callback authentication/throttles from mobile routes.
resource "aws_apigatewayv2_api" "notification" {
  count         = local.ingress_enabled ? 1 : 0
  name          = "${local.prefix}-play-notifications"
  protocol_type = "HTTP"
  tags          = var.tags
}
resource "aws_cloudwatch_log_group" "notification_access" {
  count             = local.ingress_enabled ? 1 : 0
  name              = "/aws/apigateway/${local.prefix}-play-notifications"
  retention_in_days = 14
  tags              = var.tags
}
resource "aws_apigatewayv2_stage" "notification" {
  count       = local.ingress_enabled ? 1 : 0
  api_id      = aws_apigatewayv2_api.notification[0].id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit   = 4
    throttling_rate_limit    = 2
    detailed_metrics_enabled = true
  }
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.notification_access[0].arn
    format          = jsonencode({ requestId = "$context.requestId", routeKey = "$context.routeKey", status = "$context.status", integrationLatency = "$context.integrationLatency" })
  }
  tags = var.tags
}
resource "aws_apigatewayv2_authorizer" "notification" {
  count            = local.ingress_enabled ? 1 : 0
  api_id           = aws_apigatewayv2_api.notification[0].id
  name             = "google-push"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {
    audience = [var.pubsub_identity.audience]
    issuer   = "https://accounts.google.com"
  }
}
resource "aws_apigatewayv2_integration" "notification" {
  count                  = local.ingress_enabled ? 1 : 0
  api_id                 = aws_apigatewayv2_api.notification[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_alias.runtime["ingress"].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}
resource "aws_apigatewayv2_route" "notification" {
  count              = local.ingress_enabled ? 1 : 0
  api_id             = aws_apigatewayv2_api.notification[0].id
  route_key          = "POST /v1/notifications/google-play"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.notification[0].id
  target             = "integrations/${aws_apigatewayv2_integration.notification[0].id}"
}
resource "aws_lambda_permission" "notification" {
  count          = local.ingress_enabled ? 1 : 0
  statement_id   = "ExactGoogleNotificationRoute"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.runtime["ingress"].function_name
  qualifier      = aws_lambda_alias.runtime["ingress"].name
  principal      = "apigateway.amazonaws.com"
  source_account = "107827791950"
  source_arn     = "${aws_apigatewayv2_api.notification[0].execution_arn}/$default/POST/v1/notifications/google-play"
}
