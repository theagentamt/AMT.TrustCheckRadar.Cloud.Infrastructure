# Shared maintenance: reconciliation with pinned main

This local increment selectively carries the required component controls from
infrastructure main `f1c5d36d565d1f6eb937d957605dc235f7867780` onto the release-based
maintenance proposal. The integration target remains `release-V01`; no whole-main
merge, publication, deployment or activation occurred. The immutable main tree is
`57c0090b3c83abdfeb98da04766c307ddbb9e4ce`. Connector source identity has been
resolved. The retained release tree equals its merge-base tree, so the three
release-only history commits contain no unique file content; their ancestry is
preserved. The original worktree remains intact.

The selective import comprises 13 Message/URL component files and eight verifier
and test files. Trial/operator/deletion definitions are required references of
the existing main component, not permission to activate those capabilities.
Workflows, tfvars, dependency locks and unrelated components are unchanged.

GET-only access snapshot selection remains sensitive, distinct from the original
trial selection and injected only into entitlements. It is not unioned into
consumer, deletion or recovery admission. The maintenance-only switch remains
default-off. An explicit combined fixture checks that enabling maintenance
preserves the existing snapshot/trial/deletion selections and closed URL gate.

Both candidate.1 and candidate.3 plan review now require the same-table versioned
maintenance configuration before active admission, including no-op plans.
Inactive rollback does not depend on a running worker. Legacy review also checks
both functions and aliases on no-op plans, rejecting unexpected runtime
attachments, malformed/weighted versions, failed/unknown checks and inconsistent
inventory. Candidate.3 retains its provider-free rules-only and History controls.
Neither verifier enables the proposed one-use AI exception; that future overlay
needs its own reviewed plan and permissions.

The maintenance object proves configuration consistency only. Its supplied hash,
version and booleans are not trusted AWS readback. Before rollout they must join
the actual same-table worker alias/code, environment, schedule, target, invocation
policy, least-privilege IAM and heartbeat/overdue alarms. Operational GET-snapshot
preparation/plan/readback remains a separate current-main control. No new live
readback, identity lookup or endpoint call was made in this reconciliation.

The official Python 3.14 ARM64 runtime gate is passed for the unchanged consumer
ZIP `11761fba…67e04` and evaluator ZIP `9823ebc4…415c` only. The durable runtime
packet records the complete hashes, Python 3.14.8/aarch64/glibc 2.34 imports,
33/23 schema definitions, fake-boundary safeguards and independent PASS. It does
not qualify a changed worker, other component ZIPs or future rebuilt bytes.

`authority-maintenance-reconciliation.json` records final test/review pins and
supersedes the old source-access/runtime blockers in the earlier readiness
packet. Earlier records remain dated evidence. All six mobile/cloud journeys
remain HOLD: no current operational readiness receipt, provider call or mobile
acceptance follows from local tests. See `authority-maintenance-next-actions.md`
for the exact staged proposal, irreversible cleanup and rollback limits.
