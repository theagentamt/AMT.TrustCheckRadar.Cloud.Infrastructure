# SECUR4ALL-207 recovery permission preparation

This increment selects disabled Dev recovery preparation against the already
ACTIVE sparse deletion-ledger index. It does not select a new Lambda artifact,
activate command enrollment or scheduled cleanup, approve any inventory or enable
account deletion. UAT/Production and main remain unchanged.

## Qualification boundary

The worker test composes the new recovery policy with every observed overlapping
worker ledger grant. The current role has only deletion-runtime and content-free
logging inline policies, no managed policy and no boundary. The base runtime is
validated against the existing strict deletion policy specification; pipeline,
users, streams, KMS and logging grants cannot overlap ledger item/index actions.
The existing account Get/ConditionCheck grants must be allowed in the combined
fixture, unlike the earlier new-policy-only test. No new ledger Put/Delete/Scan
is expected. This is identity-policy behavior on synthetic resources, not proof
about live SCPs, table resource policies, other services or handler semantics.

Producer qualification includes every statement affecting users and the ledger,
including account-data's existing ledger Scan, LIFECYCLE checkpoint Get/Put,
account standalone Put/Delete and user Query/Delete. It must not incorrectly
claim those operations are denied. Known disjoint table/service permissions are
reported as excluded; wildcard or unclassified overlapping grants are refused.
The actual attached/inline policy inventory is checked for additional overlapping
permissions. Application ownership and sort-key checks still require runtime
validation; IAM prefixes do not identify the authenticated account.

## Reviewed Dev changes

API selects the reviewed account-data and participation policy updates and forces
CAMPAIGN_RECOVERY_WRITES_ENABLED=false in both existing functions. The account
API's live deletion gate remains false. No source object versions or hashes
change. Existing unrelated purchase cleanup IAM is outside this change.

Campaign preparation creates the separate recovery permission policy, restricted
Scheduler role, DISABLED five-minute static-event schedule and eight alarms with
actions disabled. The existing deletion function receives only four recovery
configuration values: false gate, fixed index name, inventory revision0 and empty
manifest. Code, architecture, runtime and concurrency remain unchanged. Existing
campaign schedules and mappings stay disabled. The async invocation setting of
age60/retries0 applies to all unqualified async calls to the deletion function;
stream mappings use their separate retry settings. This is a shared-function
configuration change, not a scheduler-only limit.

The normal plan can defer the unchanged existing scheduler invocation-policy
render until the deletion function environment update completes. Do not replace
an unknown policy blindly: apply a reviewed selected-resource preparation plan
that excludes that legacy policy, then run full planning to verify no remaining
managed drift and publish output-only contracts separately if needed.

## Completion proof dependency

Lambda owns a separate unwired candidate for stable per-period proof and atomic
withdrawal/job/control or account/job/SEALED0/CAMPAIGN receipt completion. A newly
versioned metadata-only completion inventory must explicitly pin reviewed
locator/recovery manifests and cover all writers, orphan repair, publication,
restore and earlier-period erasure. No such marker is created by this work.
Persistent tombstone guards plus a strong exact-partition check are useful only
under those qualified invariants; empty indexes or age alone cannot prove erasure.
Missing/retired keys and older unqualified commands remain blocked. No completion
IAM grants or runtime activation are selected here.

SECUR4ALL-207 remains In Progress until completion, historical/restore evidence,
exact packages and runtime/operational acceptance are qualified. Physical devices
are not a dependency for this backend increment.

## Verified preparation evidence

The [worker identity-policy qualification](evidence/campaign-permissions-2026-09-24/worker-qualification.json)
passed 39 recorded AWS cases. The [producer qualification](evidence/campaign-permissions-2026-09-24/producer-qualification.json)
passed 47 cases, including atomic command/job/control writes, counter increments,
duplicate rollback, receipt/profile/control/inventory/fence races and the actual
legacy access boundaries. The three temporary tables and three temporary roles
were removed; absence was independently verified. Local tests passed 18 worker
harness and 17 producer harness cases, including SDK/Moto transaction-shape checks.
These numbers count recorded cases; some cases contain several assertions.

The [dated role-policy audit](evidence/campaign-permissions-2026-09-24/role-policies-before.json)
is bound by hashes to the tests. It is an identity-policy snapshot, not a claim
that SCPs, resource policies or all future changes are covered. No customer data,
provider credentials or log events were read by the qualification harnesses.

The reviewed [API plan](evidence/campaign-permissions-2026-09-24/api-plan.json)
contains five managed changes: two policies, two false-only environment updates,
and the Terraform preparation guard. The reviewed [worker scoped plan](evidence/campaign-permissions-2026-09-24/worker-plan.json)
contains thirteen creates and one environment-only function update; it excludes
the deferred existing scheduler policy. No replacement or deletion is planned.
These plan files record the pre-apply review. The deployment record below
establishes the subsequent apply; runtime activation remains separate.


## Deployed disabled preparation — 2026-09-24

Infrastructure [PR80](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/pull/80)
merged into release-V01 at `cd7ddad22f5f033ed330e6617039e28a01b636b7`.
The exact reviewed saved plans were hash-checked and applied manually in Dev:
API one create/four updates; worker thirteen creates/one update; zero destroys.
The [preflight](evidence/campaign-permissions-2026-09-24/deployment-preflight.json)
verified live source hashes and the complete audited role policy inventory first.
The [readback](evidence/campaign-permissions-2026-09-24/deployment-readback.json)
confirms three affected functions retain code/runtime/role/architecture/concurrency
and mapping states, the changed policies match, four schedules and three campaign
mappings are disabled, and all eight recovery alarm actions are disabled.
Live account deletion and recovery enrollment/execution remain false.

Both full post-deployment plans have no managed or output drift and all checks
pass. The [deployment summary](evidence/campaign-permissions-2026-09-24/deployment-summary.json)
records hashes and the final campaign verification inputs. Its legacy
`artifact_release` must also be supplied as the existing `d98ffd65...` release to
satisfy the older dependency check, even though all four immutable worker pins
already select that same release. The initial null-input warning was not a code
change or missing deployed artifact. The final verification plan was not applied.

Lambda [PR56](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/56)
merged candidate `82dab71e1807c7249b8bb8d318463a1940779e0d` into release-V01 at
`ee7febb87f123a468a43cfa30429faf0dea95dcc`. It implements separate inventory-pinned
stable per-period proof and atomic completion transactions. Legacy terminal
commands alone cannot assert campaign erasure; positive replays require matching,
unexpired proof and absence of the owned job. Validation passed 217 combined
SDK/Moto cases including 46 focused completion cases, plus six ordinary tests and
nine subtests. Root independently reran those same 46 focused cases; they are not
additional unique coverage. The candidate remains unwired and undeployed, without
completion IAM grants or approval markers. No historical coverage or actual
completion runtime acceptance is claimed.
