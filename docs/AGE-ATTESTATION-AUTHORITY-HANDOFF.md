# Adult self-attestation authority and release handoff

Status: **prepared in source; not deployed or activated**. This record covers
ATCR-74, SECUR4ALL-177 and SECUR4ALL-193. It does not authorize an AWS mutation,
UAT/Production promotion, tracker transition or release acceptance.

## Candidate contract

The cross-component contract is
`contracts/age-attestation/1.0.0-candidate.1` with `schemaVersion: 1` and
`agePolicyVersion: "v1.0"`. Android sends an authenticated `POST` to
`/v1/users/age-attestation` with a canonical UUIDv4 `operationId` and the literal
`over18Acknowledged: true`; additional properties are rejected. The request uses
a Cognito **access token** containing `sub`, `token_use=access` and the
`aws.cognito.signin.user.admin` scope. The authorizer issuer is the exact pool
issuer and the audience/client identity is the mobile app client.

The Lambda response records the same operation ID, schema and policy version,
`attestationStatus: "ACKNOWLEDGED"`, `eligibleForSignup: true`, an empty
`denialReasons` list, `attestedAt`, and whether the response was replayed. Stable
errors are `INVALID_REQUEST`, `AUTHENTICATION_REQUIRED`, `PROFILE_NOT_FOUND`,
`ACCOUNT_NOT_ELIGIBLE`, `ACCOUNT_STATE_CONFLICT`, `IDEMPOTENCY_CONFLICT`,
`RATE_LIMITED` and `SERVICE_UNAVAILABLE`.

The Lambda is the authority for adult acknowledgement and phone eligibility.
Android removes `custom:over_18` from Cognito signup and never derives eligibility
from a client-written Cognito attribute. Lambda uses `AdminGetUser` against the
exact user pool, requires the verified Cognito phone profile expected by its
candidate implementation, parses the E.164 number server-side and accepts only a
resolved region in `US,PR,VI,GU,AS,MP`. A `+1` prefix alone is insufficient because
the North American Numbering Plan includes other countries and territories.
Infrastructure supplies the exact pool ID and region allowlist; it does not replace
the Lambda's parser or eligibility checks.

Idempotency receipts remain in the existing users table at
`PK=USER#<sub>`, `SK=AGE_ATTESTATION#<operationId>`. They retain the request hash
and exact response for seven days using `expiresAt` and a fixed 604800-second TTL.
The duration is a source contract constant rather than a mutable environment
setting.

## Infrastructure boundary

The foundation change updates the existing Dev mobile app client in place. Its
write allowlist is `email`, `family_name`, `given_name` and `phone_number`.
`custom:over_18` remains readable for legacy observation but is no longer writable
by the app client. This matches Android after its coordinated signup change. The
user pool and optional mutable schema attribute remain intact, and the existing
PostConfirmation trigger must survive the update unchanged. UAT and Production
keep the legacy default until their own reviewed contract selection and explicit
promotion approval.

The API route keeps JWT authorization and adds the exact access-token scope. Its
Lambda invoke grant is limited to the same AWS account and
`*/POST/v1/users/age-attestation`. The dedicated route throttle is 4 burst / 2 per
second. The canonical Dev client URL is
`https://api-dev.andmorethings.net/v1/users/age-attestation`. The execute-api URL
remains enabled and protected by the same route/authorizer while consumers migrate;
disabling it requires separate consumer evidence and a reviewed edge change.

The Lambda role adds only `cognito-idp:AdminGetUser` on the exact pool. Users-table
reads are `GetItem` on `USER#*`; receipt/profile `PutItem` and `UpdateItem` require
`TransactWriteItems`; transaction `ConditionCheckItem` is limited to `USER#*`.
The existing deletion-ledger `ConditionCheckItem` fence remains. The environment
uses `AGE_ATTESTATION_USER_POOL_ID`, `AGE_ATTESTATION_ALLOWED_REGION_CODES` and
`USERS_TABLE_NAME`; no `TABLE_NAME` compatibility alias or receipt-TTL override is
introduced.

CloudWatch alarms cover Lambda `Errors`, Lambda `Throttles` and route-specific API
Gateway `5xx`. They use five-minute sums, alarm on any occurrence, treat missing
data as not breaching and point both alarm/recovery actions at the established Dev
resolver topic. Before activation, read back that its confirmed
`support@andmorethings.com` subscription remains present. Lambda and API access log
groups retain 14 days. Logs and alarm descriptions must never contain bearer
tokens, phone numbers or attestation payloads.

`age_attestation_backend_settings` is the machine-readable operations/Android/
Lambda handoff. It includes the canonical and execute-api URLs, method, token type,
scope, issuer, audience, route, contract/schema/policy versions, region allowlist,
receipt key/TTL contract, log groups and alarm names.

## Safe Dev plan and apply order

A published candidate `age_attestation.zip` object version and base64 SHA-256 are
still required. Pin them through the existing `profile_fence_deployment` object;
do not install a mutable release key. Confirm the Lambda candidate tests the exact
contract above, including verified-phone parsing, non-US NANP denial, UUID and
idempotency conflicts, deletion fencing, concurrent replay and redacted logging.

Android must first publish a compatible candidate that omits `custom:over_18` from
Cognito signup and calls this contract. Do not apply the app-client restriction to
a Dev build that still sends the removed write attribute, because Cognito would
reject its signup request.

Use two separately reviewed plans because API consumes foundation remote state:

1. Initialize and plan `foundation` with the Dev tfvars. Require an in-place update
   of only the app client's read/write attributes and contract output. Reject any
   user-pool replacement, schema mutation, app-client replacement, PostConfirmation
   trigger change or unrelated drift.
2. After an explicitly authorized foundation apply and direct readback, initialize
   and plan `api` with the Dev tfvars and the exact published artifact selection.
   Require only the reviewed route/scope, exact permission, IAM/env, function
   artifact, route throttle, alarms and outputs. Reject edge removal, a wildcard
   invoke grant, a second table, TTL setting changes, unrelated functions or any
   UAT/Production action.
3. Apply only the saved plans that were reviewed against the immediately preceding
   state. Do not reuse a pre-foundation API plan. Preserve the existing profile
   writer fence and wait for successful Lambda update status before connected tests.

The repository helper provides the exact state keys and tfvars:

```sh
TF_STATE_BUCKET=<dev-state-bucket> scripts/terraform.sh plan dev foundation
TF_STATE_BUCKET=<dev-state-bucket> scripts/terraform.sh plan dev api <candidate-release>
```

Planning and applying require current authorized Dev credentials. This source task
had no AWS credentials, so no plan, apply or live readback was represented as done.

## Required direct readback

Retain sanitized JSON evidence and independently compare it with the reviewed plan:

- `aws cognito-idp describe-user-pool-client` must show the exact four write
  attributes, retain the intended read attributes and preserve auth flows/token
  validity. `aws cognito-idp describe-user-pool` must show the unchanged
  PostConfirmation ARN and existing `custom:over_18` schema definition.
- `aws lambda get-function` / `get-function-configuration` must match the selected
  S3 object version/hash, Python 3.14 ARM64 runtime, handler, bounded concurrency,
  exact environment variables and successful update status.
- `aws iam get-policy-version` and `list-attached-role-policies` must match the
  exact DynamoDB and Cognito boundaries above. Run policy simulations for allowed
  exact-pool `AdminGetUser`, denied other-pool/list/update actions, transaction-only
  user mutations, denied standalone writes, denied other partitions and deletion
  ledger immutability. Mocked policy shape is not installed-role evidence.
- `aws apigatewayv2 get-routes`, `get-authorizers`, `get-stages`, `get-domain-names`
  and `get-api-mappings` must show the exact POST route/scope, pool issuer/client,
  route throttle, custom-domain mapping and retained execute-api surface.
- `aws lambda get-policy` must contain only the same-account exact POST source ARN
  for this statement. CloudWatch readback must match all three alarms, dimensions,
  actions and both 14-day log groups. Confirm the SNS subscription without sending
  a user payload.
- `terraform output -json age_attestation_backend_settings` must exactly match the
  client/Lambda handoff, followed by fresh no-drift foundation and API plans.

## Later Dev and release qualification

Use disposable synthetic accounts and Android emulation; physical-device cases stay
deferred under the standing repository rule. Record source commits, app build,
artifact object version/hash, infrastructure revision, output contract and sanitized
timestamps. Required cases are:

| Case | Required observation |
| --- | --- |
| Verified allowed-region phone and fresh adult acknowledgement | Signup completes through the restricted app client; access-token POST returns the exact candidate response; profile becomes eligible once; PostConfirmation remains healthy. |
| Retry the same operation ID and body, including after a client timeout | Exact stored response returns with `replayed: true`; no duplicate state transition or extended receipt lifetime. |
| Reuse an operation ID with a changed body | `IDEMPOTENCY_CONFLICT`; existing receipt/profile remain unchanged. |
| Missing/ID token, wrong pool/client/scope, expired token or foreign subject | Route/Lambda rejects the request without eligibility disclosure or mutation. |
| Missing, unverified, malformed, non-US NANP or disallowed-region phone | Stable ineligible/profile error; no active profile or acknowledgement receipt that can authorize signup. Include at least one real non-US `+1` fixture. |
| False/missing acknowledgement, noncanonical UUID, wrong schema/policy or extra field | `INVALID_REQUEST`; no receipt or profile mutation. |
| Concurrent identical and conflicting requests | One authoritative result; exact replays converge and conflicts never overwrite it. |
| Existing deletion tombstone or stale/pending/active profile variants | Deletion and state fences produce the documented result without resurrection or cross-account access. |
| Trigger Lambda error, throttle and API 5xx with sanitized fixtures | Correct metric/alarm transition and recovery reach the approved topic; separately confirm inbox receipt without sensitive content. |
| Canonical URL and retained execute-api URL | Both surfaces enforce the same JWT route; Android uses only the canonical URL. No unauthenticated or wrong-method invocation succeeds. |

Clean up only the disposable accounts and receipts through reviewed product/fixture
paths, then verify unrelated account baselines and no drift. Dev component evidence
does not complete the later assembled UAT/release story. UAT/Production contract
selection, execute-api retirement and physical-device evidence remain separate
reviewed work.
