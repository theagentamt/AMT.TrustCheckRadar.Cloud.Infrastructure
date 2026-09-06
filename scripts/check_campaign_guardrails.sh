#!/usr/bin/env bash
set -euo pipefail

campaign_paths=(
  terraform/campaign-data
  terraform/campaign-processing
  terraform/campaign-api
)

if rg --line-number \
  'resource "aws_(opensearch|nat_gateway|vpc_endpoint|sfn|dynamodb_global_table|instance|db_instance|rds_cluster|elasticache|msk|ecs_service|lambda_provisioned_concurrency_config)' \
  "${campaign_paths[@]}"; then
  echo "A prohibited fixed-cost V1 service is present in campaign Terraform." >&2
  exit 1
fi

if rg --line-number 'AWSLambdaBasicExecutionRole' \
  "${campaign_paths[@]}"; then
  echo "Campaign Lambdas must use exact logging/data resources and explicit denies." >&2
  exit 1
fi

if rg --line-number 'sourceIp|jwtSubject|requestId|integrationErrorMessage|authorizerError' \
  terraform/api/main.tf; then
  echo "The shared API access log contains a prohibited identity or error field." >&2
  exit 1
fi

for environment in dev uat prod; do
  rg --quiet '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/campaign-data.tfvars"
  rg --quiet '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/foundation.tfvars"
  rg --quiet '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/api.tfvars"
  rg --quiet '^campaign_processing_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/campaign-processing.tfvars"
  rg --quiet '^kill_switch_enabled[[:space:]]*=[[:space:]]*true$' \
    "environments/$environment/campaign-processing.tfvars"
  rg --quiet '^campaign_api_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/campaign-api.tfvars"
  rg --quiet '^campaign_review_api_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/campaign-api.tfvars"
done

echo "Campaign V1 infrastructure guardrails passed."
