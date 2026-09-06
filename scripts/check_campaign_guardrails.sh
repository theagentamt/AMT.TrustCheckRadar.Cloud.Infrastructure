#!/usr/bin/env bash
set -euo pipefail

campaign_paths=(
  terraform/campaign-data
  terraform/campaign-processing
  terraform/campaign-api
)

search_with_lines() {
  if command -v rg >/dev/null 2>&1; then
    rg --line-number "$@"
  else
    grep --recursive --line-number --extended-regexp --exclude-dir=.terraform "$@"
  fi
}

file_matches() {
  if command -v rg >/dev/null 2>&1; then
    rg --quiet "$1" "$2"
  else
    grep --extended-regexp --quiet "$1" "$2"
  fi
}

if search_with_lines \
  'resource "aws_(opensearch|nat_gateway|vpc_endpoint|sfn|dynamodb_global_table|instance|db_instance|rds_cluster|elasticache|msk|ecs_service|lambda_provisioned_concurrency_config)' \
  "${campaign_paths[@]}"; then
  echo "A prohibited fixed-cost V1 service is present in campaign Terraform." >&2
  exit 1
fi

if search_with_lines 'AWSLambdaBasicExecutionRole' \
  "${campaign_paths[@]}"; then
  echo "Campaign Lambdas must use exact logging/data resources and explicit denies." >&2
  exit 1
fi

if search_with_lines 'sourceIp|jwtSubject|integrationErrorMessage|authorizerError' \
  terraform/api/main.tf; then
  echo "The shared API access log contains a prohibited identity or error field." >&2
  exit 1
fi

for environment in dev uat prod; do
  file_matches '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/campaign-data.tfvars"
  file_matches '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/foundation.tfvars"
  file_matches '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/api.tfvars"
  file_matches '^campaign_processing_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/campaign-processing.tfvars"
  file_matches '^kill_switch_enabled[[:space:]]*=[[:space:]]*true$' \
    "environments/$environment/campaign-processing.tfvars"
  file_matches '^campaign_api_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/campaign-api.tfvars"
  file_matches '^campaign_review_api_enabled[[:space:]]*=[[:space:]]*false$' \
    "environments/$environment/campaign-api.tfvars"
done

echo "Campaign V1 infrastructure guardrails passed."
