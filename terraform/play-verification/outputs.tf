output "candidate_contract" {
  value = {
    provisioned              = var.enabled
    play_handoff_enabled     = false
    authority_enabled        = false
    catalog_verified         = var.catalog_p1m_verified
    general_customer_access  = false
    route_published          = local.route_enabled
    intended_route           = "POST /v1/purchases/google-play/verify"
    endpoint                 = local.route_enabled ? "https://${var.api_gateway.api_id}.execute-api.us-east-1.amazonaws.com/v1/purchases/google-play/verify" : null
    runtime_alias            = try(aws_lambda_alias.runtime[0].arn, null)
    credentials_managed_here = false
    retention_store_created  = false
    runtime_alarm_names      = [for alarm in aws_cloudwatch_metric_alarm.runtime : alarm.alarm_name]
  }
}
