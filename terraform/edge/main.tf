data "terraform_remote_state" "api" {
  count   = var.api_mapping_enabled ? 1 : 0
  backend = "s3"

  config = {
    bucket       = var.state_bucket_name
    key          = "${var.state_key_prefix}/${var.environment}/api.tfstate"
    region       = var.state_bucket_region
    encrypt      = true
    use_lockfile = true
  }
}

data "aws_route53_zone" "api" {
  name         = var.route53_zone_name
  private_zone = false
}

locals {
  api = var.api_mapping_enabled ? data.terraform_remote_state.api[0].outputs : null

  api_stage_name = var.api_mapping_enabled ? try(local.api.api_stage_name, "$default") : null
  endpoint_paths = var.api_mapping_enabled ? try(local.api.endpoint_paths, {
    age_attestation        = "/v1/users/age-attestation"
    analysis               = "/analysis"
    device_registration    = "/device-registration"
    device_recovery        = "/device-recovery"
    entitlement_snapshot   = "/entitlements/snapshot"
    purchase_handoff       = "/purchase-handoff"
    web_risk_communication = "/web-risk-communication"
  }) : null

  mapping_path = var.api_mapping_key == null ? "" : "/${trimprefix(var.api_mapping_key, "/")}"
  base_url     = "https://${var.domain_name}${local.mapping_path}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "edge"
  })
}

resource "aws_acm_certificate" "api" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_route53_record" "api_domain_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.api.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_route53_record.api_domain_validation : record.fqdn]
}

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "api" {
  count = var.api_mapping_enabled ? 1 : 0

  api_id          = local.api.age_attestation_api_id
  domain_name     = aws_apigatewayv2_domain_name.api.id
  stage           = local.api_stage_name
  api_mapping_key = var.api_mapping_key
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.api.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
