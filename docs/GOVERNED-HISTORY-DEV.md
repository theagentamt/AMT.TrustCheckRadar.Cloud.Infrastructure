# Candidate.3 rules-only and governed History — Dev source handoff

Epic [SECUR4ALL-336](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-336)
coordinates Lambda SEC337/338, infrastructure SEC339, Android ATCR163 and assembled
Dev qualification SEC340. This page describes source and future test execution.
It grants no deployment, activation, account mutation or release authority.

## Source boundary

Candidate.3 deterministic execution is independently selected with
`MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED` on both message functions. The consumer
still enforces authenticated adult account, active device, paid/trial/complimentary
access and original scan allowance. AI remains disabled and unqualified; the
provider circuit remains closed. The evaluator role explicitly denies invocation
of the private URL-assessment alias in this mode and retains its provider-secret
denial. Reviewed links do not trigger Google or AI: unsupported evidence produces
an honest inconclusive, uncharged result. Candidate.1 engineering and full AI
qualification are different modes.

Governed History reuses settled authority receipts. Foundation owns a sparse
`GSI2` (string `GSI2PK`/`GSI2SK`) whose INCLUDE attributes are only `recordType`,
`state`, `governedHistory`, `expiresAt`, plus automatic table/index keys. It is
absent by default. No legacy History table, queue or writer is activated.

The isolated Python3.14 ARM64 reader has concurrency 2 and a 23-second timeout
within the 29-second API integration. This allows bounded index queries, at most
20 canonical reads and both identity-fence passes under the shared one-attempt
SDK timeouts. The reader owns exactly:

- `GET /v1/users/analysis-history`
- `GET /v1/users/analysis-history/{resultId}`

Both use the existing Dev JWT authorizer and account/device/deletion fences.
`GOVERNED_HISTORY_LIST_ENABLED` and `GOVERNED_HISTORY_DETAIL_ENABLED` are separate;
`GOVERNED_HISTORY_SETTLEMENT_ENABLED` independently controls receipt projection.
Active reader IAM restricts identity reads to the one approved Dev subject,
receipt/index reads to that subject’s retained HMAC partitions, and every read to
explicit permitted attributes. Inactive reader IAM permits only logging.
Readers do not require a currently paid allowance and never consume checks.
They cannot write, scan, invoke a provider, mutate badges or export data.
`HISTORY_READS_ENABLED` and legacy History export remain unchanged.

Receipt projection stores typed codes, original outcome, original immutable
accounting and fixed clocks. No screenshot, original/sanitized message, submitted
URL, entity token, operation proof, identity document or AI prose is added.
The seven-day deadline starts at the original settlement. Retry, list, lookup and
presentation never extend it. Index queries are bounded and request the exact
narrow projection with `Select=SPECIFIC_ATTRIBUTES`; each returned candidate is
checked against a strongly consistent canonical receipt. Expired/deleted/stale
rows are suppressed. TTL physical removal is asynchronous; application deadline
checks suppress access without waiting for TTL.

Cursor lifetime is 15 minutes. Signed stateless cursors bind account, active
binding generation, retained key inventory and contract. No cursor table/copy is
created. Existing authority backups retain the previously disclosed backup
window; activation must verify the current PITR settings rather than assuming a
new retention policy. No live account deletion or export admission changes are
part of this source increment. Existing erasure and restore/deletion controls
must handle the new optional receipt fields before activation.

AWS fine-grained Query constraints are documented in
[the DynamoDB condition reference](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/specifying-conditions.html).

## Reviewed CI/CD stages

Infrastructure and Lambda integrate into `main`; Android/iOS remain on
`release-V01`. Main-only CI remains unchanged. The new manual workflow
`.github/workflows/governed-history-dev.yml` runs only on main, only in Dev, with
an exact infrastructure revision and exact account/state coordinates. It does
not run on a push or PR. It publishes no raw plan, subject list or state artifact.

1. Integrate/review source and qualify Lambda main CI and immutable ARM64 package
   publication. Installation and behavior are separate from ZIP publication.
2. Select exact immutable S3 keys, object versions and SHA256 for the reader and
   message functions; verify producer commit, source contract and successful CI.
   Configure metadata-only Dev variables `GOVERNED_HISTORY_DEPLOYMENT_JSON` and
   `MESSAGE_CANDIDATE3_DEPLOYMENT_JSON`. Secret
   `GOVERNED_HISTORY_ENGINEERING_SUBJECTS_JSON` holds exactly one authorized
   disposable synthetic Cognito UUID. Do not put subjects in public source. The runner derives private account
   partitions from the exact existing AWSCURRENT authority key ring in memory;
   the synthetic subject and derived partitions enter its private 0600 variable
   file and Terraform state. HMAC key material is
   never printed or persisted by this helper. Rotation requires a fresh reviewed
   plan covering every retained partition before access is qualified.
3. Review/persist the intended foundation index flag in the Dev configuration
   source before approved index creation. The ordinary foundation workflow
   refuses any GSI2 creation/removal/key/projection change; it permits steady
   state. Leaving its persisted flag false after creation blocks ordinary future
   deployments rather than silently removing GSI2.
4. Dispatch **plan** for scope `index`, mode `active`. The verifier permits only an
   in-place authority-table index/key-attribute change, preserves existing
   indexes and positively verifies TTL/PITR/billing/account identity. Obtain
   separate approval of that exact digest before dispatching **apply**. Wait for
   GSI2 ACTIVE; verify exact projection, TTL and PITR via configuration reads.
5. Plan scope `reader`, mode `inactive`, with the qualified immutable package.
   Verify the existing reader role has no extra attached/inline policies before
   planning and again immediately before apply. Only first inactive provisioning
   may accept an absent role; activation requires the installed role. Review exact
   default-off IAM/runtime/JWT routes and digest before apply. It
   cannot activate list/detail merely by provisioning routes.
6. Scope `message`, mode `rules-only`, enables candidate.3 for the exact subject
   without History settlement. `rules-only-history` additionally permits atomic
   projection after the index is positively verified. Scope `reader`, mode
   `list`, `detail` or `both` enables only those operations after index verification.
   Every apply requires the digest produced at the same reviewed revision,
   scope and mode; changed variables/source/state require a new review.
7. Apply uses the saved verified plan, then reads back exact versions/hashes,
   environments, concurrency, reader/evaluator IAM, JWT route targets and any
   required active index, and requires zero drift. This is configuration evidence,
   not behavioral or Android acceptance evidence.

The existing message workflow rejects the new candidate.3/History switches.
It cannot bypass the new exact IAM/receipt boundary by selecting candidate.1.
No API, function, alias, index, GitHub variable or subject is changed by this page.
UAT and Production provisioning/activation are rejected for this increment.

## Rollback

Use separately reviewed main workflow plans; no console edits/manual AWS apply.
Disable reader access and message admission/projection by planning their
`inactive` modes, with empty subject allowlists and the exact qualified pinned
artifacts. The evaluator's legacy URL permission is restored only while all
message admission/execution gates are closed. Preserve cleanup and existing
retention. Keep the sparse index and typed receipts until their fixed deadline;
removing the index requires its own `index/inactive` reviewed plan and must never
precede disabling dependent readers/settlement. Persist the corresponding Dev
foundation source flag so later ordinary deployment remains consistent.
Verify readback/zero drift and remove temporary subject configuration after the
approved test. Disposable-account deletion requires its own authorization.

## Pending assembled acceptance

[SECUR4ALL-340](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-340) retains
all unexecuted scoped Dev activation and Android emulator acceptance. Existing
[SEC334](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-334) and
[ATCR62](https://andmorethings.youtrack.cloud/issue/ATCR-62) retain later release
qualification. Physical testing remains in ATCR148 and is not requested now.

Use only approved disposable adult Dev account/device binding and its explicitly
activated 7-day/10-completed-check trial. Do not invent account identifiers or
create/delete accounts from these instructions. Exact qualified contract fixtures
come from Lambda `contracts/message-consumer/1.0.0-candidate.3` and
`contracts/governed-history/1.0.0-candidate.1`. Android ATCR163 must first consume
the governed schema; legacy score History cannot qualify this journey.

Pending test sequence: EN/ES synthetic deterministic no-link prepare/submit;
same-proof reconciliation/retry; list History; restart emulator/app; direct
result lookup; repeat list/detail. Expect one logical completion, one settled
receipt/entry and at most one check deduction, zero provider calls, original
accounting on reopen and no retained message/URL/image. Include inconclusive and
hostile no-charge outcomes, partial result visibility, four-key rotation paging,
expired/stale canonical rows, cursor expiry/tamper/cross-account/device-generation
change and expired Google evidence fixtures without calling Google. Verify
original outcome/accounting versus the separate current presentation.

No assembled runner/activation has run for this epic yet. Attach privacy-safe
status/count evidence, exact commits/packages/contracts/flags, rollback readback
and test results to SEC340. Never call local fixtures live qualification, a
configuration readback a behavioral test, or Android emulator evidence physical
or real store transaction evidence.

Reader planning and immediately-before-apply preflight reject extra managed or
inline role grants and extra Lambda resource-policy invoke grants. Only the two
exact API Gateway route source statements are permitted on the `live` alias;
unqualified function invoke policy grants are rejected. First inactive
provisioning may lack the role/alias policy. Active preflight and post-apply
readback require the exact policies. These configuration checks do not replace
SECUR4ALL-340's JWT and cross-account behavioral qualification.

## Source qualification (before deployment)

Local infrastructure validation passed 297 helper tests, 14 foundation mock
Terraform tests, 16 message mock tests and eight reader mock tests. Terraform
1.12.1 generated and the verifier accepted actual plans for inactive, list-only,
detail-only and combined reader modes using a localhost STS fixture. These used
synthetic metadata, no AWS connection and no deployed resources. YAML/shell
syntax, formatting and diff checks passed. Independent review covered the
Lambda source and infrastructure permission/activation boundaries. Source
publication, main CI and future exact artifact selection are separate evidence.

SECUR4ALL-340 owns the unperformed Dev installation and assembled emulator
qualification; ATCR-163 owns Android History integration. Later release testing
remains linked through SECUR4ALL-334 and ATCR-62. No physical device testing is
required to close the source implementation stories.

## SEC340 live prerequisite audit

The first Dev CI/CD index plan (37136301426) was rejected before apply because
Cognito's computed estimated user count changed from its saved state. A private
read-only diagnostic showed only that telemetry drift and one planned authority
GSI2/key-attribute update. The verifier now accepts only a count-only refresh for
the exact Dev pool when its resource plan is no-op; pool configuration drift,
other resource drift and any pool mutation are still rejected. This does not
change Cognito or weaken the index-only apply scope. The Dev foundation source
flag is persisted before the separate guarded apply; ordinary deployment still
rejects index creation/removal. No GSI2 or reader is claimed deployed by this note.

SEC340 access preparation uses scope `access`, mode `trial`, with the same private
one-subject selection. It changes only that subject's entitlements admission and
the already-approved explicit-trial gate on the existing function and live alias.
The original trial workflow also enabled lease maintenance and expanded the
deletion worker subject set, so it is not used for this qualification. The new
`governed_trial_subjects` selection never enters deletion, URL execution or
maintenance. All packages, routes, IAM, existing deletion scope, operator access
and background controls must remain unchanged; live drift fails closed. Plan,
exact-digest approval, apply and readback remain separate. Roll back with this
scope's `inactive` mode, preserving any already-created trial eligibility record.
