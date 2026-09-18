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

The existing Lambda task is developing on
`codex/itcr59-device-recovery-contract` and will return an immutable local commit,
exact contract/fixture paths and test evidence. Scope includes complete receipt
validation, historical-outcome versus current-binding semantics, logical expiry,
conditional-write/race/isolation tests and versioned consumer schemas/fixtures.

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

Previous Dev device deployment is the 8d25e19b source pin, with consumer recovery
disabled. Current development is not live readiness. A local branch or passing
mocked Terraform test does not publish an API or verify real account mutations.
No AWS API calls, live plans/applies, accounts, tokens, paid model calls, tracker
writes, pushes or deployments are part of this infrastructure checkpoint.
