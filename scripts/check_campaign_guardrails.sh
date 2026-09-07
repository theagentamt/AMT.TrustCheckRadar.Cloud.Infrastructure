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

if search_with_lines \
  'resource "aws_ecr_|resource "aws_lambda_function" "feature"|feature_queue_(arn|url|visibility)|model_repository_(arn|url)|feature_image_digest|CAMPAIGN_FEATURE_IMAGE_DIGEST|FEATURE_IMAGE_ECR_REPOSITORY' \
  terraform/campaign-data \
  terraform/campaign-processing \
  .github/workflows/deploy.yml \
  bootstrap/access/main.tf; then
  echo "Campaign feature extraction must remain app-side; server feature runtimes and images are prohibited." >&2
  exit 1
fi

if search_with_lines 'dynamodb:TransactWriteItems' \
  "${campaign_paths[@]}" \
  terraform/api; then
  echo "DynamoDB transactions must grant the underlying item actions, not the nonexistent TransactWriteItems IAM action." >&2
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

for environment in uat prod; do
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

dev_foundation_enabled=false
dev_data_enabled=false
dev_api_data_enabled=false
dev_processing_enabled=false
dev_trends_enabled=false
dev_review_enabled=false

file_matches '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*true$' \
  environments/dev/foundation.tfvars && dev_foundation_enabled=true
file_matches '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*true$' \
  environments/dev/campaign-data.tfvars && dev_data_enabled=true
file_matches '^campaign_intelligence_enabled[[:space:]]*=[[:space:]]*true$' \
  environments/dev/api.tfvars && dev_api_data_enabled=true
file_matches '^campaign_processing_enabled[[:space:]]*=[[:space:]]*true$' \
  environments/dev/campaign-processing.tfvars && dev_processing_enabled=true
file_matches '^campaign_api_enabled[[:space:]]*=[[:space:]]*true$' \
  environments/dev/campaign-api.tfvars && dev_trends_enabled=true
file_matches '^campaign_review_api_enabled[[:space:]]*=[[:space:]]*true$' \
  environments/dev/campaign-api.tfvars && dev_review_enabled=true

[[ "$dev_foundation_enabled" == "$dev_data_enabled" ]] || {
  echo "Dev foundation and campaign-data activation flags must agree." >&2
  exit 1
}

if [[ "$dev_processing_enabled" == true ]]; then
  [[ "$dev_data_enabled" == true && "$dev_api_data_enabled" == true ]] || {
    echo "Dev processing requires the foundation, campaign data, and source API integration." >&2
    exit 1
  }
fi

if [[ "$dev_trends_enabled" == true || "$dev_review_enabled" == true ]]; then
  [[ "$dev_data_enabled" == true ]] || {
    echo "Dev campaign APIs require the campaign data plane." >&2
    exit 1
  }
fi

file_matches '^kill_switch_enabled[[:space:]]*=[[:space:]]*true$' \
  environments/dev/campaign-processing.tfvars

echo "Campaign V1 infrastructure guardrails passed."
