output "candidate_contract" {
  value = {
    provisioned               = var.enabled
    consumer_enabled          = var.activate_engineering
    recovery_enabled          = local.authority_engineering_active
    access_enabled            = local.authority_engineering_active
    deletion_enabled          = local.authority_deletion_active
    trial_activation_enabled  = var.activate_engineering
    access_only_engineering   = var.activate_access_engineering
    consumer_endpoint         = var.api_gateway == null ? null : "https://${var.api_gateway.api_id}.execute-api.${var.aws_region}.amazonaws.com/v1/url-checks"
    general_customer_access   = false
    engineering_subject_count = length(var.engineering_subjects)
    routes                    = [for route in values(local.routes) : route.key]
    policy_version            = "owner-2026-09-20-v1"
    hmac_secret_arn           = try(aws_secretsmanager_secret.authority_hmac[0].arn, null)
    function_aliases          = { for name, function in aws_lambda_alias.runtime : name => function.arn }
    secret_value_in_state     = false
  }
}
