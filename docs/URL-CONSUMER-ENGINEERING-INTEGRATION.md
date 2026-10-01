# V1 engineering integration and approved retention

On 2026-09-20 the owner explicitly approved both retention settings:

- Minimized result/usage receipts: seven days, without original URLs or messages.
- One-time trial eligibility: while the account exists, erased through account deletion.

This resolves those policy choices. It does not approve unrelated legacy deletion
retention, token discovery, financial-record policies or production activation.

## Engineering boundary

The new Dev integration has five JWT-scoped routes for prepare, submit, reconcile,
access and explicit trial activation. It uses Python 3.14 ARM64 with the existing
private assessment alias. Only up to three explicitly configured synthetic Cognito
subjects can qualify; missing or empty allowlists deny access. Existing JWT,
account, age, device, trial and quota checks still apply. The infrastructure output
always distinguishes this mode from general customer access.

A separate V1 deletion worker processes only authoritative commands for those
synthetic subjects. It does not replace legacy ENTITLEMENTS cleanup or claim
complete account deletion. The existing account-data API is not deployed and the
legacy token-discovery/identity-finalization gates remain open. Paid verification
is still a legacy stub; no paid or complimentary grant is fabricated for tests.

The deletion worker uses an exact deletion-ledger stream plus one-minute bounded
reconciliation. Lease recovery and explicit indexed receipt expiry run each minute;
TTL is a fallback. Seven-day expiry denies reads and schedules physical deletion;
cleanup delay/failure is monitored rather than assumed away. Alarms use the existing
confirmed support@andmorethings.com topic with exact CloudWatch source ARNs.

Each authority mutation is conditioned on a verified retained-key inventory.
Initialization requires proving the namespace is fresh or auditing historical key
issuance. No runtime derives a complete-history claim merely from its current key.
Key material remains outside Terraform, source, logs and outputs.

## Qualification and cleanup

Manual release must pin the four authority ZIPs to one source commit and update
the private assessment's trusted execution-budget extension separately. Start with
all execution gates false; review the plan and actual IAM/routing before enabling
the sole synthetic account. Logs and harness output must omit credentials, URLs,
account/proof identifiers and raw provider responses.

The temporary Cognito user is created with messaging suppressed and a synthetic
profile fixture; signup itself is not represented as tested. Qualification uses
real Cognito access-token authentication, age-attestation, device registration,
explicit trial activation, URL submission and same-proof reconciliation. Synthetic
delete commands qualify V1 cleanup only. Remove temporary account/profile/device
and test ledger data, revoke the allowlist and disable engineering execution after
tests; keep only nonsecret deployment evidence and the fresh key inventory.

Current source and test evidence must be supplemented by deployed results before
claiming completion. ATCR-124 remains open until the full native journey, live
contracts/access modes and accessibility acceptance are actually verified.

## Manual Dev release evidence, 2026-09-20

The four authority packages and private assessment were built from local Lambda
commit `84733306d62dd57df883b4425fa5305db6c4a62d`; each versioned S3 object and SHA-256
is pinned in the Dev variable files. Source publication and GitHub workflows were
not used for this integration. The Lambda documentation-only follow-up is
`2f277a1eda6e9cb89678903d0e18b68ddb521f6e`.

Local Lambda validation passed 692 tests plus 162 subtests, 223 isolated tests,
package integrity checks, and four disabled archive imports. Infrastructure passed
eight mocked consumer tests and ten resolver tests. Actual deployed verification
confirmed five Python 3.14 ARM64 packages, five JWT-scoped routes, 15 expected
alarms, and 32 actual-role IAM simulation grants/denials. Absent and invalid tokens
returned 401 on every route; valid synthetic authentication returned 503 while
disabled. Resolver version/hash and legacy Web Risk revision/concurrency were
verified unchanged.

Live verification caught and corrected two integration issues before completion:

- IAM's `ConditionCheckItem` simulation rejected the `EnclosingOperation`
  restriction, while transactional writes passed. Read-only condition checks now
  use the same scoped read grants; Put/Update/Delete remain transaction-only.
  This follows the supported keys in the [AWS service authorization reference](https://docs.aws.amazon.com/service-authorization/latest/reference/list_dynamodb.html).
- Terraform conditional type unification converted scheduled `schemaVersion` to
  text. Each payload is now JSON-encoded before collection unification. An exact
  numeric-payload regression assertion covers both schedules.

The actual HTTP trial/URL smoke passed seven assertions: authentication denial,
explicit trial activation, preparation, complete assessment charged once,
URL-free reconciliation, duplicate submission, and an allowance change of exactly
one with zero remaining reservations. Cleanup and final disabled-state evidence
are recorded below when independently verified; this paragraph alone is not an
account-deletion or production-readiness claim.

After the scheduled-payload correction, normal EventBridge runs reported zero
failures for both workers; the deletion reconciliation completed a full ledger
scan. The actual deletion-error alarm recorded successful SNS actions for both
failure and recovery to the existing support topic. This proves CloudWatch-to-SNS
action execution, not that a person read an email.

A read-only inspection of the sole synthetic V1 partition confirmed that original
URL, Cognito subject and device fingerprint values were absent. The corresponding
new Lambda log-group inspection also found none of those fixture values, bearer
tokens or proof-field labels. These are bounded observations, not a claim about
all historical application logs.

Live follow-up results:

- An origin-only partial result charged zero, left the allowance unchanged, and
  released its reservation (one logical request).
- An expired unsubmitted preparation returned HTTP 200 with
  `rejected/OPERATION_EXPIRED`, `not_started`, zero charge and no further
  reconciliation required. Two explicit duplicate reconciliations also passed.
  The first minimal assertion failed without retaining its response; its cause
  remains unproven. Later exact results do not erase that limitation.
- The normal schedule physically deleted three uniquely marked expired fixtures
  (PREPARE, ATTEMPT and settled CHECK). Strong reads confirmed all three absent;
  scheduled logs recorded exactly three explicit deletes and zero failures.
  Existing account rows and verified key inventory remained unchanged. This
  distinguishes explicit cleanup from merely observing DynamoDB TTL disappearance.

An authoritative command for the same temporary synthetic account then produced
its `V1_AUTHORITY` COMPLETE receipt. Strongly consistent inspection found zero V1
account rows, including trial eligibility and minimized receipts, with the key
inventory preserved. The stream and scheduled workers were not directly invoked
for this verification. This validates only the V1 component; legacy ENTITLEMENTS,
identity finalization and full account-deletion acceptance remain open.

## Android handoff

The owner explicitly approved the exact Android contract update on 2026-09-20,
resolving the automatic approval-review block. The snapshot now pins runtime and
schema/fixtures `84733306d62dd57df883b4425fa5305db6c4a62d`, with README-only source
`2f277a1eda6e9cb89678903d0e18b68ddb521f6e`. Its external feature remains disabled.
This approval covers the contract update and local completion, not publication or
customer activation. The final required Android quality gate passed all 452 tasks:
347 Dev, 335 UAT and 335 Production unit tests, 92.12% line coverage and 85.27%
branch coverage against unchanged 90%/85% requirements. Earlier emulator evidence
remains 26 passing tests, with manifest hardening and all flavor builds also
passing. The contract-only follow-up did not change UI or storage behavior.

New regressions verify that a generic expired response retains uncertain recovery
state, while an exact matching authoritative zero-charge closure clears the
minimal receipt after a process-style restart without replaying the URL. All 20
consumer fixtures pass. Root independently verified that all 11 vendored contract
files match their recorded SHA-256 and approved immutable Lambda source bytes.

Android implementation and the approved contract follow-up are committed locally as
`2f952870512e3fd7e85bd33d5ac6a9aa5dfdb899`. The worktree is clean. A bounded independent
cross-contract review found no issues, and the staged-diff secret scan found no
secrets. The closure-assertion caveat remains in the live evidence.

The disabled Dev debug APK SHA-256 is
`72ce7e53a7290ad677b021e9ffa241301090c7084bf4adf02a6d7b21603acf08`.
Real TalkBack spoken output/focus, signed physical-device/store-sandbox acceptance,
and broader paid/complimentary/deletion readiness remain tracked acceptance work;
the local quality gate does not substitute for that evidence.

## Final deployed state

The engineering allowlist is empty. All V1 runtime gates, both schedules and the
V1 deletion stream mapping are disabled. Final alias versions are consumer 4,
recovery 4, entitlements 4, deletion 3 and private assessment 2. The five package
hashes still match the pinned release. Fifteen final authenticated/unauthenticated
route checks passed. Consumer, assessment and resolver Terraform roots each
reported no drift.

Operator cleanup revoked/deleted the temporary Cognito identity, one synthetic
profile row, two device rows and two synthetic deletion-ledger rows. Private local
credentials, access token, receipt proofs and expiry-state files were removed.
This operator teardown does not substitute for the unfinished customer deletion
workflow. The HMAC key ring/inventory remain available for future approved work.

Ten sanitized machine-readable reports are in
[evidence/v1-engineering-2026-09-20](evidence/v1-engineering-2026-09-20/).
No UAT/Production change, general customer activation, GitHub push or workflow
execution is included. The broad infrastructure and entitlement stories remain
In Progress until their remaining acceptance criteria are met.

On 2026-09-20, the owner explicitly accepted Android implementation completion and
requested that device testing follow V1 implementation. [ATCR-124](https://andmorethings.youtrack.cloud/issue/ATCR-124)
is Done with local Android commit `2f952870512e3fd7e85bd33d5ac6a9aa5dfdb899`.
Outstanding physical-device, actual TalkBack and store/live-service acceptance is
tracked by [ATCR-148](https://andmorethings.youtrack.cloud/issue/ATCR-148), an Open
User Story in **Android V1-5 - Release qualification**. It depends on the 15 current
V1-0 through V1-4 implementation/refinement stories and environment-readiness story
ATCR-71. Its entry gate also requires any newly added V1 implementation work and
required Lambda/infrastructure dependencies to be complete. It reuses the ATCR-62
QA umbrella, which remains Open. These pending tests have not been reported as
passed; this disposition does not activate any feature or publish code.
