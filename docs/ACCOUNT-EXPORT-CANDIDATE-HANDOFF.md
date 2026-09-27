# Protected account export infrastructure candidate

Status as of September 27: SECUR4ALL-236/245 scoped activation source work is in progress.
The existing Dev candidate and cursor container were previously deployed; the new
runtime/API selection has not yet been deployed or qualified. No general export
activation, inventory approval or secret value is introduced by this source change.

The owner approved direct authenticated observed-data export on September 21;
see [the decision record](ACCOUNT-DATA-POLICY-DECISIONS.md). Lambda owns the
canonical contract at `39cce61623794a123e61d25f5248b0c081eccf4a`, path
`contracts/account-export/1.0.0-candidate.3` (20 families, including minimized Play
verification metadata). Candidate.2 consumers need the coordinated contract update.
Android owns bounded assembly and explicit document saving. Infrastructure does
not expand the field projection or replace missing backend readers with IAM.

## Candidate inputs and boundaries

`account_export_deployment` is null by default. Selecting it requires an immutable
release ID, S3 object version, base64 SHA-256, review reference, exact existing
same-environment V1 authority HMAC secret ARN, and separate promotion approval
outside Dev. It prepares:

- A Python 3.14 ARM64 `account_export_api.zip` Lambda in the existing API root,
  with 29-second timeout, 256 MiB memory and concurrency one.
- A dedicated execution role, fourteen-day log group, and no asynchronous retry.
- An empty `trustcheckradar/<environment>/account-export-cursor` Secrets Manager
  container. Terraform stores no key material and creates no export payload store.
- Optional same-account/Region SNS alarms, only when `account_export_monitoring`
  is supplied. The topic must deliver to `support@andmorethings.com` and be verified
  during rollout; adding alarms is not proof notification delivery works.

Without `account_export_activation`, there is no export API route or invocation
permission; `ACCOUNT_EXPORT_ENABLED=false`, inventory pending and username mapping
false remain explicit. No function URL is created. The optional activation input
is Dev-only and requires one to ten canonical synthetic subjects, exact selected
export source, all current source stores/work pins, monitoring and policy,
inventory, identity and contract evidence references.

The `runtime` phase enables the guarded handler for private qualification without
an HTTP route. The `api` phase additionally requires runtime evidence and creates
only JWT/scope-protected `POST /v1/users/account-export` with rate two/burst four.
Lambda must reject signed subjects outside the supplied list before owned data
reads for both START and CONTINUE. Work quiescence overrides activation and sets
concurrency zero. Removing activation closes the runtime and removes the route.
Outputs distinguish scoped HTTP availability from general availability, which
remains false; Terraform does not attest runtime behavior.

A read-only exporter may use a separately reviewed artifact through
`account_export_work_compatibility`. Both exact source SHAs and the evidence
reference are mandatory; the writer/work source must still match the unchanged
account-data deployment. Stale overrides fail even when normal source equality
would pass. Generation, manifest, revision and table identities remain bound by
the existing work activation; no writer IAM or inventory mutation is added.

The existing foundation, optional approved recovery, deployed History and optional
campaign storage contracts supply resource identities. This creates no table,
index, archive bucket, export-control row or new retention policy. All existing
retention remains unchanged; a disabled/missing family must be resolved in the
inventory, not silently called empty by the runtime.

## Execution access

DynamoDB permits GetItem/Query only on exact environment table and partition
families for profile, devices, deletion controls, purchase/authority, legacy
analysis, History and approved recovery. Purchase coverage has a separate
GetItem-only `PURCHASE#CONTROL` grant; the handler checks the exact sort key and
verified inventory revision. Purchase tokens/internal hashes are not export fields.

Campaign source access includes owned outbox locators and event rows, exact base
pipeline rows, and Query on `ContributorPeriodIndex` under `CONTRIB#*`. Base
pipeline access is GetItem only. The runtime derives and checks actual ownership;
IAM cannot replace those checks or guarantee an eventually consistent index is
a snapshot. No campaign intelligence/other-user aggregate reads are added.

Period HMAC operations permit only GenerateMac, HMAC_SHA_256 and keys in this
account/Region tagged with the project, environment and
`Purpose=campaign-contributor-token`. This follows existing rotation conventions
without adding manually retained key copies. Separately, transient storage key
Decrypt is restricted to regional DynamoDB, the caller account, and the outbox or
pipeline table encryption context. See AWS's
[DynamoDB encryption usage notes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/encryption.usagenotes.html).
No key creation, signing, direct arbitrary decryption or encryption is granted.

Cognito AdminGetUser is scoped to the exact pool; validated subject/username
mapping remains a runtime prerequisite. There is no identity deletion permission.
Secrets Manager GetSecretValue is restricted to the two exact authority/cursor
keyrings with explicit AWSCURRENT. Object storage, SSM and role chaining are
explicitly denied. The role cannot write source tables or invoke analysis services.

## Cursor key and rollout requirements

The cursor keyring schema is `{activeKeyId, keys}`, with at most four key IDs
mapping to base64-encoded 32-byte AES keys. The Dev keyring was initialized on September 23; do not rerun initial setup on
a populated secret. For a new environment, generate cryptographic random
material and populate it outside Terraform only during a reviewed rollout;
never echo it into logs, tracker, source, plan or state. Runtime must request
VersionStage=AWSCURRENT. Rotation retains old keys through outstanding fifteen-minute
continuation expiry; a missing key must fail, never downgrade authentication.

The Lambda owns AES-GCM cursor binding, exact projections and before/after-read
account/device/deletion checks. A continuation never extends the fixed lifetime.
Limits are 64 KiB per page, 8 MiB cumulative wire data and 256 pages; they are
resource safeguards, not proof every legitimate inventory fits. Oversize accounts
must fail honestly rather than yield a truncated COMPLETE export. No subscription
or check allowance is required to retrieve one's own data.

## Monitoring

Lambda EMF namespace `AMT/TrustCheckRadar/AccountExport` emits fixed
Environment/Operation dimensions (`start`, `continue`, `unknown`). The five
optional alarms cover Lambda Errors/Throttles and handled AccountExportUnavailable
for all three operations. Page success and ordinary authentication, expiry,
conflict or size rejection remain separate counters, not system-failure alarms.
No account, token, cursor, content or exception text belongs in metrics/logs.

## Acceptance still required

The backend package and all shared dependencies must be built and checked for ARM64
Python 3.14. Source tests do not replace inventory completeness, subject mapping,
key rotation, cross-account/session/deletion races, maximum-size and legitimate
large-inventory qualification. A current saved plan with real immutable artifact
pins, verified credentials, exact alert routing and explicit activation review is
needed before a Dev rollout. UAT/production remain separately gated.

See [the pending release-test instructions](SECUR4ALL-236-RELEASE-TESTS.md) for
later assembled-system qualification. Required Dev runtime work remains in SECUR4ALL-236;
UAT/physical testing does not automatically block independently complete backend work.

## Historical local source evidence

Terraform 1.12.1 validate, all 73 API mocked tests and repository formatting/diff
checks pass. Independent review identified the legacy consumption prefix and
purchase-coverage marker access gaps; both were corrected and asserted in tests,
and the reviewer confirmed the fixes. No live export or provider calls occurred.


## September 27 scoped activation source validation

Terraform 1.12.1 passed all **167 API mock tests**, including 19 new activation
and exact reader-compatibility cases. Null rollback, runtime-only access, JWT route
and throttle, missing source prerequisites, bad scopes, stale source pairs and
quiescence are covered. Independent source review found no blocker; existing
writer and deletion protections remain intact. These are local mocked tests,
not deployed behavior. The new selection has not been applied; real Dev runtime
qualification, frozen source integration and story completion remain pending.

Later UAT execution has linked [SECUR4ALL-331](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-331),
with detailed pending instructions. It does not absorb unfinished Dev criteria.
