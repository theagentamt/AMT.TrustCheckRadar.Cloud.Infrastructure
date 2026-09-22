output "candidate_contract" {
  value = {
    provisioned              = var.enabled
    play_handoff_enabled     = false
    authority_enabled        = false
    catalog_verified         = false
    general_customer_access  = false
    route_published          = false
    intended_route           = "POST /v1/purchases/google-play/verify"
    endpoint                 = null
    runtime_alias            = try(aws_lambda_alias.runtime[0].arn, null)
    credentials_managed_here = false
    retention_store_created  = false
    runtime_alarm_names      = [for alarm in aws_cloudwatch_metric_alarm.runtime : alarm.alarm_name]
  }
}
