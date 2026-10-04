# Candidate.3 rules-only and governed History — Dev source handoff

Epic [SECUR4ALL-336](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-336)
coordinates Lambda SEC337/338, infrastructure SEC339, Android ATCR163 and assembled
Dev qualification SEC340. This page describes the source, deployment procedure
and current qualification status; historical pre-apply notes are identified below.
It grants no deployment, activation, account mutation or release authority.

## Source boundary

Candidate.3 deterministic execution is independently selected with
`MESSAGE_CANDIDATE3_RULES_ONLY_ENABLED` on both message functions. The consumer
still enforces authenticated adult account, active device, paid/trial/complimentary
access and original scan allowance. AI remains disabled and unqualified; the
provider circuit is open (`MESSAGE_PROVIDER_CIRCUIT_OPEN=true`), blocking dispatch. The evaluator role explicitly denies invocation
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
   dedicated synthetic Cognito UUID. The current fixture is an existing reusable
   account, preserved through testing and rollback. Do not put subjects in public
   source. The runner derives private account
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

## Current qualification and remaining assembled acceptance

[SECUR4ALL-340](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-340) retains
the assembled Dev engineering acceptance. Android EN/ES normal-app phases
passed. On October 3, 2026, the owner instructed “no rollback”: the existing
dedicated-account rules-only Dev scope stays enabled, replacing the post-test
inactive-apply acceptance criterion. Evidence integration and tracker closure
are required; no rollback, empty allowlist or removed selection is claimed.
Backend activation and rules-only EN/ES qualification passed. Existing
[SEC334](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-334) and
[ATCR62](https://andmorethings.youtrack.cloud/issue/ATCR-62) retain later release
qualification. Physical testing remains in ATCR148 and is not requested now.

Use only an approved adult synthetic Dev account/device binding. The current
SEC340 fixture is an existing dedicated reusable account with its existing
7-day/10-completed-check trial. Use the runner
`--fixture-mode dedicated_reusable`; never activate/reset its trial or delete
this account. New minimized receipts keep their original seven-day deadlines.
A disposable fixture requires separate explicit creation/deletion authority and
its corresponding runner mode. Do not invent identifiers from these instructions. Exact qualified contract fixtures
come from Lambda `contracts/message-consumer/1.0.0-candidate.3` and
`contracts/governed-history/1.0.0-candidate.1`. Android ATCR163 must first consume
the governed schema; legacy score History cannot qualify this journey.

The EN/ES backend synthetic no-link prepare/submit, same-proof reconciliation,
retry and list/direct lookup sequence passed. The subsequent Android Dev phases
also passed: submission through the app, History entry, real app restart and
direct reopen in EN/ES across reviewed windows.
A separate connected reader/decoder/cache test does not by itself prove that UI
journey. For both completed and remaining cases, expect one logical completion,
one settled receipt/entry and at most one check deduction, zero provider calls, original
accounting on reopen and no retained message/URL/image. Include inconclusive and
hostile no-charge outcomes, partial result visibility, four-key rotation paging,
expired/stale canonical rows, cursor expiry/tamper/cross-account/device-generation
change and expired Google evidence fixtures without calling Google. Verify
original outcome/accounting versus the separate current presentation.

The scoped backend activation and EN/ES rules-only runner have now passed;
[current evidence](evidence/sec340-governed-history-dev/README.md) records exact
source, apply runs and counters. Android acceptance and rollback status are
tracked there independently. Attach privacy-safe
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

## Historical source qualification before deployment

Local infrastructure validation passed 297 helper tests, 14 foundation mock
Terraform tests, 16 message mock tests and eight reader mock tests. Terraform
1.12.1 generated and the verifier accepted actual plans for inactive, list-only,
detail-only and combined reader modes using a localhost STS fixture. These used
synthetic metadata, no AWS connection and no deployed resources. YAML/shell
syntax, formatting and diff checks passed. Independent review covered the
Lambda source and infrastructure permission/activation boundaries. Source
publication, main CI and future exact artifact selection are separate evidence.

At this pre-apply stage, SECUR4ALL-340 owned Dev installation and assembled
emulator qualification. Installation and backend qualification have since
passed; ATCR-163 owns Android History integration and its remaining acceptance. Later release testing
remains linked through SECUR4ALL-334 and ATCR-62. No physical device testing is
required to close the source implementation stories.

## Historical SEC340 prerequisite audit before apply

The first Dev CI/CD index plan (37136301426) was rejected before apply because
Cognito's computed estimated user count changed from its saved state. A private
read-only diagnostic showed only that telemetry drift and one planned authority
GSI2/key-attribute update. The verifier now accepts only a count-only refresh for
the exact Dev pool when its resource plan is no-op; pool configuration drift,
other resource drift and any pool mutation are still rejected. This does not
change Cognito or weaken the index-only apply scope. The Dev foundation source
flag is persisted before the separate guarded apply; ordinary deployment still
rejects index creation/removal. This pre-apply note was not deployment evidence. Later approved runs created
the index and installed/activated the scoped reader as recorded in current evidence.

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


## SEC340 first-read provider normalization

Index apply `37141414785`, access-only apply `37142537394`, inactive reader
apply `37143161640`, and rules-only message/settlement apply `37143163547`
succeeded through reviewed Dev CI/CD at infrastructure main
`ff4b05c542bbec9c8d81f623b9fe3d3dbd276cda`. Each passed configuration
readback and zero drift at its apply stage. These are installation/configuration
checks; no live analysis or Android restart journey is qualified by them.
The installed reader and message ZIPs use qualified Lambda main
`6d9ae503b7d4e36a16a4cfc6bee2c939b988c723`, main CI `37142525442`, and
immutable publication `37142703658`. Exact S3 versions/checksums remain the
workflow deployment inputs, with independent S3 HEAD verification.

Subsequent reader activation plan `37143266035` and message rollback plan
`37143461315` failed closed before apply. Private read-only diagnostics identified
only initial AWS provider collection normalization and the IAM role's computed
view of a separately managed inline policy. No raw plans, account identifiers,
environments, or policy subjects belong in public evidence.

The reader verifier accepts only the observed null-to-empty request maps on the
exact existing API integration/routes, tags on the exact reader log group/role/
function, and empty function layers. Each drift entry must bind the exact current
managed resource. Only the reader function may also undergo its independently
validated activation update; other normalization resources stay no-op. The full
reader inventory still checks exact runtime/source, routes, trust, permissions,
limits, and account/device gates. Reverse, nonempty or additional field drift
remains rejected.

For reader and evaluator roles, the computed inline-policy view must contain
exactly the single owned policy and match the separately managed policy's current
`before` JSON. The previous view may contain no policy or only that same owned
current/target policy. Unexpected grants, names, role trust, current-policy drift,
other roles and provider identities remain rejected. The desired reader/evaluator
policy is validated separately, including the evaluator's exact policy name.
Observed normalized drift stays in the authoritative reviewed-plan digest; only
the already-validated evaluator view is removed from the legacy compatibility
verifier's temporary copy.

The corrected main revision is `990e66e8c0b8a9dcc2dcb114745b015655f4e43f`.
Owner-approved reader activation apply `37146970010` passed exact readback and
zero drift. Reader list/detail are enabled for the dedicated account only;
AI and providers remain blocked. Backend qualification produced four results,
two charged and two inconclusive/uncharged. The original trial clock and
eligibility are preserved; used/reserved/remaining moved from 1/0/9 to 3/0/7.
No trial activation/reset, account creation/deletion, UAT or Production change
occurred in that backend window. Subsequent Android normal-app EN/ES phases passed
across reviewed windows, and PR68 is integrated into `release-V01` at
`59c515f4ce83eefe999da7d798452ccbd0e6eb25`. Final trial counters are 10/5/0/5
(limit/used/reserved/remaining); reads and reopening charged no extra check.
The owner subsequently instructed “no rollback” on October 3, 2026, so all
three post-test inactive applies are intentionally unperformed. Existing scoped
admission and the private CI/CD subject selection remain in place. This changes
only the retained completion scope; it enables no additional user, capability,
provider or environment. Future disabling requires a fresh plan at the current
source revision, its own exact-digest approval and successful readback. See the
[current evidence](evidence/sec340-governed-history-dev/README.md).
