#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <base-url> <jwt> [expected-status]" >&2
  exit 2
fi

base_url=${1%/}
jwt=$2
expected_status=${3:-200}
response_file=$(mktemp)
trap 'rm -f "$response_file"' EXIT

status=$(curl --silent --show-error \
  --output "$response_file" \
  --write-out '%{http_code}' \
  --header "Authorization: Bearer $jwt" \
  --header 'Accept: application/json' \
  "$base_url/v1/scam-trends")

if [[ "$status" != "$expected_status" ]]; then
  echo "Expected HTTP $expected_status from the campaign trends route, received $status." >&2
  exit 1
fi

if [[ "$status" == "200" ]]; then
  jq --exit-status 'type == "object" and has("schemaVersion")' "$response_file" >/dev/null

  if jq --exit-status '
    [paths as $path
      | ($path[-1] | tostring | ascii_downcase)
      | select(. == "accountid"
          or . == "cognitosub"
          or . == "deviceid"
          or . == "ipaddress"
          or . == "requestid"
          or . == "contributortoken"
          or . == "rawtext"
          or . == "ocrtext"
          or . == "screenshot"
          or . == "embedding")]
    | length > 0
  ' "$response_file" >/dev/null; then
    echo "Campaign response contains a prohibited field name." >&2
    exit 1
  fi
fi

echo "Campaign trends smoke test passed with HTTP $status."
