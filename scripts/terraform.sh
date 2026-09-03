#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <init|plan|apply|output> <dev|staging|prod> <foundation|api|identity-workflows> [artifact-release]" >&2
  exit 2
}

[[ $# -ge 3 ]] || usage

operation=$1
environment=$2
stack=$3
artifact_release=${4:-${ARTIFACT_RELEASE:-}}

case "$operation" in
  init|plan|apply|output) ;;
  *) usage ;;
esac

case "$environment" in
  dev|staging|prod) ;;
  *) usage ;;
esac

case "$stack" in
  foundation|api|identity-workflows) ;;
  *) usage ;;
esac

: "${TF_STATE_BUCKET:?Set TF_STATE_BUCKET to the remote state S3 bucket name}"
aws_region=${AWS_REGION:-us-east-1}
state_key_prefix=${TF_STATE_KEY_PREFIX:-trustcheckradar}
stack_dir="terraform/$stack"
var_file="../../environments/$environment/$stack.tfvars"

export TF_VAR_state_bucket_name="$TF_STATE_BUCKET"
export TF_VAR_state_bucket_region="$aws_region"

if [[ "$stack" != "foundation" && ("$operation" == "plan" || "$operation" == "apply") ]]; then
  : "${artifact_release:?Pass an artifact release or set ARTIFACT_RELEASE}"
  export TF_VAR_artifact_release="$artifact_release"
fi

terraform -chdir="$stack_dir" init -reconfigure \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=$state_key_prefix/$environment/$stack.tfstate" \
  -backend-config="region=$aws_region" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"

case "$operation" in
  init)
    ;;
  plan)
    terraform -chdir="$stack_dir" plan -var-file="$var_file"
    ;;
  apply)
    terraform -chdir="$stack_dir" apply -var-file="$var_file"
    ;;
  output)
    terraform -chdir="$stack_dir" output
    ;;
esac
