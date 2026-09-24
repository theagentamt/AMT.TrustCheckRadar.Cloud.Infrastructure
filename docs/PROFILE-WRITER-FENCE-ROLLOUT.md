# Dev profile-writer fence qualification and rollout

The signup post-confirmation and age-attestation writers must both respect the
fixed account-deletion ledger entry before whole-account deletion is activated.
They are active service paths. A source pin alone does not prove either live
behavior or a safe permissions transition.

## Scoped permissions

Final signup permission is users-table PutItem within TransactWriteItems;
final age permission is users-table UpdateItem within TransactWriteItems. Both
are restricted to USER# partitions. The paired ledger grant is ConditionCheckItem
on the same Dev ledger and ACCOUNT# partitions, with ReturnValues restricted to
NONE when supplied. No ledger mutation, user read, Cognito deletion or provider
permission is added by the final policies.

The [AWS service authorization reference](https://docs.aws.amazon.com/service-authorization/latest/reference/list_dynamodb.html)
does not list EnclosingOperation for ConditionCheckItem, although the
[transaction guide](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis-iam.html)
includes it in a generic example. Earlier live IAM simulation rejected that
combination. These policies omit it on ConditionCheckItem and retain the documented
ForAnyValue:StringEquals TransactWriteItems condition on user writes. Isolated
actual-role transactions and denied standalone writes must qualify this choice;
mock policy shape alone is insufficient. ConditionCheck has no standalone mutation
API. The existing user/ledger account-region-environment checks apply during
preparation as well as final source selection and use actual caller identity.

## Three-stage Dev sequence

1. **Prepare:** select `profile_fence_transition_enabled=true`, leaving both
   source selections null. This adds exact ledger configuration and the bounded
   condition-check grant while preserving each old writer's users permissions.
   Review/apply both complete stack plans and read back env/IAM before proceeding.
2. **Install:** keep transition true and select exactly the independently qualified
   immutable post-confirmation and age-attestation packages. Select Python3.14
   ARM64 explicitly. Verify both hashes, runtime, environment, successful update
   status and unchanged Cognito trigger map. Existing code must be compatible with
   preparation; neither install may depend on an unprepared grant/configuration.
3. **Tighten:** after both installs are verified, wait beyond the larger old/new
   configured invocation timeout after the last successful update (with margin),
   then set transition false while retaining both artifact pins. Review/apply
   permission-only plans, verify installed grants/denials, and require full fresh
   no-drift plans. No local-exec Cognito trigger update is expected in this stage.

Transition mode is rejected outside Dev. The outputs separately report transition
and transactional-permission selection; `*_fenced` records source selection, not
live acceptance. Do not enable deletion/export/finalization, insert inventory
approval markers, or infer completion from this deployment. Other profile writers,
legacy data/restore paths and subject mapping retain their separate acceptance.

Rollback also needs sequencing: if final IAM is installed, restore transition
permissions before selecting an older package, and retain required ledger env
until the old package is verified. Do not roll back to an unfenced writer after
account deletion has been activated. This procedure authorizes no UAT/Prod change.

## Validation boundary

Terraform tests cover unchanged defaults, source/config pinning, supported action
conditions, caller/table ownership, the prepare/install/tighten distinctions and
rejection of production transition. The synthetic live qualification substitutes
only users/ledger table Resource ARNs in the actual rendered final policies;
all actions and conditions remain identical. Its temporary roles trust only the
current exact IAM principal and receive no application-resource access. Fixtures
are synthetic, have no streams/PITR, and are removed with their roles afterward.
This proves IAM/transaction behavior, not real signup or completed account erasure.

Any plan rendered with `qualification-not-for-deployment` artifacts is exclusively
for extracting policies; never apply it. Real rollout plans require published
archive/version/hash verification and independent review first.

## Executed IAM qualification, 2026-09-23

The frozen harness passed all 14 actual-role cases against synthetic tables,
including positive atomic writes, denied standalone/cross-partition/ledger writes,
denied old-value return, and tombstone cancellation without mutation or returned
item contents. The exact production ledger sort-key shape was used. Both temporary
roles and both tables were deleted; cleanup completed with no outstanding resource.
The first earlier run also passed/cleaned up but used a generic fixture sort key;
this final evidence supersedes that fixture-shape limitation.

[Sanitized evidence and exact rendered source policies](evidence/profile-writer-fence-2026-09-23/synthetic-iam-qualification.json)
preserve source-policy hashes and the executed harness hash. Five local harness
tests verify policy validation, resource-only substitution and meaningful denial
classification. No real account or application-table item was accessed.
