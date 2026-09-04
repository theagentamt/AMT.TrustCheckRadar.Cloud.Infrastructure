#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <aws-profile> [output-directory]" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage

profile="$1"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output_dir="${2:-.local/aws-inventory/$timestamp}"
errors=0

command -v aws >/dev/null 2>&1 || {
  echo "AWS CLI is required." >&2
  exit 1
}

mkdir -p "$output_dir/global" "$output_dir/regions"
export AWS_PAGER=""

capture() {
  local destination="$1"
  shift

  if ! aws --profile "$profile" "$@" --output json >"$destination" 2>"$destination.err"; then
    errors=$((errors + 1))
    return 0
  fi

  rm -f "$destination.err"
}

echo "Verifying AWS profile '$profile'..."
if ! aws --profile "$profile" sts get-caller-identity --output json >"$output_dir/caller-identity.json"; then
  echo "Unable to use profile '$profile'. Authenticate it before retrying." >&2
  exit 1
fi

capture "$output_dir/global/organization.json" organizations describe-organization
capture "$output_dir/global/organization-accounts.json" organizations list-accounts
capture "$output_dir/global/s3-buckets.json" s3api list-buckets
capture "$output_dir/global/route53-hosted-zones.json" route53 list-hosted-zones
capture "$output_dir/global/route53-domains.json" route53domains list-domains --region us-east-1
capture "$output_dir/global/iam-oidc-providers.json" iam list-open-id-connect-providers
capture "$output_dir/global/iam-roles.json" iam list-roles
capture "$output_dir/global/savings-plans.json" savingsplans describe-savings-plans --region us-east-1

# Keep the JMESPath literal backticks intact for the AWS CLI.
# shellcheck disable=SC2016
if ! regions="$(aws --profile "$profile" ec2 describe-regions \
  --all-regions \
  --query 'Regions[?OptInStatus!=`not-opted-in`].RegionName' \
  --output text)"; then
  echo "Unable to list enabled AWS Regions." >&2
  exit 1
fi

for region in $regions; do
  region_dir="$output_dir/regions/$region"
  mkdir -p "$region_dir"

  echo "Inventorying $region..."
  capture "$region_dir/tagged-resources.json" resourcegroupstaggingapi get-resources --region "$region"
  capture "$region_dir/cloudformation-stacks.json" cloudformation describe-stacks --region "$region"
  capture "$region_dir/lambda-functions.json" lambda list-functions --region "$region"
  capture "$region_dir/dynamodb-tables.json" dynamodb list-tables --region "$region"
  capture "$region_dir/cognito-user-pools.json" cognito-idp list-user-pools --max-results 60 --region "$region"
  capture "$region_dir/api-gateway-rest-apis.json" apigateway get-rest-apis --region "$region"
  capture "$region_dir/api-gateway-v2-apis.json" apigatewayv2 get-apis --region "$region"
  capture "$region_dir/secrets.json" secretsmanager list-secrets --region "$region"
  capture "$region_dir/log-groups.json" logs describe-log-groups --region "$region"
  capture "$region_dir/acm-certificates.json" acm list-certificates --region "$region"
  capture "$region_dir/ec2-instances.json" ec2 describe-instances --region "$region"
  capture "$region_dir/ec2-reserved-instances.json" ec2 describe-reserved-instances --region "$region"
  capture "$region_dir/rds-instances.json" rds describe-db-instances --region "$region"
  capture "$region_dir/rds-reserved-instances.json" rds describe-reserved-db-instances --region "$region"
done

cat >"$output_dir/README.txt" <<EOF
Generated: $timestamp
AWS profile: $profile

This is a read-only discovery export. A missing or empty service response is not
proof that the account has no resources. Review *.err files for denied or
unsupported API calls and verify billing, Marketplace subscriptions, Route 53
domains, backups, and every enabled Region before approving destruction.
EOF

echo "Inventory written to $output_dir"
if [[ $errors -gt 0 ]]; then
  echo "$errors inventory calls could not be completed; review the .err files." >&2
fi
