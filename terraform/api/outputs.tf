output "age_attestation_lambda_name" {
  description = "Age attestation Lambda function name"
  value       = aws_lambda_function.age_attestation.function_name
}

output "age_attestation_lambda_arn" {
  description = "Age attestation Lambda function ARN"
  value       = aws_lambda_function.age_attestation.arn
}

output "age_attestation_api_id" {
  description = "HTTP API ID"
  value       = aws_apigatewayv2_api.age_attestation.id
}

output "age_attestation_api_url" {
  description = "Base invoke URL for the age attestation HTTP API"
  value       = aws_apigatewayv2_stage.age_attestation.invoke_url
}

output "age_attestation_endpoint_url" {
  description = "Full POST endpoint URL for age attestation"
  value       = "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}/v1/users/age-attestation"
}

output "age_attestation_custom_domain_name" {
  description = "Custom domain name for the age attestation API"
  value       = var.custom_domain_enabled ? aws_apigatewayv2_domain_name.age_attestation[0].domain_name : null
}

output "age_attestation_custom_endpoint_url" {
  description = "Custom-domain endpoint URL for age attestation"
  value       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}/v1/users/age-attestation" : null
}

output "analysis_lambda_name" {
  description = "Conversation analysis Lambda function name"
  value       = aws_lambda_function.analysis.function_name
}

output "analysis_lambda_arn" {
  description = "Conversation analysis Lambda function ARN"
  value       = aws_lambda_function.analysis.arn
}

output "analysis_authorizer_id" {
  description = "JWT authorizer ID used by the protected analysis route"
  value       = aws_apigatewayv2_authorizer.cognito_jwt.id
}

output "analysis_route_key" {
  description = "HTTP method and path for the conversation analysis endpoint"
  value       = aws_apigatewayv2_route.analysis.route_key
}

output "analysis_http_method" {
  description = "HTTP method the mobile app should use for the conversation analysis endpoint"
  value       = "POST"
}

output "analysis_endpoint_path" {
  description = "Primary path the mobile app should call for conversation analysis"
  value       = var.analysis_primary_path
}

output "analysis_integration_timeout_ms" {
  description = "Configured API Gateway integration timeout for conversation analysis requests"
  value       = aws_apigatewayv2_integration.analysis_lambda.timeout_milliseconds
}

output "analysis_endpoint_url" {
  description = "Full execute-api URL for conversation analysis"
  value       = "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.analysis_primary_path}"
}

output "analysis_custom_endpoint_url" {
  description = "Custom-domain endpoint URL for conversation analysis"
  value       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.analysis_primary_path}" : null
}

output "analysis_lambda_log_group_name" {
  description = "CloudWatch log group for the conversation analysis Lambda"
  value       = aws_cloudwatch_log_group.analysis_lambda.name
}

output "analysis_api_log_group_name" {
  description = "CloudWatch log group for API Gateway access logs"
  value       = aws_cloudwatch_log_group.age_attestation_api.name
}

output "openai_secret_name" {
  description = "Secrets Manager secret name used by the conversation analysis Lambda"
  value       = local.openai_secret_name
}

output "openai_secret_arn" {
  description = "Secrets Manager secret ARN used by the conversation analysis Lambda"
  value       = local.effective_openai_secret_arn
}

output "google_play_secret_name" {
  description = "Secrets Manager secret name used by the purchase handoff Lambda for Google Play validation"
  value       = local.google_play_secret_name
}

output "google_play_secret_arn" {
  description = "Secrets Manager secret ARN used by the purchase handoff Lambda for Google Play validation"
  value       = local.effective_google_play_secret_arn
}

output "web_risk_secret_name" {
  description = "Secrets Manager secret name used by the Web Risk communication Lambda"
  value       = var.enable_web_risk_communication ? local.web_risk_secret_name : null
}

output "web_risk_secret_arn" {
  description = "Secrets Manager secret ARN used by the Web Risk communication Lambda"
  value       = var.enable_web_risk_communication ? local.effective_web_risk_secret_arn : null
}

output "shared_entitlement_service_settings" {
  description = "Shared entitlement-service runtime contract used by purchase handoff and analysis authorization"
  value = {
    tableName                 = local.purchase_entitlements_table_name
    usagePeriodMode           = var.entitlement_usage_period_mode
    defaultTier               = var.entitlement_default_tier
    premiumTier               = var.entitlement_premium_tier
    platform                  = "google_play"
    productId                 = var.google_play_subscription_product_id
    accessGrantingStatuses    = var.entitlement_access_granting_statuses
    nonterminalStatuses       = var.entitlement_nonterminal_statuses
    usageCounterRetentionDays = var.purchase_usage_counter_retention_days
  }
}

output "analysis_backend_settings" {
  description = "App-ready values for backend-settings.json or equivalent mobile configuration"
  value = {
    endpointUrl                       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.analysis_primary_path}" : "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.analysis_primary_path}"
    method                            = "POST"
    authorizationType                 = "CognitoJWT"
    authorizationHeader               = "Authorization: Bearer <access-token>"
    audience                          = local.cognito_app_client_id
    issuer                            = local.jwt_issuer
    timeoutMs                         = aws_apigatewayv2_integration.analysis_lambda.timeout_milliseconds
    routeKey                          = aws_apigatewayv2_route.analysis.route_key
    corsAllowOrigins                  = var.cors_allow_origins
    corsAllowHeaders                  = var.cors_allow_headers
    corsAllowMethods                  = var.cors_allow_methods
    lambdaLogGroup                    = aws_cloudwatch_log_group.analysis_lambda.name
    apiAccessLogGroup                 = aws_cloudwatch_log_group.age_attestation_api.name
    entitlementsTable                 = local.analysis_entitlements_table_name
    scanRateLimitWindowSeconds        = var.analysis_scan_rate_limit_window_seconds
    scanRateLimitMaxRequests          = var.analysis_scan_rate_limit_max_requests
    freeMonthlyScanLimit              = var.analysis_free_monthly_scan_limit
    proMonthlyScanLimit               = var.analysis_pro_monthly_scan_limit
    usageCounterRetentionDays         = var.purchase_usage_counter_retention_days
    entitlementDefaultTier            = var.entitlement_default_tier
    entitlementPremiumTier            = var.entitlement_premium_tier
    entitlementUsagePeriodMode        = var.entitlement_usage_period_mode
    entitlementPlatform               = "google_play"
    entitlementProductId              = var.google_play_subscription_product_id
    entitlementAccessGrantingStatuses = var.entitlement_access_granting_statuses
    entitlementNonterminalStatuses    = var.entitlement_nonterminal_statuses
    openAISecretArn                   = local.effective_openai_secret_arn
    openAISecretName                  = local.openai_secret_name
    abuseControlTable                 = local.analysis_abuse_control_table_name
    deviceBindingsTable               = local.device_bindings_table_name
  }
}

output "device_registration_lambda_name" {
  description = "Device registration Lambda function name"
  value       = aws_lambda_function.device_registration.function_name
}

output "device_registration_lambda_arn" {
  description = "Device registration Lambda function ARN"
  value       = aws_lambda_function.device_registration.arn
}

output "device_registration_route_key" {
  description = "HTTP method and path for the device registration endpoint"
  value       = aws_apigatewayv2_route.device_registration.route_key
}

output "device_registration_http_method" {
  description = "HTTP method the mobile app should use for the device registration endpoint"
  value       = "POST"
}

output "device_registration_endpoint_path" {
  description = "Primary path the mobile app should call for device registration"
  value       = var.device_registration_path
}

output "device_registration_integration_timeout_ms" {
  description = "Configured API Gateway integration timeout for device registration requests"
  value       = aws_apigatewayv2_integration.device_registration_lambda.timeout_milliseconds
}

output "device_registration_endpoint_url" {
  description = "Full execute-api URL for device registration"
  value       = "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.device_registration_path}"
}

output "device_registration_custom_endpoint_url" {
  description = "Custom-domain endpoint URL for device registration"
  value       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.device_registration_path}" : null
}

output "device_registration_lambda_log_group_name" {
  description = "CloudWatch log group for the device registration Lambda"
  value       = aws_cloudwatch_log_group.device_registration_lambda.name
}

output "device_registration_backend_settings" {
  description = "App-ready values for device registration integration"
  value = {
    endpointUrl           = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.device_registration_path}" : "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.device_registration_path}"
    method                = "POST"
    authorizationType     = "CognitoJWT"
    authorizationHeader   = "Authorization: Bearer <access-token>"
    audience              = local.cognito_app_client_id
    issuer                = local.jwt_issuer
    timeoutMs             = aws_apigatewayv2_integration.device_registration_lambda.timeout_milliseconds
    routeKey              = aws_apigatewayv2_route.device_registration.route_key
    deviceBindingsTable   = local.device_bindings_table_name
    inactiveRetentionDays = var.device_bindings_inactive_retention_days
    lambdaLogGroup        = aws_cloudwatch_log_group.device_registration_lambda.name
    apiAccessLogGroup     = aws_cloudwatch_log_group.age_attestation_api.name
  }
}

output "device_recovery_lambda_name" {
  description = "Device recovery Lambda function name"
  value       = var.enable_device_recovery ? aws_lambda_function.device_recovery[0].function_name : null
}

output "device_recovery_lambda_arn" {
  description = "Device recovery Lambda function ARN"
  value       = var.enable_device_recovery ? aws_lambda_function.device_recovery[0].arn : null
}

output "device_recovery_route_key" {
  description = "HTTP method and path for the device recovery endpoint"
  value       = var.enable_device_recovery ? aws_apigatewayv2_route.device_recovery[0].route_key : null
}

output "device_recovery_http_method" {
  description = "HTTP method the mobile app should use for the device recovery endpoint"
  value       = "POST"
}

output "device_recovery_endpoint_path" {
  description = "Primary path the mobile app should call for device recovery"
  value       = var.device_recovery_path
}

output "device_recovery_integration_timeout_ms" {
  description = "Configured API Gateway integration timeout for device recovery requests"
  value       = var.enable_device_recovery ? aws_apigatewayv2_integration.device_recovery_lambda[0].timeout_milliseconds : null
}

output "device_recovery_endpoint_url" {
  description = "Full execute-api URL for device recovery"
  value       = "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.device_recovery_path}"
}

output "device_recovery_custom_endpoint_url" {
  description = "Custom-domain endpoint URL for device recovery"
  value       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.device_recovery_path}" : null
}

output "device_recovery_lambda_log_group_name" {
  description = "CloudWatch log group for the device recovery Lambda"
  value       = var.enable_device_recovery ? aws_cloudwatch_log_group.device_recovery_lambda[0].name : null
}

output "device_recovery_backend_settings" {
  description = "App-ready values for device recovery integration"
  value = var.enable_device_recovery ? {
    endpointUrl           = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.device_recovery_path}" : "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.device_recovery_path}"
    method                = "POST"
    authorizationType     = "CognitoJWT"
    authorizationHeader   = "Authorization: Bearer <access-token>"
    audience              = local.cognito_app_client_id
    issuer                = local.jwt_issuer
    timeoutMs             = aws_apigatewayv2_integration.device_recovery_lambda[0].timeout_milliseconds
    routeKey              = aws_apigatewayv2_route.device_recovery[0].route_key
    deviceBindingsTable   = local.device_bindings_table_name
    inactiveRetentionDays = var.device_bindings_inactive_retention_days
    lambdaLogGroup        = aws_cloudwatch_log_group.device_recovery_lambda[0].name
    apiAccessLogGroup     = aws_cloudwatch_log_group.age_attestation_api.name
  } : null
}

output "entitlement_snapshot_lambda_name" {
  description = "Entitlement snapshot Lambda function name"
  value       = aws_lambda_function.entitlement_snapshot.function_name
}

output "entitlement_snapshot_lambda_arn" {
  description = "Entitlement snapshot Lambda function ARN"
  value       = aws_lambda_function.entitlement_snapshot.arn
}

output "entitlement_snapshot_route_key" {
  description = "HTTP method and path for the entitlement snapshot endpoint"
  value       = aws_apigatewayv2_route.entitlement_snapshot.route_key
}

output "entitlement_snapshot_http_method" {
  description = "HTTP method the mobile app should use for the entitlement snapshot endpoint"
  value       = "GET"
}

output "entitlement_snapshot_endpoint_path" {
  description = "Primary path the mobile app should call for entitlement snapshot refresh"
  value       = var.entitlement_snapshot_path
}

output "entitlement_snapshot_integration_timeout_ms" {
  description = "Configured API Gateway integration timeout for entitlement snapshot requests"
  value       = aws_apigatewayv2_integration.entitlement_snapshot_lambda.timeout_milliseconds
}

output "entitlement_snapshot_endpoint_url" {
  description = "Full execute-api URL for entitlement snapshot refresh"
  value       = "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.entitlement_snapshot_path}"
}

output "entitlement_snapshot_custom_endpoint_url" {
  description = "Custom-domain endpoint URL for entitlement snapshot refresh"
  value       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.entitlement_snapshot_path}" : null
}

output "entitlement_snapshot_lambda_log_group_name" {
  description = "CloudWatch log group for the entitlement snapshot Lambda"
  value       = aws_cloudwatch_log_group.entitlement_snapshot_lambda.name
}

output "entitlement_snapshot_backend_settings" {
  description = "App-ready values for entitlement snapshot refresh integration"
  value = {
    endpointUrl                       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.entitlement_snapshot_path}" : "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.entitlement_snapshot_path}"
    method                            = "GET"
    authorizationType                 = "CognitoJWT"
    authorizationHeader               = "Authorization: Bearer <access-token>"
    audience                          = local.cognito_app_client_id
    issuer                            = local.jwt_issuer
    timeoutMs                         = aws_apigatewayv2_integration.entitlement_snapshot_lambda.timeout_milliseconds
    routeKey                          = aws_apigatewayv2_route.entitlement_snapshot.route_key
    entitlementsTable                 = local.purchase_entitlements_table_name
    usageCounterRetentionDays         = var.purchase_usage_counter_retention_days
    freeMonthlyScanLimit              = var.analysis_free_monthly_scan_limit
    proMonthlyScanLimit               = var.analysis_pro_monthly_scan_limit
    entitlementDefaultTier            = var.entitlement_default_tier
    entitlementPremiumTier            = var.entitlement_premium_tier
    entitlementUsagePeriodMode        = var.entitlement_usage_period_mode
    entitlementPlatform               = "google_play"
    entitlementProductId              = var.google_play_subscription_product_id
    entitlementAccessGrantingStatuses = var.entitlement_access_granting_statuses
    entitlementNonterminalStatuses    = var.entitlement_nonterminal_statuses
    lambdaLogGroup                    = aws_cloudwatch_log_group.entitlement_snapshot_lambda.name
    apiAccessLogGroup                 = aws_cloudwatch_log_group.age_attestation_api.name
  }
}

output "purchase_handoff_lambda_name" {
  description = "Purchase handoff Lambda function name"
  value       = aws_lambda_function.purchase_handoff.function_name
}

output "purchase_handoff_lambda_arn" {
  description = "Purchase handoff Lambda function ARN"
  value       = aws_lambda_function.purchase_handoff.arn
}

output "purchase_handoff_route_key" {
  description = "HTTP method and path for the purchase handoff endpoint"
  value       = aws_apigatewayv2_route.purchase_handoff.route_key
}

output "purchase_handoff_http_method" {
  description = "HTTP method the mobile app should use for the purchase handoff endpoint"
  value       = "POST"
}

output "purchase_handoff_endpoint_path" {
  description = "Primary path the mobile app should call for purchase handoff"
  value       = var.purchase_handoff_path
}

output "purchase_handoff_integration_timeout_ms" {
  description = "Configured API Gateway integration timeout for purchase handoff requests"
  value       = aws_apigatewayv2_integration.purchase_handoff_lambda.timeout_milliseconds
}

output "purchase_handoff_endpoint_url" {
  description = "Full execute-api URL for purchase handoff"
  value       = "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.purchase_handoff_path}"
}

output "purchase_handoff_custom_endpoint_url" {
  description = "Custom-domain endpoint URL for purchase handoff"
  value       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.purchase_handoff_path}" : null
}

output "purchase_handoff_lambda_log_group_name" {
  description = "CloudWatch log group for the purchase handoff Lambda"
  value       = aws_cloudwatch_log_group.purchase_handoff_lambda.name
}

output "purchase_handoff_backend_settings" {
  description = "App-ready values for purchase handoff integration"
  value = {
    endpointUrl                       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.purchase_handoff_path}" : "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.purchase_handoff_path}"
    method                            = "POST"
    authorizationType                 = "CognitoJWT"
    authorizationHeader               = "Authorization: Bearer <access-token>"
    audience                          = local.cognito_app_client_id
    issuer                            = local.jwt_issuer
    timeoutMs                         = aws_apigatewayv2_integration.purchase_handoff_lambda.timeout_milliseconds
    routeKey                          = aws_apigatewayv2_route.purchase_handoff.route_key
    purchaseVerificationMode          = var.purchase_verification_mode
    purchaseEntitlementsTable         = local.purchase_entitlements_table_name
    entitlementsTableName             = local.purchase_entitlements_table_name
    usageCounterRetentionDays         = var.purchase_usage_counter_retention_days
    entitlementDefaultTier            = var.entitlement_default_tier
    entitlementPremiumTier            = var.entitlement_premium_tier
    entitlementUsagePeriodMode        = var.entitlement_usage_period_mode
    entitlementPlatform               = "google_play"
    entitlementProductId              = var.google_play_subscription_product_id
    entitlementAccessGrantingStatuses = var.entitlement_access_granting_statuses
    entitlementNonterminalStatuses    = var.entitlement_nonterminal_statuses
    googlePlaySecretArn               = local.effective_google_play_secret_arn
    googlePlaySecretName              = local.google_play_secret_name
    googlePlayPackageName             = var.google_play_package_name
    googlePlaySubscriptionProduct     = var.google_play_subscription_product_id
    googlePlayProProductId            = var.google_play_subscription_product_id
    lambdaLogGroup                    = aws_cloudwatch_log_group.purchase_handoff_lambda.name
    apiAccessLogGroup                 = aws_cloudwatch_log_group.age_attestation_api.name
  }
}

output "web_risk_communication_lambda_name" {
  description = "Web Risk communication Lambda function name"
  value       = var.enable_web_risk_communication ? aws_lambda_function.web_risk_communication[0].function_name : null
}

output "web_risk_communication_lambda_arn" {
  description = "Web Risk communication Lambda function ARN"
  value       = var.enable_web_risk_communication ? aws_lambda_function.web_risk_communication[0].arn : null
}

output "web_risk_communication_route_key" {
  description = "HTTP method and path for the Web Risk communication endpoint"
  value       = var.enable_web_risk_communication ? aws_apigatewayv2_route.web_risk_communication[0].route_key : null
}

output "web_risk_communication_http_method" {
  description = "HTTP method the client should use for the Web Risk communication endpoint"
  value       = "POST"
}

output "web_risk_communication_endpoint_path" {
  description = "Primary path the client should call for Web Risk communication"
  value       = var.web_risk_communication_path
}

output "web_risk_communication_integration_timeout_ms" {
  description = "Configured API Gateway integration timeout for Web Risk communication requests"
  value       = var.enable_web_risk_communication ? aws_apigatewayv2_integration.web_risk_communication_lambda[0].timeout_milliseconds : null
}

output "web_risk_communication_endpoint_url" {
  description = "Full execute-api URL for Web Risk communication"
  value       = "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.web_risk_communication_path}"
}

output "web_risk_communication_custom_endpoint_url" {
  description = "Custom-domain endpoint URL for Web Risk communication"
  value       = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.web_risk_communication_path}" : null
}

output "web_risk_communication_lambda_log_group_name" {
  description = "CloudWatch log group for the Web Risk communication Lambda"
  value       = var.enable_web_risk_communication ? aws_cloudwatch_log_group.web_risk_communication_lambda[0].name : null
}

output "web_risk_communication_backend_settings" {
  description = "App-ready values for Web Risk communication integration"
  value = var.enable_web_risk_communication ? {
    endpointUrl         = var.custom_domain_enabled ? "https://${var.api_domain_name}/${var.api_mapping_key}${var.web_risk_communication_path}" : "${trimsuffix(aws_apigatewayv2_stage.age_attestation.invoke_url, "/")}${var.web_risk_communication_path}"
    method              = "POST"
    authorizationType   = "CognitoJWT"
    authorizationHeader = "Authorization: Bearer <access-token>"
    audience            = local.cognito_app_client_id
    issuer              = local.jwt_issuer
    timeoutMs           = var.enable_web_risk_communication ? aws_apigatewayv2_integration.web_risk_communication_lambda[0].timeout_milliseconds : null
    routeKey            = var.enable_web_risk_communication ? aws_apigatewayv2_route.web_risk_communication[0].route_key : null
    webRiskTable        = local.web_risk_cache_table_name
    webRiskSecretName   = local.web_risk_secret_name
    lambdaLogGroup      = var.enable_web_risk_communication ? aws_cloudwatch_log_group.web_risk_communication_lambda[0].name : null
    apiAccessLogGroup   = aws_cloudwatch_log_group.age_attestation_api.name
  } : null
}
