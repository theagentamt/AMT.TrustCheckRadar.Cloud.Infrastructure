# SECUR4ALL-200 Dev acceptance

This record distinguishes the Dev implementation and evidence from later release
qualification. The owner moved UAT execution/evidence to
[SECUR4ALL-329](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-329), in
Backend V1-5. That follow-up depends on Dev completion; it does not block Dev
closure. No UAT, Production, main promotion or general deletion admission is
performed by this work.

## Existing accepted Dev evidence

The [live rollout record](LIVE-ACCOUNT-DELETION-ROLLOUT.md) and its September 26
reports establish three original authenticated operations, all twelve genuine
component receipts, actual Cognito absence and preservation of unrelated rows.
The final token monitor independently establishes same-poll application and
Cognito rejection before credential expiry. These accounts were otherwise empty;
[populated component qualification](ALL-COMPONENT-DELETION-FIXTURE.md) supplies
separate actual SDK data-family and failure/retry evidence. Neither replaces the
other. Failed or inconclusive earlier attempts remain in the evidence record.

The current Dev resource/source inventory, exact IAM qualification, route and
worker readbacks, monitoring and no-drift results remain the infrastructure
baseline. This acceptance extension must not broaden any application role, change
its artifact, copy an inventory approval onto a restored table, or change its
admission lists merely to run a fixture.

## Remaining qualification under execution

The Lambda owner is adding the retained OpenAPI description, the complete
component failure/recovery evidence map, a composed restored-data quarantine test,
and supported identifier re-registration/no-relink tests. Completion must be
based on exact reviewed commits and their recorded results, not this plan.

For the actual Cognito re-registration check, the infrastructure operator
`scripts/prepare_account_reregistration_fixture.py` uses an existing completed
isolated real-Cognito fixture. It verifies the original identity is absent,
its terminal account command exists, and the exact pool, function, source hash,
configuration, account and region match the original journal. The runner remains
responsible for independently validating the original operation and all receipts.

The operator makes one suppressed same-email creation request, durably records
its intent and returned new subject, then changes only the current and previous
subject fields in the fixture function using a revision condition. An ambiguous
creation is not retried. The private stage journal cannot be overwritten by a
second invocation. Cleanup uses the original fixture journal: deletion of the
owned disposable pool also removes the new fixture identity. No AdminCreateUser
permission is added to the Lambda runtime and no existing application pool is
used. This is controlled administrative re-registration, not native signup-trigger
or client authentication evidence.

## Restore scope

Dev restoration tests reconstruct stale application records in isolated fixture
tables, retain the original deletion fences, and exercise actual application
read/write/replay and inventory refusal paths. Remaining restored records must
stay quarantined and be reported as present, not erased. Old receipts prove the
original cleanup and cannot certify the restored copy. Successful native AWS
backup restoration, cleanup/requalification and reopening of an environment remain
SECUR4ALL-245 acceptance and later environment qualification; no such result is
inferred from the Dev application fixture.

## Release handoff

SECUR4ALL-329 contains the pending E2E execution guide: exact artifact promotion,
environment validation, dedicated populated accounts, acceptance and credential
fences, twelve-receipt proof, failure/replay/restore cases, re-registration,
privacy-safe results and cleanup. Its runner must be parameterized and reviewed
for UAT before execution; existing Dev-only helpers are not automatically valid
there. Physical-device testing is not a backend prerequisite.
