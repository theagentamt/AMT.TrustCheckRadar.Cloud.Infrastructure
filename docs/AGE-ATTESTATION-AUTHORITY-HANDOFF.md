# Adult self-attestation authority and release handoff

Status: **deployed and reconciled in Dev**. This record covers ATCR-74,
SECUR4ALL-177 and SECUR4ALL-193. UAT/Production promotion, execute-api retirement,
assembled release acceptance and physical-device acceptance remain separate.

## Dev deployment outcome

The owner-approved Dev rollout completed on 2026-09-30 in AWS account
`107827791950`, Region `us-east-1`. Identity workflows, API and foundation were
applied in that order from separately saved plans. A final API output-only
reconciliation recorded `clientWriteBoundaryFinalized: true`. Fresh plans for all
three stacks then reported no changes.

The immutable release is `atcr74-age-authority-f8f091c`. The age-attestation
artifact is S3 version `xw2._HvBtaROylLJnMTI_.s2TOa7b1O1` with Lambda SHA-256
`GIxLSZ2egFTrPr/zH9FLMPdCkoGzeW7o3UTQ37fY8sU=`. PostConfirmation is S3 version
`lgl3gBUczrha6AzRrpUYhB8bF6955rB.` with Lambda SHA-256
`hef5SOmcheAm4N9/qj5Slq4E8gPmGvudM0cwJggOVSg=`. Both functions are active on
Python 3.14 ARM64 and reported a successful last update.

Direct AWS readback confirmed the exact access-token route and scope, exact-pool
`AdminGetUser`, exact POST invoke permission, 4/2 route throttle, three healthy
alarms, 14-day logs, the confirmed `support@andmorethings.com` SNS subscription,
the unchanged PostConfirmation trigger, and the four-attribute client write list.
Both HTTP surfaces returned 401 without a token, and GET on the canonical age path
returned 404. The complete sanitized evidence is in
`docs/evidence/atcr74-age-authority-2026-09-30/deployment-readback.json`.

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
errors are `INVALID_REQUEST` (400), `AUTHENTICATION_REQUIRED` (401),
`PHONE_REGION_NOT_ALLOWED` and `PHONE_NUMBER_UNSUPPORTED` (403),
`PROFILE_NOT_FOUND` (404),
`ACCOUNT_STATE_CONFLICT` and `IDEMPOTENCY_CONFLICT` (409), `RATE_LIMITED`
(429), and `SERVICE_UNAVAILABLE` (503). The exact envelope is
`contracts/age-attestation/1.0.0-candidate.1/error-response.schema.json`.

The Lambda is the authority for adult acknowledgement and phone-region eligibility.
Android removes `custom:over_18` from Cognito signup and never derives eligibility
from a client-written adult attribute. Lambda uses `AdminGetUser` against the exact
user pool, reads the self-provided Cognito `phone_number`, parses it server-side and
accepts only a resolved region in `US,PR,VI,GU,AS,MP`. A `+1` prefix alone is
insufficient because the North American Numbering Plan includes other countries
and territories. This is region eligibility over a self-provided value. It is not
proof of phone control, identity, seat ownership or account-recovery authority.
Infrastructure supplies the exact pool ID and region allowlist; it does not replace
the Lambda's parser or eligibility checks.

Idempotency receipts remain in the existing users table at
`PK=USER#<sub>`, `SK=AGE_ATTESTATION#<operationId>`. They retain the request hash
and exact response for seven days using `expiresAt` and a fixed 604800-second TTL.
The duration is a source contract constant rather than a mutable environment
setting.

## Infrastructure boundary

When the final contract stage is selected, the foundation change updates the
existing Dev mobile app client in place. Its write allowlist becomes `email`,
`family_name`, `given_name` and `phone_number`.
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
The existing deletion-ledger `ConditionCheckItem` fence remains. Duplicate-safe
PostConfirmation additionally receives users-table `ConditionCheckItem` on
`USER#*`; its original profile `PutItem` remains transaction-only and its deletion
fence remains ledger-only. The environment uses `AGE_ATTESTATION_USER_POOL_ID`,
`AGE_ATTESTATION_ALLOWED_REGION_CODES` and `USERS_TABLE_NAME`; no `TABLE_NAME`
compatibility alias or receipt-TTL override is introduced.

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

The deployed Lambda source candidate is commit
`f8f091cbc579500d81bf55cd64752e982be184e1`; its locally reported package SHA-256
is `188c4b499d9e8054eb3ebff31fd14b30f7429281b3796ee8dd44d0dfb7d8f2c5`.
The published candidate object versions and hashes are recorded above. The same
`age_attestation_contract` object must name both exact release/object/hash pins in
the identity-workflows, API and foundation stacks. The contract-specific pins
override the older `profile_fence_deployment` packages; a selected contract can
never silently serve those older handlers. Checked-in Dev configuration now pins
the reviewed pair in all three stacks. The Lambda candidate tests the exact
contract above, including self-provided phone parsing,
non-US NANP denial, UUID and idempotency conflicts, deletion fencing, duplicate
PostConfirmation, concurrent replay and redacted logging.

Android must first publish a compatible candidate that omits `custom:over_18` from
Cognito signup and calls this contract. Do not apply the app-client restriction to
a Dev build that still sends the removed write attribute, because Cognito would
reject its signup request.

Use three separately reviewed stages. API reads the identity-workflows candidate
output, so the duplicate-safe trigger must be installed before the route can be
activated:

1. Select the exact release pair in `identity-workflows`, review and apply its saved
   plan, then read back the PostConfirmation object version/hash, Python 3.14 ARM64
   runtime, successful update, unchanged trigger ARN, and IAM. The plan must replace
   the older package with the selected duplicate-safe candidate and add only the
   scoped users-table duplicate check beside existing writer/fence permissions.
2. After identity readback, select the same release pair in `api`, then review and
   apply its saved plan. API remote state rejects a missing or different installed
   PostConfirmation candidate. The plan must select the age candidate even while
   the older profile-fence pin remains configured.
   Require only the reviewed route/scope, exact permission, IAM/env, function
   artifact, route throttle, alarms and outputs. Reject edge removal, a wildcard
   invoke grant, a second table, TTL setting changes, unrelated functions or any
   UAT/Production action.
3. After both Lambdas and the route pass direct readback, select the same release
   pair in `foundation`. Require an in-place app-client read/write update and exact
   contract output. Reject user-pool replacement, schema mutation, app-client
   replacement, PostConfirmation trigger change or unrelated drift. Apply this
   final client boundary only when the compatible Android build is ready.

Apply only saved plans reviewed against the immediately preceding state. Never
reuse a pre-identity API plan or a pre-API foundation plan. Preserve the profile
writer fence and wait for successful Lambda update status at each stage.

The repository helper provides the exact state keys and tfvars:

```sh
TF_STATE_BUCKET=<dev-state-bucket> scripts/terraform.sh plan dev identity-workflows <candidate-release>
TF_STATE_BUCKET=<dev-state-bucket> scripts/terraform.sh plan dev api <candidate-release>
TF_STATE_BUCKET=<dev-state-bucket> scripts/terraform.sh plan dev foundation
```

Planning and applying require current authorized Dev credentials. The 2026-09-30
rollout used saved plans and the direct readbacks listed in the evidence record.

## Required direct readback

Retain sanitized JSON evidence and independently compare it with the reviewed plan:

- `aws cognito-idp describe-user-pool-client` must show the exact four write
  attributes, retain the intended read attributes and preserve auth flows/token
  validity. `aws cognito-idp describe-user-pool` must show the unchanged
  PostConfirmation ARN and existing `custom:over_18` schema definition.
- `aws lambda get-function` / `get-function-configuration` for both functions must
  match their selected S3 object version/hash, Python 3.14 ARM64 runtime, handler,
  exact environment variables and successful update status. Age attestation also
  retains bounded concurrency.
- `aws iam get-policy-version` and `list-attached-role-policies` must match the
  exact DynamoDB and Cognito boundaries above. Include the new PostConfirmation
  duplicate `ConditionCheckItem` on users `USER#*`. Run simulations for allowed
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
- `terraform output -json age_attestation_post_confirmation_candidate` and
  `terraform output -json age_attestation_backend_settings` must expose the same
  release pair. After the final client step, foundation must expose that exact pair
  and `clientWriteBoundaryFinalized` must become true. Finish with fresh no-drift
  identity-workflows, API and foundation plans.

## Later Dev and release qualification

Use disposable synthetic accounts and Android emulation; physical-device cases stay
deferred under the standing repository rule. Record source commits, app build,
artifact object version/hash, infrastructure revision, output contract and sanitized
timestamps. Required cases are:

| Case | Required observation |
| --- | --- |
| Self-provided allowed-region phone and fresh adult acknowledgement | Signup completes through the restricted app client; access-token POST returns the exact candidate response; profile becomes eligible once; PostConfirmation remains healthy. Record that this does not prove phone control, identity, seat ownership or recovery authority. |
| Retry the same operation ID and body, including after a client timeout | Exact stored response returns with `replayed: true`; no duplicate state transition or extended receipt lifetime. |
| Reuse an operation ID with a changed body | `IDEMPOTENCY_CONFLICT`; existing receipt/profile remain unchanged. |
| Missing/ID token, wrong pool/client/scope, expired token or foreign subject | Route/Lambda rejects the request without eligibility disclosure or mutation. |
| Missing, malformed, non-US NANP or disallowed-region self-provided phone | Stable ineligible/profile error; no active profile or acknowledgement receipt that can authorize signup. Include at least one real non-US `+1` fixture. |
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
