output "candidate_contract" {
  value = {
    provisioned           = var.enabled
    consumer_enabled      = false
    evaluator_enabled     = false
    model_enabled         = false
    consumer_endpoint     = null
    policy_version        = "message-rules-2026-09-20-v1"
    authority_reused      = true
    function_aliases      = { for name, function in aws_lambda_alias.runtime : name => function.arn }
    secret_value_in_state = false
  }
}
