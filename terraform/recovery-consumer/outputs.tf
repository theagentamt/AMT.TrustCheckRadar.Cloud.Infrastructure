output "candidate_contract" {
  value = {
    provisioned            = var.enabled
    consumer_enabled       = false
    evaluator_enabled      = false
    ai_enabled             = false
    ai_qualified           = false
    consumer_endpoint      = null
    policy_version         = "recovery-clarification-2026-09-21-v1"
    policy_approval_sha256 = "173132b8d5a16d3d5a8ccdbc7355a631f8384634945772993200a3559c89da72"
    playbook_version       = "recovery-playbook-1.0"
    authority_reused       = true
    receipt_policy         = "usage_only_no_sensitive_result"
    function_aliases       = { for name, function in aws_lambda_alias.runtime : name => function.arn }
    secret_value_in_state  = false
    runtime_alarm_names    = [for alarm in aws_cloudwatch_metric_alarm.runtime : alarm.alarm_name]
    daily_reporting_ready  = false
  }
}
