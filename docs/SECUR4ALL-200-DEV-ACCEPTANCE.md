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

## Additional Dev qualification

The Lambda owner added the retained OpenAPI description, complete twelve-producer
failure/recovery evidence map, composed restored-data quarantine test and supported
identifier re-registration/no-relink tests in [Lambda PR72](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/72).
Fixture source is frozen at `de60324aac7616d05207ad46351c936fc61841eb`;
the documentation-only retry map is `7e2d172f3d0d736afc307af700d3f188036f5ab7`.
All three targeted actual AWS cases passed on Python 3.14 ARM64. The retained
reports below distinguish these results from the existing SDK/Moto tests.

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

## Recorded results and closure boundary

| Remaining Dev criterion | Result and evidence |
| --- | --- |
| Versioned API documentation | Reviewed OpenAPI for POST/GET `/v1/users/account-deletion`, immutable schema/fixture references, gateway uncertainty and current twelve-component examples. The old proposed DELETE route is superseded; no duplicate endpoint is introduced. OpenAPI validation and 76 tests plus 56 subtests passed. |
| Every receipt producer has failure/recovery evidence | Reviewed Lambda producer map covers all twelve producers with 43 test anchors and 15 source paths. Nine missing local receipt/deletion acknowledgment-loss cases were added; existing accepted AWS, IAM, auth, export, retention and writer-fence evidence is reused without claiming new coverage from deployment alone. |
| Composed restored-copy suppression | Actual AWS `handler_all_components_restore_quarantine` passed in 13.238 seconds. Original completion proof, real guard/writer refusals and copied/missing inventory refusals are checked together. Residual copied records remain quarantined, not reported erased. |
| Re-registration without automatic relinking | Actual AWS `identity_complete` passed in 12.317 seconds and independent Cognito lookup confirmed absence. The same suppressed fixture email was recreated with a distinct actual subject; `identity_reregister_same_email` passed in 3.001 seconds. Genuine profile creation, original suppression, no automatic grant and unchanged seven used paid checks were verified. Explicit verified store restoration remains covered by separate tests; no provider purchase was performed. |

All exact archived source members were independently checked against Git: 97 for
the restore package and 98 for the identity package. The two package-verification
reports, three runtime reports and two independent cleanup readbacks live in
[evidence/sec200-dev-closure-2026-09-26](evidence/sec200-dev-closure-2026-09-26).

The first re-registration preparation refused before any account creation because
the operator used an invalid slash in the Lambda ARN resource format. The original
journal records `createAttempted=false`. Reviewed infrastructure fix
`f72d5a1b20bef17dddc86661f5a8fea7e8e2b3e3` uses the provider's colon format;
eleven boundary tests pass normally and with optimization. Read-only preflight
then passed against the unchanged fixture, and a fresh journal recorded the single
actual recreation. This was an operator defect, not a deployed deletion defect.
The failed preflight is retained separately from successful acceptance.

Independent cleanup confirms both sets of twelve fixture tables, both functions
and roles, and the disposable Cognito pool including the recreated identity are
absent. Both test HMAC keys are PendingDeletion until October 3; they are not yet
physically destroyed. Application tables, roles, handlers and admission gates were
not changed by this increment.

The remaining Dev evidence checklist is satisfied. Close SECUR4ALL-200 only after
both final PRs and their evidence are verified on remote `release-V01` and the
tracker reflects the actual POST/GET contract. SECUR4ALL-329 remains open for UAT;
SECUR4ALL-207 and SECUR4ALL-245 retain their own lifecycle/restore acceptance.
This record does not authorize or claim general admission, native backup recovery,
UAT or Production qualification, or native signup-trigger delivery.
