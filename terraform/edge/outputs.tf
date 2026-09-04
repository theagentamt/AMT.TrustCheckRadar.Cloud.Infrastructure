output "domain_name" {
  description = "Environment-specific API hostname"
  value       = aws_apigatewayv2_domain_name.api.domain_name
}

output "base_url" {
  description = "Base URL for the environment API"
  value       = var.api_mapping_enabled ? local.base_url : null
}

output "endpoint_urls" {
  description = "Custom-domain URL for every enabled API route"
  value = var.api_mapping_enabled ? {
    for name, path in local.endpoint_paths : name => path == null ? null : "${local.base_url}${path}"
  } : null
}

output "api_mapping_id" {
  description = "API Gateway custom-domain mapping identifier"
  value       = var.api_mapping_enabled ? aws_apigatewayv2_api_mapping.api[0].id : null
}

output "certificate_arn" {
  description = "ACM certificate used by the API custom domain"
  value       = aws_acm_certificate.api.arn
}

output "route53_alias_fqdn" {
  description = "Route 53 alias record for the API custom domain"
  value       = aws_route53_record.api.fqdn
}
