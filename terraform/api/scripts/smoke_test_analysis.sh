#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") --token <cognito-access-token> [--endpoint <url>] [--request-id <id>]

Runs two smoke tests against the deployed conversation analysis endpoint:
- one expected-success request
- one expected-structured-failure request

If --endpoint is omitted, the script reads analysis_endpoint_url from the current
terraform/api stack. Pass the edge stack's custom URL to test the public hostname.
EOF
}

TOKEN=""
ENDPOINT=""
REQUEST_ID="smoke-$(date +%s)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --endpoint)
      ENDPOINT="$2"
      shift 2
      ;;
    --request-id)
      REQUEST_ID="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TOKEN" ]]; then
  echo "Error: --token is required." >&2
  exit 1
fi

if [[ -z "$ENDPOINT" ]]; then
  ENDPOINT="$(terraform -chdir="$ROOT_DIR" output -raw analysis_endpoint_url)"
fi

SUCCESS_PAYLOAD="$(mktemp)"
FAILURE_PAYLOAD="$(mktemp)"
trap 'rm -f "$SUCCESS_PAYLOAD" "$FAILURE_PAYLOAD"' EXIT

cat >"$SUCCESS_PAYLOAD" <<EOF
{
  "schemaVersion": "v1",
  "requestId": "${REQUEST_ID}",
  "sourceType": "conversation",
  "localSanitizationApplied": true,
  "sanitizedText": "I feel nervous about a suspicious email and want to understand whether it is a phishing attempt.",
  "entities": [
    {
      "type": "EMAIL"
    }
  ]
}
EOF

cat >"$FAILURE_PAYLOAD" <<EOF
{
  "schemaVersion": "v999",
  "requestId": "${REQUEST_ID}-invalid",
  "sourceType": "",
  "localSanitizationApplied": false,
  "sanitizedText": "",
  "entities": []
}
EOF

echo "Endpoint: $ENDPOINT"
echo
echo "== Successful request =="
curl -sS \
  --request POST \
  --url "$ENDPOINT" \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/json" \
  --data @"$SUCCESS_PAYLOAD"
echo
echo
echo "== Structured failure request =="
curl -sS \
  --request POST \
  --url "$ENDPOINT" \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/json" \
  --data @"$FAILURE_PAYLOAD"
echo
