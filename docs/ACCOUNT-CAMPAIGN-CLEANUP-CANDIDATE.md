# Account privacy: campaign cleanup candidate

ATCR-94, SECUR4ALL-200 and SECUR4ALL-245 remain In Progress. This prepares the
campaign worker deployment contract for the reviewed account-privacy source;
it does not enable processing or prove complete contribution erasure.

## Coordinated artifacts and controls

The optional `account_privacy_artifacts` input pins all four workers (publisher,
cluster, deletion bridge and lifecycle) to one reviewed release with individual
S3 object versions and SHA-256 hashes. It requires a review reference, the kill
switch, provisioned workers and separate non-Dev promotion approval. Mixing it
with the older individual publisher/deletion overrides is rejected. Null retains
existing packages, runtimes, IAM and activation behavior.

Selecting the candidate uses Python 3.14 ARM64 for all four functions and keeps
every event-source mapping and lifecycle schedule disabled. Validation rejects
attempts to release the kill switch for this candidate; `local.active` also
remains false. Existing environment files do not select the candidate. The newer strong-locator
source receives `CAMPAIGN_LOCATOR_MANIFEST_SHA256=""` and
`CAMPAIGN_LOCATOR_INVENTORY_REVISION="0"`; those defaults deny its mutations and do
not approve the `INVENTORY#<environment> / CAMPAIGN_LOCATORS` marker. Selecting
valid pins is a later reviewed inventory/qualification change. Lifecycle also gets
`CAMPAIGN_LIFECYCLE_CANDIDATE_ENABLED=false`. Its newer source permits only explicit
bounded recovery/paired-expiry operations after qualification, with legacy bulk
scheduling and key retirement still blocked. Function IAM may
permit explicit isolated invocations; disabled consumers alone are not a runtime
authorization boundary.

The campaign root now pins AWS provider 6.66.0 under the same supported 6.x
constraint used by the API root. This enables Python 3.14 schema validation.
The [read-only Dev provider plan](evidence/account-privacy-campaign-provider-plan.json)
uses existing artifact inputs and selects no new candidate. Its zero managed
changes are not a reviewed candidate deployment plan. Regenerate the plan before
any apply; no source artifact, environment switch or state was applied here.

## Least-privilege changes

Publisher and cluster receive pipeline ConditionCheckItem only inside
transactions for `CONTRIB#*` tombstones. All four workers can check the read-only locator inventory marker in
transactions. Lifecycle candidate/aggregate condition checks support guarded
publication and cleanup; its writes are limited to mutable pipeline families and
CAMPAIGN aggregate partitions. The publisher retains its authoritative
participation and account-fence checks, and transaction-only pipeline writes.

The deletion bridge reads the existing exact pipeline/index resources and uses
transaction-only Put/Update/Delete/ConditionCheck for contributor, event and
candidate partitions. Exact ledger commands are read and checked in each write
transaction. The candidate has no participation or ledger completion write grant.
Runtime schemas still enforce exact sort keys and target ownership; IAM partition
prefix conditions cannot enforce those details. The existing stream mapping uses
whole-batch retry; pending cleanup raises an error rather than acknowledging a
successful partial batch that the mapping would ignore.

All candidate workers validate environment/account/Region table identities.
No inventory marker writer, public route, new secret or retention extension is
introduced. New strongly consistent locator and lifecycle retry source must be
reviewed with its final IAM handoff before artifact selection.

## Source integration and remaining coverage

Lambda PR31, source `8db60fede5cf6bd24eb4a3dcc8528f4e648cfb38`, is integrated into
`release-V01` at `0226742becfccbe393b86358e4398be19c8470c7`:
https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/31

It closes producer/tombstone races, persists bounded traversal/repair, handles
terminal replays and detects incomplete lifecycle batches. Its eventual-index
pass cannot prove absence: it writes neither a CAMPAIGN receipt nor a completed
withdrawal. Repeating an eventually consistent index query is not authoritative
coverage. The source requires strongly consistent contributor locators, complete
legacy migration/writer inventory, period-key/restore coverage and durable
reconciliation beyond stream lifetime before activation. Locator lifetime must
cover target and repair cleanup; independent TTL disappearance cannot establish
completion. No longer retention was approved by this implementation.

Lifecycle aggregate publication must resume safely when publication succeeded
but cleanup failed, and erased contributor influence must be handled across
all candidate metadata. New source candidates for those paths remain subject to
review and acceptance. No test-only proof marker may be promoted into live
inventory approval. Suppression fences remain durable through the approved
backup/replay coverage window; this is distinct from receipt retention.

## Identity-mapping observation

The [read-only Dev count audit](evidence/account-privacy-dev-cognito-mapping.json)
enumerated all three current users: all three Username values matched their sub,
with no missing or duplicate sub attribute. Only counts/configuration metadata
were retained. This verifies that small current-pool observation; it does not
certify historical identifiers, restored records, future writers or the complete
account-data inventory. No user or inventory marker was changed.

## Validation boundary

Twelve mocked campaign tests cover preserved default behavior, exact artifact
pins, all disabled consumers, guarded IAM, missing pins, conflicting overrides
and foreign-account rejection. Runtime writes are restricted to mutable key
families; none of the four worker roles can write an INVENTORY marker. Local Terraform validation, formatting and
whitespace checks pass. These tests do not exercise actual AWS authorization,
queues, keys, cleanup deadlines, restoration or Android end-to-end behavior.

Independent Lambda-owner review found no blocking IAM/source mismatch in the
coordinated candidate, marker protections or disabled settings. All verification
remains source/configuration evidence; public acceptance is still open.
