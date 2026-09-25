# SECUR4ALL-207 period admission fence

This candidate closes admission to new campaign contributions while retaining the
period HMAC key for cleanup. Closing admission is not proof of erasure, final
publication, drained outbox/queue, or key retirement. Live deletion stays disabled.

## Coordinated contract

The existing PERIOD#n / HMAC_KEY row retains PK, SK, periodId, keyArn,
status=ENABLED and retireAfterEpoch. The Lambda candidate adds a strict versioned
admission schema: admissionSchemaVersion=1, canonical UUID admissionGeneration,
admissionState OPEN or CLOSING, positive admissionRevision, admissionManifestSha256,
admissionInventoryRevision and admissionChangedAtEpoch. The latter manifest and
revision bind the existing independently qualified locator inventory. No field
contains an account identifier, contributor token or message content. Data retention
and key-retirement deadlines are not refreshed or extended.

All four workers require the generation pinned outside the table. The new default
configuration is CAMPAIGN_PERIOD_ADMISSION_ENABLED=false and an empty
CAMPAIGN_PERIOD_ADMISSION_GENERATION. Missing or legacy admission metadata is not
implicitly OPEN. CAMPAIGN_PERIOD_ADMISSION_ACCOUNT_ID is pinned to the actual AWS
account; runtime Region and invocation identity must agree with the key ARN.
No initializer, automatic migration, reopen, generation assignment,
inventory approval or key-retirement writer is introduced by this candidate.
Existing rows require separately qualified preparation before future activation.

Publisher writes and every cluster mutation must check the exact observed OPEN
period row in their DynamoDB transaction. Direct key-id injection cannot bypass
that check. SQS send is not atomic with DynamoDB: a delayed envelope can still
exist after closure, and the cluster transaction must refuse it. The outbox producer
is a separate upstream boundary; this does not claim absence of outbox observations.

The guarded lifecycle close operation transitions only OPEN to CLOSING, checks the
same observed registry and inventory, and requires the period to have ended. It
keeps the key ENABLED. Repeat closure must preserve original timestamps and not
increment revisions again. Deletion/repair may continue under exact-generation
checks after closure; new publication freeze requires CLOSING as well as existing
recovery-window, candidate and inventory conditions. Restoring an older OPEN row
under unchanged external pins remains unsafe: restore quarantine, generation
invalidation and requalification are still required before writers may resume.

## Infrastructure scope

The nullable campaign_period_fence_preparation requires coordinated same-source
pins for the existing four-worker privacy bundle and completion-worker override,
Dev only, recovery/completion preparation and the global kill switch. Its selection
adds the two closed admission values and fixed account ID to every worker. It does not add
a live-generation input or activation switch.

Publisher, cluster and lifecycle gain ConditionCheckItem on the exact pipeline ARN
and PERIOD#* keys, with ReturnValues NONE. Deletion already has the required period
checks. Lifecycle loses PERIOD#* from its broader Put/Update/Delete/BatchWrite grant;
its new period Update is transaction-only, with ReturnValues NONE. Period Put,
Delete and BatchWrite are not granted. DynamoDB Update can upsert without a
condition; IAM cannot enforce record existence or the admission schema. The
application's exact observed-row condition prevents initialization and enforces
the OPEN-to-CLOSING transition. No KMS permission changes.

Four local Terraform tests cover default absence, coordinated closed selection,
mixed-source rejection and missing completion preparation. The complete mocked
module suite passed 32 tests. Permission-only preview artifacts deliberately do not
exist and cannot be used for deployment; actual selection requires reviewed source,
immutable package hashes/versions, exact policy qualification and saved-plan review.

The [actual AWS IAM qualification](evidence/campaign-period-admission-2026-09-24/iam-results.json)
passed 37 cases for the three complete audited DynamoDB policy unions, including
the exact lifecycle narrowing. Five synthetic tables and three temporary roles
were removed. It exercises permissions and transaction rollback with synthetic
shapes, not actual worker schema, transport, erasure or retirement behavior.
The helper's 15 local tests validate source binding, reject overlapping authority,
and check expression/rollback behavior without treating Moto as IAM enforcement.

## Exact-source package and runtime evidence

The reviewed Lambda source is `cab9a2a3976e52b64b75057a8432b1506a365b02`.
The [package manifest](evidence/campaign-period-admission-2026-09-24/package-manifest.json)
records all four production archive hashes and sizes, plus the separate qualification
archive and its member hashes. The
[local archive verification](evidence/campaign-period-admission-2026-09-24/local-verification.json)
checks the four exact packages and their disabled-handler refusals on local Python
3.14. Its `awsArm64RuntimeQualified:false` describes that local check only.

[Immutable artifact publication](evidence/campaign-period-admission-2026-09-24/publication.json)
completed for all four packages in the Dev artifact bucket. Publication records
exact S3 object versions and hashes; `runtimeUpdated:false` and
`activationApproved:false` distinguish uploading packages from worker deployment.
No deployment or activation is claimed by this evidence update.

The [isolated AWS runtime result](evidence/campaign-period-admission-2026-09-24/runtime-results.json)
records 46 passing cases on Python 3.14 ARM64 for fixture `c9415ab382de`, including
period-close replay, legacy/stale-generation/foreign-key refusals, publisher first
and final write races, late cluster delivery, new/repeat/capped cluster races and
cleanup during CLOSING. The qualification archive SHA256 matches the manifest.
This runtime evidence is separate from the production-role IAM qualification.

The runtime runner uses one isolated HMAC key to model two logical periods. It
therefore does not prove independent per-period key separation, rotation, disable
or deletion. SQS send and candidate-index discovery are injected; logical outbox
records share the isolated users fixture table. These cases do not establish actual
queue transport, GSI propagation or separate production outbox-table bindings.
Restore cases reconstruct synthetic snapshots rather than restoring native AWS
backups. Injected races exercise actual SDK transactions but cannot establish
historical coverage, inventory approval, production activation or retirement.
The separate [cleanup readback](evidence/campaign-period-admission-2026-09-24/fixture-cleanup-readback.json)
confirms the fixture Lambda, role and all three tables are absent. The disposable
key is PendingDeletion for 2026-10-02 UTC; it is not yet destroyed.

## Deployment preparation

The full and bounded saved plans were verified against the exact qualified IAM
policy hashes and immutable four-worker package pins. The bounded plan contains
four worker updates, three period-check policies and the lifecycle permission
narrowing. No activation values, table rows, schedules or stream mappings change.
The full plan also renders two deferred scheduler policies; these are excluded
from the bounded apply. Plan verification is not deployment evidence.

GitHub publication awaits the owner response after automatic approval review
rejected the Lambda push for inability to establish repository-specific
authorization. Both repositories target release-V01; main remains unchanged.
No current candidate has been deployed or integrated by this evidence update.

## Remaining acceptance

Closing admission is one dependency of SECUR4ALL-207. Orphan recovery, whole-period
current/legacy family coverage, aggregate/publication completion, guarded key
retirement and interruption recovery, historical period qualification, restore/
replay and operational acceptance remain open. An empty eventual index, queue
count or current base-table scan cannot replace these requirements. No mobile
hardware blocks this work, and no current acceptance is marked complete by this
preparatory document.
