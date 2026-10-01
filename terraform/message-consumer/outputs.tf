output "candidate_contract" {
  value = {
    provisioned               = var.enabled
    consumer_enabled          = var.activate_rules_engineering
    evaluator_enabled         = var.activate_rules_engineering
    model_enabled             = false
    ai_enabled                = false
    ai_qualified              = false
    ai_policy_version         = "message-ai-2026-09-21-v1"
    ai_policy_approval_sha256 = "d6e9fff12225540bef9ba7833cce457cca4b9c791af3b49dd8a4f1601d204349"
    consumer_routes           = sort([for route in aws_apigatewayv2_route.message : route.route_key])
    engineering_subject_count = length(var.engineering_subjects)
    provider_circuit_open     = !var.activate_rules_engineering
    policy_version            = "message-rules-2026-09-20-v1"
    authority_reused          = true
    function_aliases          = { for name, function in aws_lambda_alias.runtime : name => function.arn }
    secret_value_in_state     = false
    runtime_alarm_names       = [for alarm in aws_cloudwatch_metric_alarm.runtime : alarm.alarm_name]
    daily_reporting_ready     = false
  }
}
