# ATCR-94 backend readiness after profile-writer deployment

Historical September 24 assessment. Current account-specific readiness and resolved
source gaps are tracked in [the September 26 rollout](LIVE-ACCOUNT-DELETION-ROLLOUT.md).
The old missing-CAMPAIGN-implementation statement below no longer describes current
source; whole-period key retirement is not an individual-account prerequisite.

Read-only assessment of latest Lambda `origin/release-V01` at
`859fd3f3029633262b0d5f5a0c5741fe5b6345dc`. Assessed deletion/finalizer/campaign/token
sources equal that release. No account records, provider calls, runtime changes or
policy/approval markers were touched. Existing deployed metadata evidence is used;
this is not a new live AWS audit.

## Accepted request and Android local cleanup

Existing immutable contract: `contracts/account-deletion/1.0.0-candidate.1/`, last
changed at `7d6f9dfa99c30b2ba8a24ea59d5d75657dfa5169`.

Both strict POST 202 REQUESTED and strict GET 200 REQUESTED for the same authenticated
account and exact locally retained operation UUID establish request acceptance.
`AccountDeletionService.status` strongly reads the fixed owned command;
`request` atomically puts that command and sets the profile DELETION_REQUESTED.
GET is therefore durable acceptance reconciliation, not a second deletion request.
The owner's new approval permits Android local cleanup after that matching proof;
no response-schema change or POST-only limitation is required.

A different UUID, NOT_REQUESTED, malformed response, timeout or 401/404 is not
matching acceptance proof. `completionEligible` is not global completion. The
producer never emits overall COMPLETE and can stop serving authenticated status
when identity is removed. Local-cleanup approval must not be worded as completed
server erasure. The approved unresolved UUID retention is a client policy, not
new server retention or checkpoint permission.

## Prioritized remaining dependencies

1. **Resolve the mandatory CAMPAIGN completion gap — Lambda owner.**
   `src/campaign_deletion_bridge/service.py:133` unconditionally raises
   CoverageUnavailable from `complete_account_deletion_component`. Its traversal
   returns `complete=false`/`LOCATOR_TRAVERSAL_ONLY`; strong locators alone do not
   qualify historical coverage, period/key retirement, writer/replay and tombstone
   cleanup. This is a source/qualification requirement, not just a missing flag.
   Do not create a synthetic real-account CAMPAIGN receipt or bless empty current
   tables as historical erasure. Finish the bounded coverage proof and receipt
   producer before claiming all twelve components can complete.

2. **Complete identity and full retained-data inventory evidence — infrastructure
   audit owner with Lambda contract review.**
   Mapping must show Cognito Username equals exactly one sub and owned PROFILE
   identity for all relevant existing identities, plus signup/import/federation
   writer behavior. A selected account/pool setting is insufficient. Produce
   counts/mismatch categories and digest only; unknown mappings need a specific
   migration or resolver implementation before the current finalizer can run.
   Full inventory must cover legacy data, restores, all writer paths and qualified
   erasure/export, not merely table enumeration. The new profile-writer evidence
   closes two writer prerequisites; it is not full inventory approval.

   Required ledger marker is INVENTORY#dev / ACCOUNT_DATA_INVENTORY, strict
   schema 1, reviewed revision and manifest SHA, VERIFIED_COMPLETE, approved epoch,
   usernameIsSubVerified=true and exact ordered components:
   SESSION_REVOCATION, DEVICE_BINDINGS, DEVICE_RECOVERY, ANALYSIS_ABUSE, HISTORY,
   CAMPAIGN, CAMPAIGN_OUTBOX, ENTITLEMENTS, V1_AUTHORITY, PLAY_TOKENS, USER_PROFILE,
   IDENTITY. Commands must be newer than approval. Authority HMAC, purchase
   ownership and campaign locator inventories are separate evidence. Preserve
   legacy usage/rows; no marker can automatically requalify older commands.

3. **Qualify all receipt producers and their durable retry path — Lambda plus
   infrastructure.** Verify exact deployed code/IAM for History terminal-safe
   bridge and lifecycle, campaign bridge/lifecycle, V1 authority deletion,
   PLAY_TOKENS deletion, and account-data reconciliation. Refresh any older
   artifact before activation; source implementation alone is not deployment
   evidence. Exercise only isolated synthetic AWS fixtures under a reviewed
   fixture plan: missing proof blocks profile/identity, exact command/receipt
   identity, duplicate/restart/expired-stream recovery, fence races, pagination,
   logical expiry versus physical cleanup, malformed pair preservation and
   deadline/lag alerts. Existing Moto evidence is useful but not a live deadline
   or durable-worker guarantee. No physical device is needed.

4. **Enable only through an explicit coordinated limited-test plan after the
   above — infrastructure owner.** Current account-data source validates both
   ACCOUNT_DELETION_ENABLED and ACCOUNT_IDENTITY_FINALIZER_ENABLED; there is no
   independent accept-only activation mode. It also requires COGNITO_USERNAME_IS_SUB,
   approved policy/inventory/coverage controls, completion status complete and
   matching inventory pins. Current metadata has these privacy gates false,
   mapping false and inventory pending; current IAM has no AdminDeleteUser grant.
   The API account-data stream mapping and five-minute reconciliation rule are
   disabled. V1 authority deletion and PLAY_TOKEN_CLEANUP_ENABLED/triggers are
   disabled, along with History/campaign paths requiring separate review.
   Workers must be ready before accepting requests with a 24-hour deadline. Do not
   set completion/coverage fields simply to get past validation.

   The token-deletion bridge is separately gated from provider access and does
   not require the pending five-minute token lifecycle checkpoint exception.
   Isolated direct TokenDeletion fixture qualification can proceed without that
   policy. The scheduled token lifecycle/expiry worker does require its explicit
   PLAY_CHECKPOINT_POLICY_APPROVED gate; keep it off while approval is pending.
   Queue/stream permission is not a reason to activate paid/provider checks.

## Already resolved versus evidence freshness

- Both active profile writers now run reviewed c4b1cae source on Python 3.14 ARM64,
  deletion-ledger env and narrowed transactional policies. Actual readback and 16
  installed-role simulations are recorded in [tighten readback](evidence/profile-writer-fence-2026-09-23/tighten-readback.json)
  and [installed IAM simulation](evidence/profile-writer-fence-2026-09-23/installed-iam-simulation.json); neither claims live signup.
- Export cursor secret initialization and deployed strict parser were completed
  separately. The earlier privacy readback predates both and must
  not be reused to claim the secret is still empty or export still has old code.
- Export gates remain closed; export setup is not itself permission to delete.
- The last profile readback reconfirms deletion/finalizer/export gates false;
  broader worker evidence is older. Infrastructure should refresh exact aliases,
  environment allowlist, schedules/mappings and IAM at the limited-test plan.

Smallest next independent work: aggregate-only complete identity mapping audit
and inventory gap reconciliation, alongside a bounded Lambda plan to close the
hard CAMPAIGN receipt gap. Keep current Android accepted-request integration
moving with synthetic contract fixtures; do not hold it for physical hardware or
misrepresent it as live erasure acceptance.

## Current decision and delivery boundary

The [September 24 owner decisions](ACCOUNT-DATA-POLICY-DECISIONS.md#owner-decisions-2026-09-24--accepted-deletion-and-android-local-cleanup)
authorize Android local cleanup and unresolved-operation retention. They do not
resolve these backend prerequisites. ATCR-94, SECUR4ALL-244 and SECUR4ALL-125
remain in progress for their unmet acceptance. Profile-writer deployment is
completed as documented in [the rollout record](PROFILE-WRITER-FENCE-ROLLOUT.md).
