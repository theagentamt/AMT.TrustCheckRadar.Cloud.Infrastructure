# Consumer device recovery development

Status: local development only; not deployed or approved for mobile use.
Related consumers: iOS ITCR-59 and Android ATCR-75.

## Scope and ownership

The owner requested backend development through the iOS task on 2026-09-17.
Infrastructure owns Terraform, release coordination and evidence. The existing
Lambda task owns handler changes, versioned contracts, fixtures and application
tests. No duplicate task or direct edits to the Lambda/mobile repositories are
part of infrastructure work. YouTrack writes remain restricted.

Preserve automatic switching during normal `POST /device-registration`.
Separate consumer recovery controls are not a global switching policy. See
[the owner decision](ACCOUNT-DATA-POLICY-DECISIONS.md#normal-registration-switching-decision-2026-09-17).

## Infrastructure implementation

- Add `device_self_recovery_acceptance`, default null. Activation now requires
  explicit approval tied to the exact coordinated writer/reader release, a
  semantic contract version, lowercase SHA-256 contract-manifest digest, and
  owner/security evidence references. Terraform validates the metadata and
  release match, not the content or truth of referenced acceptance evidence.
- Continue requiring approved same-account/environment recovery storage and
  immutable recovery, registration, History read/mutation and analysis packages.
- Keep consumer activation false by default. Generic Lambda environment inputs
  cannot activate the route or weaken the configured recovery reauthentication
  and rate limits. Normal registration receives no new step-up control.
- Limit recovery-control reads to `GetItem` and subject-prefixed writes to
  `PutItem`/`UpdateItem` inside `TransactWriteItems`. No new Scan, Query, DeleteItem
  or cross-environment permissions. Existing source performs these mutations
  transactionally; the Lambda owner must report any additional required action.
- Correct operator recovery output descriptions and return null URLs/paths when
  the operator endpoint is unprovisioned. It remains AWS_IAM-only, never a mobile
  consumer route.

No environment tfvars, deployed artifact pins, recovery storage provisioning
flags or consumer activation flags were changed. No new public route is added
by this checkpoint.

## Lambda implementation handoff

The existing Lambda task completed a local source checkpoint on
`codex/itcr59-device-recovery-contract`, commit
`a5ae99efdd80b8c308a79d1fe756739fb9d07e2f`. This supersedes the reviewed preliminary
`4ee95b3` candidate. Neither commit was pushed, uploaded or deployed.

Implementation validates the complete receipt shape, ownership, operation,
payload hash, requested fingerprint, integral timestamps and logical expiry.
Both the initial read and transaction-cancellation replay use that validation.
Expired-but-present receipts fail closed with existing `SERVER_UNAVAILABLE`;
historical success is not current binding authority. Request parsing rejects
boolean `schemaVersion`, with a schema/runtime fixture regression. Normal
registration remains unchanged. No new Lambda environment variables or IAM
actions are required; control writes remain transactional.

Versioned source paths within the Lambda repository:

- `contracts/device-recovery/v1/contract-set.json`
- `contracts/device-recovery/v1/contract-manifest.json`
- `contracts/device-recovery/v1/self-recovery-request.schema.json`
- `contracts/device-recovery/v1/self-recovery-success.schema.json`
- `contracts/device-recovery/v1/error-response.schema.json`
- `contracts/device-recovery/v1/receipt-record.schema.json`
- `contracts/device-recovery/v1/fixtures/manifest.json` and its JSON fixtures
- `contracts/device-recovery/v1/README.md`

`status-route.proposed.json` is unsupported owner-pending design only; there is
no new GET handler, route, environment variable or IAM permission.

Independently verified local SHA-256 values:

| File | SHA-256 |
| --- | --- |
| Root `contract-set.json` | `e5d09ff748ce5f6e2f0ad6d97dd2ce38723709e3e620365218dc20ff9c509050` |
| `contract-manifest.json` | `504a3b4d2667c35357b33d495543efc8d5304bea4655564e8eada60707c48884` |
| `device-recovery-contracts-1.0.0.zip` | `383729f8fdd261b935f9b8a35cb3399d66725e6325b304167838488e53856f21` |
| `device_recovery.zip` | `04efadd6e65e49c25421a6389a4c01d83a31cec661bfcabd45ec94745f8fae25` |
| Unchanged `device_registration.zip` | `e38e0ff68a0eddc7ea194325206144557221d98cee46457195ac3b79d1e385e6` |

The root embeds the manifest digest; every listed supporting source file passed
an independent checksum check. Lambda tests additionally verify exact path-set
completeness. Local builds are in `/tmp/itcr59-device-recovery-amended-dist`, not
the older repository `dist` outputs. Its full `SHA256SUMS` check passed for 23
ZIPs. These are no-dependency build checks, not CI/S3 version or deployment
evidence. Do not copy these values into deployment pins without approved
publication and independent S3 artifact verification.

The root digest is the future `device_self_recovery_acceptance.contract_sha256`
value for this exact candidate, not the ZIP digest. No acceptance input has been
set or approved. Revisions to the contract require a new reviewed digest.

Do not represent condition-enforcing local fakes as live DynamoDB acceptance.
Keep candidate/new wire behavior unsupported until approved. Registration's
automatic switching and the operator authorization boundary must be preserved.

## Unresolved decisions

The owner has been asked to approve:

1. A read-only `GET /v1/users/device-binding` using verified token subject and
   the requesting installation's fingerprint header, reporting whether this
   installation, another installation, or none is active. No writes, account
   selector or disclosure of another fingerprint. Exact schema, inconsistent
   state handling and consistency protocol still require contract review.
2. A seven-day original-result retry window, after which expired or unverifiable
   retries stop instead of silently replacing a device again. A new recovery
   requires a deliberate new action. Exact operation-ID lifetime and enforcement
   remain unresolved; this is not approval for a tombstone retention extension.

The current random UUIDv4 plus an absent receipt cannot prove prior use. Lambda
has identified durable used-operation markers or a reviewed issuance/generation
protocol as alternatives to accepting reuse after deletion. Do not invent a new
retention period or claim permanent deduplication from seven-day receipt TTL.
Seven-day receipt retention was approved previously; post-deletion reuse was not.

## Deployment and acceptance sequence

These are preparation steps, not authorization to execute them:

1. Resolve the public contract and retry decisions; inspect the Lambda diff,
   machine-readable schemas/fixtures and local security/race evidence.
2. Review required read/status implementation and its precise IAM/actions.
   Do not reuse registration, entitlements or a paid analysis as a status probe.
3. Build/publish only after publication approval. Verify immutable S3 object
   versions and hashes for the coordinated five-package release. Pin a single
   reviewed release; do not relax the existing equality gate to reuse old pins.
4. Renew AWS SSO for a separately authorized read-only inventory. Verify account
   107827791950/us-east-1/Dev and identify any resource drift. Review foundation
   recovery storage and API plans before applying; leave activation off.
5. Obtain deployment and isolated-test approvals, including scope, temporary
   identities, cost bounds and cleanup. Consumer route exposure itself is an
   activation step under the current Terraform design, not a harmless staging
   action. Use an approved isolated candidate for pre-activation live testing.
6. Verify real concurrent registration/recovery, account isolation, old-device
   rejection while inactive, receipt replay/expiry/removed-state behavior and
   authoritative status without writes. Confirm operator JWT denial separately.
7. Only after owner/security acceptance, set the accepted release, manifest
   digest/version and evidence references, then review explicit Dev activation.
   UAT and Prod require separate approval. No production activation is implied.

## Evidence boundary

Infrastructure local verification on 2026-09-17:

- Terraform 1.12.1 API validation passed.
- Complete mocked API suite: 60 passed, 0 failed, including 17 device-recovery
  runs. No AWS resources or service calls are used by these mocked tests.
- Formatting checks for changed Terraform files and `git diff --check` passed.
- New tests cover missing/unapproved/mismatched acceptance, malformed evidence,
  transaction-only recovery-control writes, protected environment settings,
  unchanged normal registration and absent operator outputs when unprovisioned.

Lambda owner reported final post-commit results: 342 tests and 208 subtests
passed; compileall, shellcheck and diff checks passed, with two independent
no-dependency builds byte-identical. Its new stateful, condition-enforcing
simulator checks pointer-CAS and deletion-fence rollback, including rate, audit
and receipt state. This is local simulation, not real DynamoDB/API Gateway
acceptance. Infrastructure independently inspected the reviewed fixes and
verified the source/build hashes above; it did not rerun the Lambda full suite.

Previous Dev device deployment is the 8d25e19b source pin, with consumer recovery
disabled. Current development is not live readiness. A local branch or passing
mocked Terraform test does not publish an API or verify real account mutations.
No AWS API calls, live plans/applies, accounts, tokens, paid model calls, tracker
writes, pushes or deployments are part of this infrastructure checkpoint.
