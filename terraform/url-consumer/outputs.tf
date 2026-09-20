output "candidate_contract" {
  value = {
    provisioned           = var.enabled
    consumer_enabled      = false
    recovery_enabled      = false
    consumer_endpoint     = null
    policy_version        = "owner-2026-09-20-v1"
    hmac_secret_arn       = try(aws_secretsmanager_secret.authority_hmac[0].arn, null)
    function_aliases      = { for name, function in aws_lambda_alias.runtime : name => function.arn }
    secret_value_in_state = false
  }
}
