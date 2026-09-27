# SECUR4ALL-332: scheduled deletion counter serialization

On September 27, 2026 the owner reported the Dev Play token deletion Errors alarm
at 19:55:13 UTC for the 19:54 datapoint. Narrow read-only log inspection found
`TypeError: Object of type Decimal is not JSON serializable` in the handler's
final JSON summary. In the inspected 16:00–20:00 UTC window, CloudWatch recorded
120 invocation errors for each of Play token deletion and V1 authority deletion.
Adjacent Play full-pass summaries succeeded. No account content was inspected.

The shared reconciler reads validated checkpoint clocks from DynamoDB as Decimal.
A partial pass calculates a Decimal age; a full pass resets it to integer zero.
The logging exception happens after the cursor transaction can commit. Therefore
these invocation errors do not establish failed erasure, and successful adjacent
counts do not prove that every account is erased. Suppressing the alarm or simply
stringifying arbitrary data would conceal the defect.

## Reviewed source and immutable artifacts

Lambda PR78 integrates `9123459a5c2bc9503d56235b2cb1f1e162c00da1` into
`release-V01` at `73362dbddcf3511db7091142ad8ec69205d1e206`. Two integer casts
normalize only already-validated clocks; validation, checkpoint values, cursor
CAS, cleanup, retention and receipts are unchanged. All 84 affected SDK cases
passed, including 14 new handler/partial-pass regressions independently rerun.

The current Lambda release also contains unrelated changes. To avoid upgrading
those, the two correction archives preserve the exact deployed
`39cce61623794a123e61d25f5248b0c081eccf4a` archive member sets and every unrelated
member byte. Only `v1_authority_deletion/service.py` changes in Play; V1 also has
the matching root `service.py` copy. Both replacements exactly match the reviewed
Git blob. These are explicitly mixed-provenance corrections, not complete builds
of the newer source tree.

[Package evidence](evidence/sec332-deletion-packages.json) records baseline S3
versions/hashes, patch source/blob, new versions/hashes, changed members, counts
and the full member-manifest hash. Both archives were independently compared
against the actual downloaded baseline, then published with conditional
create-only writes and SHA256 checksums. Exact uploaded versions were downloaded
and hash-verified. Offline disabled-handler checks passed; they are not live
deletion acceptance.

## Infrastructure selection and deployment boundary

Both roots retain their original single-release package maps. A separate optional
deletion-only override binds the baseline source/hash, patch source, exact function
key, version, hash and reviewed provenance. Activation must match the effective
selected source. Null preserves existing behavior. This allows the correction
without replacing any sibling package or weakening their single-release checks.
The existing subject scopes, triggers, alarm settings, IAM, environments, runtime
and resource limits remain unchanged. No new account operation is authorized.

Local mocked Terraform suites passed: 32 Play lifecycle cases and 38 URL consumer
cases. The initial non-Dev tests over-specified multiple expected failures when
Terraform stopped at an earlier validation; expectations now name the actual
first guard. These are mock checks, not AWS behavior. Existing provider deprecation
warnings are unrelated to this correction.

[Saved-plan scope](evidence/sec332-reviewed-plan-scope.json) records exactly one
function and its live alias updated per root, no creates/deletes and no other
resource changes. Before/after environments, roles, architectures, handlers and
limits were compared privately. Saved plans contain state-derived values and are
not published. Independent exact-plan review and source integration precede apply.

## Runtime acceptance and rollback

After approved Dev apply, verify both live code hashes against the manifest and
unchanged settings against the saved plans. Observe natural scheduled invocations
on each installed version until both a positive integer partial-pass age and a
zero-age full pass appear. Confirm no further invocation errors in that observation
window, heartbeat/full-pass metrics continue, and alarms recover through their
normal evaluation. Do not inject account commands, change allowlists, silence
alarms or manually manufacture an OK state. Run fresh full plans for no drift.
Record timestamps, versions, counts and failures without customer data.

Rollback, if needed, selects the original pinned deletion artifact and its
matching activation source, removes the optional override, and applies a reviewed
saved plan. It preserves settings and acknowledges that the old serialization
bug returns. UAT/Production and main remain unchanged. Any later release
qualification follows the existing account-deletion/Play handoffs; this incident's
required scheduled Dev verification cannot be replaced by a manual follow-up.

At this document's initial source review the archives are published and the plans
are prepared; apply and runtime recovery have not yet occurred. Append actual
execution evidence below rather than treating plan success as runtime success.


## Applied and verified — September 27, 2026

Infrastructure PR108 integrated source
`a8e765d271f7e358df927d96409ebfbdbac17d56` at release merge
`468d0ff3db9a1f49d04a2453d2c3f6cac317221b`. Both independently reviewed saved
plans applied successfully: zero additions, two updates and zero destructions
per stack. Full follow-up plans both returned detailed exit code zero/no drift.
See [apply evidence](evidence/sec332-apply-and-no-drift.json).

[Installed configuration readback](evidence/sec332-runtime-readback.json) confirms
Play token deletion live version **13** and V1 authority deletion version **18**,
with the reviewed package hashes. All seven functions in the two roots matched
their intended hashes; the five sibling packages remained unchanged. Environment,
role, runtime, handler, architecture, timeout, memory and reserved concurrency
matched the before-plan values. Aliases have no weighted routing.

The [natural scheduled observation](evidence/sec332-scheduled-recovery.json)
starts at 20:15:21 UTC and records both partial and complete passes on each new
version, with integer counters, zero reported failed items and no error log events.
Partial ages include 55 seconds for Play and 63 seconds for V1; complete passes
return zero. No invocation was injected and no account operation was replayed.
The Lambda Errors metrics report zero in the first complete-minute window after
the readback. Both native Errors alarms are **OK**, with normal zero-error
threshold evaluations, not missing-data/manual state overrides. This finite
window demonstrates the corrected path, not a guarantee of no future failures.

[Operational metric readback](evidence/sec332-operational-metrics.json) separately
confirms both heartbeat and full-pass-age metric streams continue, including
positive ages and zero completion ages. SNS and alarm configuration are preserved;
this does not claim that the owner has read a recovery email.

No UAT/Production deployment, main promotion, retention adjustment, subject-scope
change, paid provider request or physical test occurred. Before later release,
reuse [SECUR4ALL-329](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-329): record
exact promoted artifacts/configuration and include at least one scheduled partial
checkpoint followed by a completed pass on both workers. Confirm numeric ages,
zero invocation/failed-item errors, continuing heartbeats and normal alarm states.
Use that existing synthetic-account release plan; do not mutate checkpoints or
introduce production accounts solely to fabricate this case. Engineering must
supply a bounded fixture if the target environment has no partial traversal.
This adds a release regression to existing qualification; Dev scheduled acceptance
above is already complete and is not deferred to that follow-up.
