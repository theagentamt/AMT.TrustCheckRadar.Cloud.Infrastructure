# Live account deletion rollout

The owner requested live-deletion implementation on September 26. The immediate
path is an authenticated account request, durable cleanup of that account's data,
twelve verified component receipts, and removal of its Cognito identity. Whole-period
campaign HMAC retirement remains SECUR4ALL-207 lifecycle work; it is not required
before an individual account can complete while its period key remains enabled.

## Infrastructure implementation

`account_deletion_activation` is nullable and Dev-only. Null preserves disabled
configuration and creates no public deletion routes. The `workers` phase configures
the existing account-data handler, deletion stream and five-minute reconciliation
before admission. The `api` phase adds only JWT-protected POST and GET
`/v1/users/account-deletion`, requiring the Cognito user-admin scope and exact
method/path/account API Gateway invoke permissions. The Lambda derives the subject
from the validated JWT and enforces recent authentication for requests.

The activation object pins the exact account-data source and requires finalizer
inventory pins, recovery/outbox storage, the recovery index, monitoring and review
references for policy, identity, inventory and all component workers. The API phase
additionally requires a reference to the prior deployed worker acceptance. These
are operator attestations: Terraform does not verify evidence documents, write an
inventory marker, fabricate receipts, or prove that a deletion has completed.
`identity_finalizer_configured` reports configuration; completion-availability and
runtime-attestation outputs remain false because Terraform cannot establish them.

The exact twelve components are SESSION_REVOCATION, DEVICE_BINDINGS,
DEVICE_RECOVERY, ANALYSIS_ABUSE, HISTORY, CAMPAIGN, CAMPAIGN_OUTBOX, ENTITLEMENTS,
V1_AUTHORITY, PLAY_TOKENS, USER_PROFILE and IDENTITY. Configured completion means
those handlers have been qualified, not that any particular account is erased.
The runtime still verifies account-owned receipts and the independent inventory.
No retention values or business policies are changed.

Dev foundation selects the missing device-recovery control table under its existing
approved 90-day audit, seven-day receipt, 24-hour rate-state and seven-day PITR
policy. Provisioning the table does not authorize an account deletion. Its exact
name, PK/SK shape, TTL and bounded throughput are reviewed in the foundation plan.

The account-data permission fixes remove unsupported enclosing-operation context
from ConditionCheckItem. Profile Update and purchase Delete use the qualified
ForAnyValue transaction context and request no returned failed item. Their exact
ARN/key restrictions remain. The role still has existing broader ledger and other
cleanup permissions; these narrower statements do not override another Allow.

## Closed API/consumer compatibility

The original migration required an identical API/consumer source. Later independent
campaign updates changed the applied consumer release and consequently blocked
otherwise unrelated API planning. The new optional compatibility input pins both
exact SHAs and a review reference. Null retains the same-release rule; selection is
limited to Dev with consent disabled and the exact applied account/environment,
selected contract and paused consumers. It changes no API artifacts or gates.

The selected pair is API `d98ffd65b42d54953ad83e980e58846b6fc02c5d` and campaign
`f92285b50561397355a5fe2e466d297041336755`. Source review found identical shared
research-consent authority, notice/policy constants, feature contract and incoming
publisher contract. Added shared metadata handles bounded transient contribution
repair; it does not change the outbox consent envelope. Runtime admission remains
closed. This pair is not approval for subsequent releases or enabled research.
The deletion-only activation contract distinguishes paused research producers from
active cleanup workers. The API accepts this explicit research state and preserves
the prior all-consumers check when reading older contracts.

## Current evidence and exceptions

The merged period-admission prerequisite (Infrastructure PR85, Lambda PR59) was
applied in Dev on September 26: four pinned Lambda updates and four IAM changes.
Direct readback verified hashes, policies, three disabled mappings, four disabled
schedules, eight disabled recovery alarm actions and four disabled-handler checks.
The subsequent full campaign plan has zero managed and output changes.

The fresh Cognito/profile audit enumerated three identities: all three unique
Username/sub mappings match. Two PROFILE records match their subjects, with no
orphan profile. One FORCE_CHANGE_PASSWORD administrative identity has no PROFILE
and is not admissible to the current deletion API. It remains untouched and outside
this account-deletion qualification; it needs a separately verified onboarding or
administrative lifecycle path. Username/sub consistency does not mean the entire
inventory is approved. The observations are separate reads, not one snapshot.

The purchase/profile/ledger IAM fixture passed 13 grouped actual AWS cases; all
three synthetic tables and the temporary role were removed. It validates relevant
identity-policy behavior and atomic rollback, not Cognito, every other component,
SCPs/resource policies or actual full-account erasure. Local audit tests ensure
bounds and prevent personal identifiers from entering the retained report.

## Activation and shutdown sequence

1. Deploy reviewed source and permissions for every receipt producer, including
   the campaign repair fixes and refreshed account-data recovery enrollment.
2. Qualify current storage, retained periods/locators, authority/purchase coverage
   and identity mapping; write only a genuinely reviewed manifest and matching
   inventory controls. No empty scan, TTL age or passing mock can substitute.
3. Enable workers, verify durable recovery and alerts at support@andmorethings.com,
   and run a designated synthetic-account end-to-end test including identity removal.
4. Record exact deployed worker acceptance, then expose authenticated API admission.

To stop admission, change `api` to `workers` first. Remove the public route/invoke
grant, wait past the maximum in-flight request timeout, then confirm newly accepted
and pending requests have reconciled before changing `workers` to null. An empty
backlog observed before admission drains is not sufficient. Terraform cannot enforce
transition history; null is not a safe routine one-step rollback of active requests.

No real account has been selected for deletion by this rollout work. Export, paid
provider checks and physical-device testing are independent; they do not gate backend
engineering. SECUR4ALL-200/207/245 remain open until their actual acceptance is met.

## Account-cleanup source and qualification

[Lambda PR60](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/60)
integrates source `f92285b50561397355a5fe2e466d297041336755` at release merge
`223e9bea5b109131de98bf2b07251a8f7877eeb1`. Five exact-source production archives
were independently verified and published to immutable Dev object versions.
Frozen-candidate deletion now repairs and resumes without extending deadlines;
published aggregates retain their approved anonymous form while linkable transient
pairs are removed. A lost final repair acknowledgment no longer strands the cursor.
Publication checks all included contributor tombstones and refuses transactions
beyond the DynamoDB bound rather than silently omitting contributors.

The 48-case Python 3.14 ARM64 AWS fixture passed. Its two added cases exercise
actual campaign cleanup through a CAMPAIGN receipt, sealed control and finalizer
DynamoDB proofs. Cognito and other-component receipts/inventory are injected, so
this is not evidence of live identity removal or erasure by all twelve components.
The fixture still models intelligence in the isolated pipeline table and uses one
key for two periods; separate new-grant IAM tests cover distinct table resources.
See [runtime results](evidence/live-account-deletion-2026-09-26/runtime-results.json),
[package manifest](evidence/live-account-deletion-2026-09-26/production-manifest.json)
and [publication](evidence/live-account-deletion-2026-09-26/publication.json).

No actual inventory approval or live-generation assignment is inferred from these
results. New Dev account-data source is selected with activation null. The full
account endpoint remains unavailable until coordinated component acceptance.

The three new campaign aggregate/tombstone grants passed 14 isolated AWS IAM cases.
The supplied role audit found no existing action/resource/key-namespace overlaps
for those grants. This is new-grant qualification, not a full deployed-role test.
Both temporary tables and the role were removed. The separate runtime fixture's
three tables, role and function were independently confirmed absent; its key is
PendingDeletion for October 3, not destroyed. Local API Terraform validation passed
133 cases. The final full campaign Terraform suite passed all 36 cases, including the
exact-key encryption permission regression.

## Campaign table encryption access

The current key policies delegate authorization to IAM. Existing table-specific
DynamoDB service grants do not demonstrate caller authorization for the deletion
role, whose prior policy contained only period-key GenerateMac access. Preparation
adds Decrypt on exactly the transient and persistent campaign keys, constrained to
this account and regional DynamoDB through kms:ViaService. It grants no direct
KMS use or key management. The default-encrypted IAM fixtures do not qualify this
CMK path. The later actual-role probe and delayed CloudTrail correlation below qualify the
fresh decrypt path; the original IAM fixture alone does not establish it.

## Closed deployment verified

Infrastructure PR86 merged at `4135af1b5143a92fd443a61c75224b9dc0920c6e`.
The recovery control table, four f922 campaign packages, exact cleanup/decrypt
policies and f922 account-data package were deployed manually to Dev. API recovery
storage wiring also refreshed account export and device-recovery configuration;
self recovery remains false and the operator allowlist is empty. Direct readback
matched package hashes, environment and policies, confirmed seven-day recovery
PITR/TTL and no public deletion route. Full foundation, campaign and API plans all
reported no differences after deployment.

A temporary function using the actual deployed deletion role successfully made
strongly consistent, projected reads of absent synthetic keys in both encrypted
campaign tables. It made no table writes and returned no item data. The function
and its possible log group were removed; the production function was unchanged.
The immediate CloudTrail lookup was empty. A delayed bounded lookup then confirmed
successful Decrypt events for both exact CMKs, the unique temporary function role
session and matching DynamoDB table encryption contexts. Both observations remain
in the evidence; the delayed result qualifies fresh KMS access for this probe.

## Deletion-only activation control

`campaign_deletion_activation` is null by default and is not selected in Dev.
It pins the reviewed campaign source, UUIDv4 generation and three manifest/revision
pairs, requiring existing cleanup preparations plus inventory/runtime/encryption
evidence. Selection enables only the deletion bridge, ledger stream, five-minute
recovery and its alerts. Research publisher, aggregator and whole-period lifecycle
remain paused under the global kill switch. This object does not create or approve
inventory records; live workers independently verify their exact stored proofs.
The all-consumers output becomes false when cleanup is active; a separate research
producer output stays true, avoiding a false claim that all consumers are paused.
All-component nonempty fixtures and synthetic Cognito deletion remain outstanding.

Turning `campaign_deletion_activation` back to null stops accepted campaign work.
First close public admission, drain in-flight requests and reconcile all accepted
account/withdrawal work; only then stop the campaign workers. Their stream and
schedule both wait for the required runtime policies during initial activation.

Lambda PR61 source `997e265f7edf10ce7369481f7d576b4276e8c418`, merged at
`218769da5b482f98b8cb7e0be93d16e656c38c3e`, adds a fail-closed configuration
check requiring durable campaign recovery enrollment whenever deletion is enabled.
Only config.py differs in the account-data package; all campaign pins remain f922.
The independently verified immutable account-data version is now selected in Dev
with activation still null. Local validation passed 44 tests, 20 subtests and eight
SDK cases. Package publication is separate from deployment acceptance.

Infrastructure PR87 merged at `4f11ae989d3075a5439ae9611729dba4040cefc7`.
The 997e account-data guard is deployed and directly read back with unchanged
disabled environment and no public deletion route. Full API planning reports no
drift. Campaign control outputs and alarm descriptions were applied with all gates
and alarm actions still disabled. The unprofiled administrative identity exception
is tracked in SECUR4ALL-327; it was not changed or deleted.
