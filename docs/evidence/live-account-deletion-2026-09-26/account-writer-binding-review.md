# Current Dev account writer binding

Observed 2026-09-26T14:55:18.615093+00:00; fresh metadata collection completed in 31.29 seconds. All 31 functions and 31 execution roles were enumerated, including every published version/alias and all 13 tables. Current function configurations were unchanged on final reread. No application records, secrets, tokens or user identifiers were read. No invocations or mutations.

Current account-data hash matches reviewed `65df9c7e7fe338f00df8ecc13795014ab928cdfa`; deletion, finalizer and recovery-write gates are false. This supersedes its older binding.

## Current-source binding

| Function | Source | Artifact binding |
|---|---|---|
| play-token-deletion | 39cce61623794a123e61d25f5248b0c081eccf4a | current immutable Dev artifact hash |
| history-mutation-api | c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca | current immutable Dev artifact hash |
| campaign-participation | d98ffd65b42d54953ad83e980e58846b6fc02c5d | current immutable Dev artifact hash |
| purchase-handoff | d98ffd65b42d54953ad83e980e58846b6fc02c5d | current immutable Dev artifact hash |
| device-recovery | 8d25e19b691d82caf630edc7ebd84c0b45de0c5c | current immutable Dev artifact hash |
| device-registration | 8d25e19b691d82caf630edc7ebd84c0b45de0c5c | current immutable Dev artifact hash |
| history-account-deletion-bridge | 997e265f7edf10ce7369481f7d576b4276e8c418 | current immutable Dev artifact hash |
| url-lease-recovery | 39cce61623794a123e61d25f5248b0c081eccf4a | current immutable Dev artifact hash |
| url-consumer | 39cce61623794a123e61d25f5248b0c081eccf4a | current immutable Dev artifact hash |
| campaign-review | 218769da5b482f98b8cb7e0be93d16e656c38c3e | prior byte-exact deployed ZIP audit |
| v1-entitlements | 39cce61623794a123e61d25f5248b0c081eccf4a | current immutable Dev artifact hash |
| post-confirmation | c4b1cae34b9a90a9803022302a6ad7f2d8a13e38 | current immutable Dev artifact hash |
| v1-authority-deletion | 39cce61623794a123e61d25f5248b0c081eccf4a | current immutable Dev artifact hash |
| campaign-lifecycle | f92285b50561397355a5fe2e466d297041336755 | current immutable Dev artifact hash |
| campaign-cluster-aggregator | f92285b50561397355a5fe2e466d297041336755 | current immutable Dev artifact hash |
| v1-play-handoff | 39cce61623794a123e61d25f5248b0c081eccf4a | current immutable Dev artifact hash |
| url-resolver | url-resolver-py314-dev-20260920-d107988b4412 | current immutable Dev artifact hash |
| play-lifecycle-worker | 39cce61623794a123e61d25f5248b0c081eccf4a | current immutable Dev artifact hash |
| age-attestation | c4b1cae34b9a90a9803022302a6ad7f2d8a13e38 | current immutable Dev artifact hash |
| campaign-deletion-bridge | f92285b50561397355a5fe2e466d297041336755 | current immutable Dev artifact hash |
| campaign-trends | not established here | metadata only; no current reviewed source pin established here |
| campaign-observation-publisher | f92285b50561397355a5fe2e466d297041336755 | current immutable Dev artifact hash |
| entitlement-snapshot | d98ffd65b42d54953ad83e980e58846b6fc02c5d | current immutable Dev artifact hash |
| play-lifecycle-ingress | 39cce61623794a123e61d25f5248b0c081eccf4a | current immutable Dev artifact hash |
| conversation-analysis | d98ffd65b42d54953ad83e980e58846b6fc02c5d | current immutable Dev artifact hash |
| url-assessment | 84733306d62dd57df883b4425fa5305db6c4a62d | current immutable Dev artifact hash |
| web-risk-communication | d98ffd65b42d54953ad83e980e58846b6fc02c5d | current immutable Dev artifact hash |
| account-export-api | e1651f86e30fc1478f69ba16a4049be8baf0e5f3 | current immutable Dev artifact hash |
| account-data-api | 65df9c7e7fe338f00df8ecc13795014ab928cdfa | current immutable Dev artifact hash |
| history-lifecycle | 997e265f7edf10ce7369481f7d576b4276e8c418 | current immutable Dev artifact hash |
| history-read-api | c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca | current immutable Dev artifact hash |

29 installed code hashes match current immutable Dev Terraform selections; campaign review has the prior byte-exact deployed ZIP audit. Campaign trends is metadata-only in this increment and has no DynamoDB mutation Allow on these13 stores. Resolver uses the reviewed named artifact release rather than a full Git SHA; it also has no table mutation Allow.

## Installed writer inventory

This table retains conditional Allows and subtracts only unconditional action Denys. It is a potential identity-policy writer list, not a claim of runtime reachability or IAM simulation. Complete statement conditions, attached/inline names, hashes and table resource policies are in the metadata JSON. All 31 roles have no permissions boundary. SCPs/session policies and arbitrary same-account operator policies are outside this audit.

| Store | Potential role-bound functions |
|---|---|
| users | campaign-participation, post-confirmation, age-attestation, campaign-deletion-bridge, account-data-api |
| deletion-ledger | play-token-deletion, campaign-participation, history-account-deletion-bridge, v1-authority-deletion, campaign-deletion-bridge, account-data-api, history-lifecycle |
| analysis-abuse-control | history-mutation-api, account-data-api, history-lifecycle |
| device-bindings | device-recovery, device-registration, account-data-api |
| purchase-entitlements | url-lease-recovery, url-consumer, v1-entitlements, v1-authority-deletion, v1-play-handoff, play-lifecycle-worker, play-lifecycle-ingress, account-data-api |
| web-risk-cache | none after unconditional identity Denys |
| device-recovery-control | device-recovery, account-data-api |
| campaign-outbox | account-data-api |
| campaign-pipeline | campaign-lifecycle, campaign-cluster-aggregator, campaign-deletion-bridge, campaign-observation-publisher |
| campaign-intelligence | campaign-review, campaign-lifecycle |
| history-content | history-mutation-api, history-lifecycle |
| history-control | history-mutation-api, history-account-deletion-bridge, history-lifecycle, history-read-api |
| play-tokens | play-token-deletion, v1-play-handoff, play-lifecycle-worker, play-lifecycle-ingress |

## Guard coverage and remaining actions

- Device registration has one published `$LATEST` and no aliases. Exact installed `8d25e19` source builds all binding mutations in a transaction containing ACTIVE/age-verified authoritative profile and absent ACCOUNT_DELETION checks. Device recovery is false; its exact same release wraps binding/control writes in those checks. Existing device-table IAM remains broad; safety is the bound handler transaction, not an IAM promise that unguarded writes are impossible.
- Active profile writers are exact `c4b1cae` post-confirmation and age-attestation. Cognito points PostConfirmation at that unqualified installed function. Profile Put/Update grants require a transaction; source adds absent ACCOUNT_DELETION. Neither has older published versions. Existing reviewed profile qualification is reused, not rerun.
- Legacy conversation analysis, purchase handoff, entitlement snapshot and direct Web Risk have the installed migration Denys. In particular unconditioned DenyLegacySettlementAndWrites wins over older broad writer Allows. Participation has consent and recovery writes false. Current History reads/mutations/writes/recognition/replay and lifecycle/deletion processing are all false.
- Authority, entitlement consumer, Play handoff/worker/ingress and deletion aliases are closed and have no weighted routing. Every current scheduled rule and Scheduler target inspected is disabled. Current API routes and stream mappings do not target the four enabled historical versions.
- Retained versions url-consumer:3, v1-entitlements:3, url-lease-recovery:3 and v1-authority-deletion:2 still embed true activation flags. They are not selected by aliases or current trigger targets and have no version-specific resource policy. **Controlled invocation boundary:** no current managed ingress targets these old qualified versions. The serialized root operator must not invoke or rebind them. Privileged operator ability alone is not a current cleanup blocker under that boundary. Any role, source, version/alias, trigger or restore change invalidates the binding and requires refresh before relying on it. This audit does not infer unauthorized public access.
- **Future History activation gap:** exact installed c039 History read CursorStore.create does standalone conditional CURSOR# Put after preflight account checks. That Put lacks an atomic account-deletion guard and could arrive after cleanup if reads were reopened. Current reads are false and no historical versions exist, so this is a future activation prerequisite, not a current cleanup blocker. Keep reads closed until that cursor admission path is fenced or explicitly included in bounded expiry/cleanup policy.
- Campaign review remains an active existing-aggregate CAS writer. The prior byte-exact ZIP audit proves no creation of a missing aggregate; it has no restore-generation fence. Preserve the existing restore-quarantine boundary. Campaign pipeline producers/cleanup gates and mappings remain closed; reuse the root refreshed campaign audit for the settled boundary.
- Preserve existing approved entitlement audits and usage. The authority key inventory/cursor-schema and legacy-entitlement schema audits are references, not new deletion candidates or proof of historical erasure.

## Evidence and limitations

- `/tmp/amt-account-writer-binding.json`: full sanitized metadata, policy mutation union, versions, aliases, API routes, Cognito trigger and stream targets.
- `/tmp/amt-account-writer-source-bindings.json`: exact observed codehash/current Dev pin matches, source refs/file hashes and per-store writer mapping.
- `/tmp/amt-account-writer-old-versions.json`: separate old-version allowlist counts, resource-policy presence and explicit rule/schedule targets.
- Source identity is bound through reviewed immutable deployment hashes/current Terraform selections and prior qualification. This audit did not rebuild or redownload all31 packages. It does not assert account-wide absence of arbitrary privileged IAM writers, historical copies, or storage erasure. It creates no approval/inventory marker.
