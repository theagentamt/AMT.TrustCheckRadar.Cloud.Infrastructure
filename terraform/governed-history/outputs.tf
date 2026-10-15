output "governed_history_contract" {
  value = {
    provisioned                  = var.enabled
    list_enabled                 = var.list_enabled
    detail_enabled               = var.detail_enabled
    index_ready                  = var.index_ready
    engineering_subject_count    = length(var.engineering_subjects)
    routes                       = sort([for route in aws_apigatewayv2_route.history : route.route_key])
    function_aliases             = { for name, alias in aws_lambda_alias.runtime : name => alias.arn }
    receipt_retention_seconds    = 604800
    cursor_validity_seconds      = 900
    read_only                    = true
    legacy_history_gates_changed = false
    provider_calls_enabled       = false
    hmac_key_material_in_state   = false
  }
}
