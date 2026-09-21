# Account-data inventory and completion requirements

Status: infrastructure and Lambda source inventories reconciled. Dev policy
decisions are recorded in [ACCOUNT-DATA-POLICY-DECISIONS.md](ACCOUNT-DATA-POLICY-DECISIONS.md);
live coverage verification and implementation remain incomplete. This is not activation approval.
Infrastructure baseline: `297b654`; Lambda baseline:
`195859848cde7de04b26da83f2fa34b9ff5922f4`.
The feature branch is committed; `main` and deployed resources are unchanged.
Account deletion/export and consumer recovery remain gated.

The following matrix records baseline behavior. Source fixes verified in the
subsequent Lambda commit `960282963443ccf257e135dbcd6f2e8429ba0312` are described
under "Inventory-phase source handback" below; they are not deployed fixes.

## Scope And Evidence

Infrastructure declares twelve DynamoDB table instances when all optional
features are provisioned: six existing foundation tables, one optional recovery
table, three campaign tables and two History tables. This is not a claim that
all twelve are currently deployed. Dev tfvars enable campaign and History data;
recovery storage remains opt-in. UAT/Prod require their own release review.

Sources: [foundation storage](../terraform/foundation/main.tf),
[recovery storage](../terraform/foundation/device-recovery.tf),
[campaign storage/queues](../terraform/campaign-data/main.tf),
[History storage](../terraform/history-data/main.tf), and
[Dev environment inputs](../environments/dev/).
Lambda source links below refer to the baseline commit, not an uncommitted draft.

Table suffixes below follow `trustcheckradar-<environment>-`. A hash of a user
identifier is still linkable to that user; it is not automatically anonymous.
Enabling TTL on a table neither gives every item an expiry nor proves physical
deletion within the active-data deadline. PITR and queues require separate
retention and restore/replay treatment.

## Persistent Store Coverage

| Store | User association and contents | Current source coverage | Remaining requirement |
| --- | --- | --- | --- |
| `users` | `USER#sub/PROFILE`: email, names, optional phone, age verification, status; participation state, operation receipts and consent audit share the partition | Producer fences PROFILE; campaign worker updates consent-related state | Classify every SK; remove personal profile fields only after required cleanup/identity resolution; decide minimal consent evidence retained |
| `deletion-ledger` | `ACCOUNT#sub/ACCOUNT_DELETION`, component receipts, withdrawal commands, device-cleanup progress; environment reconciliation checkpoints | Durable command, four component receipts, bounded reconciliation | Overall finalizer; retained evidence policy; exact progress-only deletion; safe fence retirement and restore suppression |
| `analysis-abuse-control` | Subject-derived hashes under REQUEST, CONSUMPTION, RATE and SCAN_RATE families; cached responses and quota/idempotency state | History cleanup redacts replay responses and retains minimal dedup evidence | Explicitly cover every family, including records outside History; protect against replay and quota reset without retaining submitted content |
| `device-bindings` | `USER#sub/DEVICE#fingerprint` and versioned `ACTIVE_BINDING` pointer | Bounded strongly consistent query/delete and DEVICE_BINDINGS completion receipt | Deployed races/retries test; ensure all writers honor the deletion fence |
| `purchase-entitlements` | `USER#sub` entitlements/usage plus `TOKEN#purchaseTokenHash/IDEMPOTENCY` containing accountId | No complete account cleanup/export component | User-partition query alone is insufficient; bounded reverse ownership locator or reviewed legacy backfill; decide billing/replay evidence retained |
| `web-risk-cache` | `WEBRISK#scope#hash/RESULT`; currently stores raw normalized URL/domain in `uri` plus threat results | Shared TTL cache; no subject-linked erase/export | Remove unnecessary raw URI from future records if compatible; explicit legacy cleanup and backup handling; do not label unowned full URLs anonymous |
| `device-recovery-control` (optional) | `USER#sub` recovery receipts, audit and rate state | Recovery writes are implemented; no account cleanup component | Separate audit/receipt/rate retention approval and PITR choice; selective erasure or minimization, not blind partition deletion before approval |
| `campaign-outbox` | Event-keyed sanitized observation data awaiting publishing | Publisher and expiry controls | Prove account/consent mapping, rejected late publication and transient payload purge; event keys cannot be found by a simple USER# query |
| `campaign-pipeline` | Pseudonymous observations/contributions, contributor-period lookup, candidate and expiry indexes | Campaign deletion/recomputation path | Inventory every key family, contribution mapping and orphan handling; prove late queue delivery cannot restore removed contributions |
| `campaign-intelligence` | Aggregates, publication/review records and contributor-derived working state | CAMPAIGN receipt after contribution removal/recomputation | Distinguish unlinkable published aggregates from linkable/internal data; preserve publication/privacy thresholds after withdrawal |
| `history-content` | `USER#sub#HISTORY#generation` summaries/results | All-generation History cleanup and expiry; HISTORY receipt | Verify actual purge, concurrent completion suppression and export projection; no screenshots/images |
| `history-control` | State/progress/badges, request locators, mutation receipts, cursors, erasure jobs and checkpoints | History lifecycle, reset, replay and erasure state machine | Account deletion versus History clear must be explicit; retain only approved minimal tombstones; verify every transient/control key |

## Retention Baseline

| Data | Source configuration, not a new approval |
| --- | --- |
| Foundation's six tables | PITR enabled; recovery window not explicitly set in Terraform. Verify effective settings and existing backups before drafting restore promises |
| Foundation TTL | `expiresAt` enabled on users, abuse, devices, entitlements and URL cache; deletion ledger has no TTL |
| Inactive devices | Default 180 days; active account deletion uses explicit cleanup rather than waiting for that expiry |
| Purchase usage counters | Default 548 days; this is not a blanket billing-record retention approval |
| Purchase replay records | Baseline writer does not set expiresAt; table TTL cannot expire those records |
| Participation audit | Dev explicitly configures 400 days; do not replace it with History's 120 days |
| History | Approved 90-day content, 24-hour active-data erasure deadline, 7-day PITR, 120-day minimal metadata and 7-day mutation receipts |
| Recovery control | Owner approved 90-day audit, 7-day receipts, 24-hour rate state and 7-day PITR on 2026-09-14; provisioning remains disabled |
| Campaign outbox/pipeline | Declared maximums 72 hours/21 days; PITR disabled; validate actual item expiry and worker deletion separately |
| Campaign intelligence | Declared maximum 400 days; PITR enabled with unspecified window |
| Campaign SQS | Source queue 4 days, DLQ 14 days; no account-specific queue purge is implied |
| URL cache | Full-URL logical TTL 15 minutes to 24 hours, domain TTL up to 7 days; PITR remains enabled |
| Managed API/campaign/History logs | Generally configured for 14 days in Dev/current defaults; not a guarantee all existing log groups are managed |

See [Dev API inputs](../environments/dev/api.tfvars),
[foundation defaults](../terraform/foundation/variables.tf),
[History approval](../environments/dev/history-data.tfvars) and
[campaign queue contract](../terraform/campaign-data/main.tf).

## Identity, Transport And Other Copies

- Cognito contains identity attributes and sessions. Global sign-out is not
  identity deletion. The pool uses email sign-in; verify actual Username/sub
  mapping instead of inferring it from the login identifier. Keep
  COGNITO_USERNAME_IS_SUB=false until proven or replaced by a validated mapping.
- Post-confirmation writes personal profile attributes. Its Terraform stack
  currently declares no managed CloudWatch log group/retention. Inventory the
  existing group read-only before importing/managing it; do not silently shorten
  existing retained logs. Source: [identity workflow](../terraform/identity-workflows/main.tf).
- Campaign queues, DLQ and DynamoDB streams can contain delayed references or
  payloads. Prove that consumers recheck deletion/consent before processing and
  that expired/redriven work cannot recreate personal data. Never purge a shared
  queue to satisfy one user's deletion request.
- Lambda/API logs and tracing/error paths need a content audit: no tokens,
  passwords, request bodies, full URLs, signed export cursors or purchase tokens.
  Do not promise selective per-user CloudWatch erasure without an implementation.
- S3 artifact and Terraform-state buckets store software/configuration, not an
  approved user export or upload store. Both are versioned. Check actual contents,
  CI artifacts and snapshots separately; do not scan or delete them automatically.
- Secrets Manager holds provider credentials, HMAC/cursor keys and service
  secrets, not normal user submissions. Per-user deletion must not delete shared
  keys or break other users' access.
- External analysis and URL-risk services, Google Play, and app-local caches are
  separate copies/owners. Document their data flow and retention obligations;
  an AWS component receipt cannot prove those copies were erased. Mobile work
  remains a handoff to the relevant Android/iOS workspace.
- No image upload/export bucket or OpenSearch resource is introduced by this
  work. Sanitized text can still contain personal information and must stay in
  the inventory.

## Concrete Source Gaps

1. [Purchase replay writer](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/195859848cde7de04b26da83f2fa34b9ff5922f4/src/purchase_handoff/idempotency.py)
   writes accountId under TOKEN#hash with no TTL. It needs an ownership discovery
   contract and a policy for preventing purchase-token reassignment after erasure.
2. [URL cache writer](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/195859848cde7de04b26da83f2fa34b9ff5922f4/src/web_risk_communication/cache.py)
   persists `uri`; query strings and paths can identify people even when the key
   is hashed. There is no subject index, and legacy configuration allows using
   the users table. Future minimization alone does not remove legacy copies.
3. [History replay cleanup](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/195859848cde7de04b26da83f2fa34b9ff5922f4/src/history_lifecycle/service.py)
   removes cached responses while retaining dedup metadata. It is not evidence
   that every abuse/quota/consumption record has an approved lifecycle.
4. Writer-fence review must include age attestation, post-confirmation, purchase
   updates and participation, not just registration/recovery/analysis. A stale
   request must not set a deleting profile back to ACTIVE or recreate erased
   records after a worker has issued its receipt.

## Required Completion Contract

Proposed implementation ordering, not approval of new retention or endpoints:

1. Accept a subject-only, freshly authenticated deletion request and durably
   fence new use. Record operationId and the applicable policy/inventory version.
2. Stop every writer and late delivery from reintroducing data. Start durable,
   idempotent cleanup with bounded work and per-component receipts.
3. Complete all inventory components, including identity deletion at the reviewed
   point in the workflow. Do not drop identifying lookup data before dependent
   cleanup can find token-keyed or contributor-keyed records.
4. Only a finalizer with the exact expected receipt set can declare completion.
   Unknown/missing components, retries and expired operational leases are not
   success. Retained evidence must be reported separately from erased content.
5. Keep a minimal suppression record through the approved replay/backup horizon.
   Restore into isolation, apply deletion suppression, re-run cleanup, validate,
   then permit serving traffic. Never rely on restoring the old deletion ledger
   together with old profiles to preserve deletions that occurred after backup.
6. Define honest post-deletion status. Current GET works only while a token is
   still accepted; a new restricted receipt-based mechanism would require its
   own abuse/expiry contract. Do not retain a working account just for polling.

## Export Contract To Finish

Prefer authenticated bounded JSON pages over another S3 export service. Export
identity must come only from the access-token subject; signed cursors must bind
subject, operation, inventory/schema version, section and expiry. Define mutable
data behavior across pages and cancellation on deletion/session revocation.
Allowlisted projections must exclude credentials, purchase tokens, other users'
records, internal abuse rules and security secrets. Report which sections are
complete, unavailable or intentionally retained; History export is not a full
account export. Resolve legacy token-keyed ownership before claiming completeness.

## Remaining Policy And Coverage Work

The owner's [2026-09-14 decisions](ACCOUNT-DATA-POLICY-DECISIONS.md)
resolve the proposed Dev retention and export-order choices. Inventory and
missing writer/cleanup work remain engineering responsibilities:

- Minimal deletion evidence: implement the approved 120-day minimal receipt
  policy only after verifying suppression coverage across backup/replay horizons.
- Purchase/billing replay evidence: exact retained minimum and duration; existing
  configuration is not proof that all billing records must be kept that long.
- Consent/security audits: implement minimal evidence under the confirmed
  400-day consent and 90-day recovery audit policies; verify retained projections.
- Recovery audit/receipt/rate and backup periods are approved; cleanup,
  logical expiry, restore treatment and deployed acceptance still need proof.
- Backup/log/external-provider treatment: understandable exclusions and maximums
  backed by verified configuration, not an unqualified "everything is gone".

The linked owner decision record supplies policy approval. No live cleanup,
index, store, public route or deployment is authorized by this inventory.

## Inventory-Phase Source Handback

The Lambda task's [full record-family matrix](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/960282963443ccf257e135dbcd6f2e8429ba0312/docs/account-data-inventory.md)
matches the infrastructure findings. The actual implementation commit is
`43300440b611c018fe8c44e4410f93e4117097de`; documentation alignment is
`960282963443ccf257e135dbcd6f2e8429ba0312`, verified on GitHub.

Source changes now remove `uri` from new URL-cache records and suppress legacy
URI values on reads. They do not erase historical rows or backups. Signup
profile creation and age-attestation writes now check the fixed deletion fence
inside the same transaction; age attestation cannot reactivate a deleting
profile. All other uncovered producer paths still need review.

Verified local ZIP hashes in the Lambda repository's current `dist` directory:

| Artifact | SHA-256 |
| --- | --- |
| age_attestation.zip | `fd7e2045fb57cf0683251752b840b6dbd4a55adb2432a9c789b1cbe6550ef545` |
| post_confirmation.zip | `b988dc830a77aa332d036ba6e1325295ede9cd33d514c9cd59ed380e55ba593b` |
| web_risk_communication.zip | `7aa2701f77c05db23f9ac45ba7ac9765a5d47246e0858983027ace8fca26361e` |

Lambda reports 284 tests and 129 subtests passing, compilation, shellcheck and
campaign evidence validation. Infrastructure did not rerun the Lambda suite.
The older `/tmp/amt-lambda-release-1958598` staged set remains unchanged and
must not be relabeled as this release.

## Prepared Profile-Writer Integration

`profile_fence_deployment` is a separate null-by-default candidate input in
both `terraform/api` (age attestation) and `terraform/identity-workflows`
(post-confirmation). Each requires the same reviewed release ID but its own
ZIP's S3 object version and source hash, an approval reference and separate
UAT/Prod promotion approval. No S3 object versions have been invented.

Selecting a candidate provides the authoritative ledger environment variable,
transaction-only profile UpdateItem/PutItem and ledger ConditionCheckItem,
scoped to the environment tables and USER#/ACCOUNT# partition families. IAM
does not enforce SK values; exact PROFILE and ACCOUNT_DELETION keys are checked
by the Lambda implementation. IAM attachment ordering precedes the function
update, but AWS code/config/IAM changes are not a single atomic operation.
Plan a controlled rollout: old code can fail closed while permissions are
tightened; do not promise a zero-interruption switch.

Post-confirmation additionally requires `post_confirmation_log_policy` with a
finite retention period and approval reference. Default null leaves the
existing log group/retention untouched. Inspect and import an existing group
before applying the managed resource; never destroy/recreate logs to adopt it.
Fourteen days was approved on 2026-09-14, but has not been selected for this
unmanaged group pending live inspection and reviewed import/rollout.

URL-risk deployment can use the existing explicit S3 key/object-version inputs
for that function alone. Terraform already provides the dedicated
WEB_RISK_TABLE_NAME and table-scoped IAM. Do not switch the global artifact
release just to publish this one fix or rely on the legacy users-table fallback.
Reverify its checksum before future publication.

No profile candidate or log policy is selected in environment tfvars. Both
writers and every remaining inventory component must pass deployed acceptance
before account deletion can activate. CI now includes plan-only mocked identity
tests; none runs the Cognito-update provisioner or touches AWS.

## Read-Only Metadata Verification

Run the repository helper using the already authenticated AWS CLI:

```sh
python3 scripts/audit_account_data_storage.py --environment dev --expected-account 107827791950
```

The helper checks the account before querying storage, then describes the twelve
default-name tables, TTL/PITR configuration and bounded Lambda/API log-group
metadata. It never reads table items, log events, messages or secret values,
does not log in, and never creates/changes/deletes resources. It reports missing
tables and unspecified backup/retention values rather than inventing defaults.
A denied metadata query or changing table aborts the report rather than silently
claiming complete coverage. The JSON explicitly does not certify deletion
readiness and lists uninspected backup/transport/external copies.

Custom-name resources, historical tables/backups and other AWS accounts are not
discovered by this helper. The five focused audit tests run without AWS and are
included in the existing helper-script CI test discovery.

The initial audit failed because the SSO session had expired. After the owner
renewed it, the 2026-09-14 read-only audit succeeded outside the network sandbox
and verified account `107827791950`, region `us-east-1`:

- Eleven default-name tables exist and are ACTIVE; recovery control does not
  exist yet.
- All six foundation tables and campaign intelligence have 35-day PITR.
  Both History tables have 7-day PITR. Campaign outbox/pipeline PITR is disabled.
- The deletion ledger has TTL disabled and a NEW_IMAGE stream. The other ten
  observed tables have expiresAt TTL enabled; item expiry coverage was not read.
- The existing `/aws/lambda/trustcheckradar-dev-post-confirmation` log group
  has no explicit retention. The other 15 matching Lambda groups and one API
  log group have 14-day retention. Import/adoption review is required before
  applying the approved post-confirmation log policy.

No table items, log events or identity attributes were read and no resources
changed. On-demand/AWS Backup copies, S3 versions, queue replay and external
copies remain unverified. The observed PITR windows alone do not authorize
retiring deletion fences at 120 days or certify account-deletion readiness.

## Private result feedback — ATCR-122 / SECUR4ALL-238

Source implementation is in progress; this entry is not evidence of live deployment. The owner approved optional structured-only product-quality feedback on an owned retained assessment and storage on the existing purchase-entitlements CHECK row with inherited backup retention. See `PRIVATE-RESULT-FEEDBACK-DECISIONS.md` for the immutable proposal and approval record.

The planned bounded object contains opaque feedback ID, one approved category, server receipt time and policy version. Existing CHECK linkage supplies account/result association. It contains no submitted message, URL, image, free text, demographics or new contact information. One report per result is immutable; ordinary analysis receipt/history projections exclude it. Feedback is separate from research/commercial consent, is not a truth label and does not change billing, verdicts or campaign data.

Active access ends at the original receipt deadline; submission does not start a new seven-day period. Existing whole-row explicit expiry and account-deletion workers must remove the field with its CHECK. TTL remains eventual fallback. Verify those workers and all inventoried account key versions before activating a writer. Restrict the runtime to owned conditional updates; operational logs must not contain bodies, categories, proofs or account/result identifiers.

This object inherits the shared table's PITR and any other backup copies. A read-only Dev audit on 2026-09-21 after renewed AWS sign-in verified 35-day PITR, expiresAt TTL enabled and GSI1 active. Regional DynamoDB backup/export and AWS Backup recovery-point listings were empty for this table; no replicas or stream were listed. This is not proof that no historical/manual/cross-region copy exists. See evidence/private-result-feedback-dev-audit.json. Explicit expiry and account-deletion workers, their schedules and the deletion stream mapping were deployed but disabled; qualify and enable them before feedback activation. Restores require quarantine and reapplication of expiry/deletion controls before access. No all-copy erasure at day seven is promised. Do not create longer-lived extracts/aggregates or new backups by implication. Account export must explicitly account for this new field before claiming export completeness; no complete export capability is asserted here.
