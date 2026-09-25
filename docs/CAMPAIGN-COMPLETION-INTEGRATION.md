# SECUR4ALL-207 completion worker integration

This increment connects the qualified campaign completion primitive to the actual
deletion stream and scheduled recovery handler. The infrastructure selects only
the deletion-worker artifact and adds its required ledger/users permissions.
Live deletion remains disabled under the owner's standing instruction. This is
component engineering, not completion of SECUR4ALL-207 or full account deletion.

## Deployment boundary

`campaign_completion_artifact` requires a reviewed immutable source SHA, S3 object
version and SHA256, the paused Dev privacy candidate, and prepared recovery.
Publisher, clustering and lifecycle artifacts retain their previous pins. The
candidate hardcodes stream, completion and recovery flags false; manifest pins
remain empty and revisions zero. No inventory marker is written. Event mappings,
schedules, alarm actions, retention, queues and the global kill switch stay closed.
The Lambda source uses Python 3.14 ARM64 and `app.lambda_handler`.

Completion adds Query for owned ledger partitions, transaction-only ledger
Put/Delete and users Put, and users ConditionCheck. Existing guarded Update is
reused. No runtime Scan, marker-write or new KMS action is added. Prefix-based IAM
does not independently enforce authenticated account or sort-key ownership; strict
application validation and transaction guards remain necessary.

The new stream handler refuses disabled delivery before storage operations. Enabled
handler processing requires exact ledger stream identity and qualification pins,
ignores only clearly non-command shared-ledger records, and retries mixed batches
with unresolved work. Every cleanup transaction checks campaign-receipt absence;
completion-enabled cleanup also checks the observed job and open control, preventing
late writes after another invocation completes the component. Terminal suppression
is distinct from qualified campaign completion and global account deletion.

## Evidence and limits

The [isolated AWS IAM result](evidence/campaign-completion-integration-2026-09-24/iam-results.json)
records 28 passing cases against the exact four new statements plus six existing
overlapping statements. Two disposable tables and one assumed role were removed.
It tests synthetic transaction shapes and effective identity-policy behavior, not
the complete Lambda handler or every organization/resource policy. Existing recovery
Update permits `ALL_OLD` on a failed transaction; new Put/Delete/Check restrictions
do not override that existing Allow. Runtime code requests no returned failed item.

The [read-only live-key observation](evidence/campaign-completion-integration-2026-09-24/live-key-metadata.json)
completed unfiltered strongly consistent base scans of the three current Dev
campaign tables. Only two recognized period-registry rows were observed: one for
1478 and one for another period. Outbox and intelligence had zero rows. This
projection does not validate unprojected attributes, form a cross-table snapshot,
prove historical erasure, or authorize an inventory marker. Keys, tokens, source
content, key ARN values and cursors were not retained in the report. Every unknown,
legacy, data or protective key would block the narrow metadata-only observation.

Terraform mock tests: 28 passed. The new audit's six tests cover bounds, privacy,
unknown/legacy/protective rows and identity rejection. Fixture tests verify that
only the disposable ledger gains the exact KEYS_ONLY recovery index and Query ARN.
The synthetic runtime fixture has broader seed/cleanup grants than production; its
handler tests must be reported separately from the production IAM qualification.

The exact Lambda source `dffa7eaae79632db58bc366cc48434125a9c10dc` is integrated by
[Lambda PR58](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/58),
release merge `5fdd2611a6a1e98b04ddace5517ff5937ea3b4f3`. The final combined local
run passed 258 SDK/Moto cases plus six ordinary tests and nine subtests. The
[runtime results](evidence/campaign-completion-integration-2026-09-24/runtime-results.json)
record 35 passing actual AWS fixture invocations on Python 3.14 ARM64, including
seven actual stream/scheduled-handler cases. Synthetic assumed qualification
markers, deliberately injected races and modeled restore snapshots are not live
inventory approval or native backup restore evidence.

The [publication record](evidence/campaign-completion-integration-2026-09-24/publication.json)
pins the production ZIP to that exact committed source and immutable S3 version.
Its SHA256 is `0eb22f2ce00f394e7b15eafae789b256154891fb1fa0b4ec8e3f8ab1630a2687`.
The separate fixture ZIP is never selected for the Dev worker. Full-plan review
includes deferred scheduler-policy rendering caused by the function update; the
scoped apply must contain only the deletion function and new completion policy,
then a full plan and direct readback must verify no remaining managed drift.

## Remaining acceptance

SECUR4ALL-207 remains open for a whole-period producer admission fence, orphan and
aggregate/publication recovery, qualified historical period coverage, safe key
retirement with interruption recovery, and restore/replay plus operational
acceptance. Current empty observations and key age cannot substitute for these.
The old time-only retirement path remains unreachable. SECUR4ALL-200 separately
owns global component coordination and Cognito deletion. No physical device or
unrelated mobile test blocks this backend work.
