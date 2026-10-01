# Protected account export release qualification

Status: **pending, not executed**. Source development is SECUR4ALL-236; infrastructure
coverage is SECUR4ALL-245, Android is ATCR-94, and future iOS parity is ITCR-41.
The release test is [SECUR4ALL-331](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-331)
in **Backend V1-5 - Release qualification**. SECUR4ALL-196
owns the broader isolation suite; reuse its accounts and evidence where appropriate.
This document does not authorize UAT deployment, general export activation or tests
against existing customer accounts.

## Scope and build prerequisites

SECUR4ALL-236 retains implementation, independent security review, all-family
component qualification, required Dev runtime checks, operational instructions and
verified release-V01 integration. None of those are deferred here. This follow-up
owns later assembled-system UAT execution before V1 release. Defects discovered
here return to the responsible component as linked fixes.

Record exact infrastructure, Lambda and mobile release commits, package version/hash,
configuration and API contract before running. The current contract is
`contracts/account-export/1.0.0-candidate.3`, pinned to Lambda producer
`39cce61623794a123e61d25f5248b0c081eccf4a`; runtime fixes may have a newer package
source without changing those contract bytes. Candidate.2 mobile clients cannot
consume candidate.3. Record the selected mobile contract pin independently of the
Lambda artifact commit.

Use the established promotion process in `docs/DEV-RELEASE-ACTIONS.md` and reviewed
environment configuration. The current scoped export activation is **Dev-only**;
UAT activation configuration is an explicit prerequisite implementation/review task,
not a manual Lambda environment edit to perform during testing. Do not substitute
Dev resources or rewrite source/inventory approval to make a UAT request pass.

Verify account/Region, Cognito pool/client and active-device policy, current source
inventories, History generation, campaign period/resource proofs, exact authority
and cursor secret references, runtime role, JWT scope, route limits and alarm
routing. Existing keyrings must not be reinitialized. No secret, token, cursor,
source content or account identifier belongs in retained logs or screenshots.

## Synthetic setup

Use two dedicated synthetic accounts with completed adult onboarding and distinct
active device bindings. Include a free or exhausted-allowance account: export is
not paid analysis. Also prepare an unfinished-onboarding fixture to prove export
is denied under the approved policy. Generate representative current records using
supported producers for all 20 declared families, including both minimized Play
verification row kinds. Track exact fixture ownership and independent unaffected
account baselines. Never fabricate shared inventory approval markers.

Include more than 25 entries in at least one supported paginated family, current
and historical key/generation cases allowed by the selected inventory, and
recognizable synthetic content for verifying the saved file. Empty families alone
do not prove their projections. Provider sandbox, injected provider doubles and
real producer results must be labeled separately. Where current producers cannot
create a required synthetic row, implement a reviewed scoped fixture runner before
claiming that case; the local SDK fixture is not a deployed-runtime substitute.

Use Android emulation/simulation for executable mobile cases. Physical/provider
UI-only cases remain under ATCR-148 until the owner resumes that testing.

ATCR-94 connected Dev work is tracked in
[the native export qualification record](ATCR-94-CONNECTED-EXPORT-DEV.md).
It uses a dedicated emulator, real native authentication/device registration,
and a disposable account. Its status must be checked before reusing the runner.
A failed or skipped native attempt is not connected acceptance; this release
follow-up still requires the populated-family and interruption cases below.

## Cases and expected observations

| Action | Required result |
| --- | --- |
| Freshly authenticate account A; POST `/v1/users/account-export` with `{schemaVersion:1,action:"START_EXPORT"}` and the supported active-device header. Continue using the returned cursor and `CONTINUE_EXPORT`. | JWT-protected success; all 20 declared families before COMPLETE; exact candidate.3 envelope and scope; no credentials, internal hashes or B's data; no-store responses. No subscription or allowance deduction. |
| Save the complete document from Android Settings; read it through the emulator's document provider. | Valid bounded artifact with all declared families and no continuation cursor. EN/ES text describes data as observed during download, not a frozen cross-store snapshot. |
| Retry the same continuation while valid; change a supported source between pages. | Operation identity and original deadline stay fixed. Concurrent changes follow the declared as-read semantics; retries never extend the lifetime or silently omit an unprocessed family. |
| Change device binding/version or switch from A to B during pagination. | No further A page is served under the replacement identity/binding. App discards A's partial assembly; no account mixing or auto-registration bypass. |
| Use missing/wrong JWT pool, client or scope; stale authentication; missing device; unfinished onboarding; manipulated or foreign cursor. | Stable contract rejection with no data disclosure or success artifact. Reauthentication does not revive an expired operation. |
| Continue at the fixed 900-second boundary; exceed page/item/total-size limits using a reviewed fixture. | Expired/oversize export fails honestly, never truncated COMPLETE. Use at most the contract's 256 pages and 8 MiB; abort upon any violation. |
| Accept deletion for disposable A during an unfinished export, then continue. | Deletion fence refuses further pages. Export creates no durable job that delays deletion/identity removal. Independently verify B remains unchanged. Reuse SECUR4ALL-200/329 deletion evidence where applicable. |
| In isolated approved configuration, invalidate a required source inventory or cursor key, then retry. | Honest unavailable response, no guessed empty family or unauthenticated fallback; restore the reviewed configuration. Verify corresponding operational metric/alert without retaining sensitive payloads. |
| Cancel document saving, replace session while picker is open, and kill/restart the emulator app with the picker open. | No unwanted document or cross-session data recovery; partial assembly/cursors are discarded as designed. Cancellation does not promise separate revocation of the still-valid server cursor. |

The supported HTTP client must keep bearer/device values in protected memory and
emit only status/code/count evidence. An automated UAT runner and fixture lifecycle
are not yet delivered by this page; implement and review them before unattended
execution. Do not paste tokens into shell command histories or issue comments.

## Evidence, cleanup and completion

For every case record timestamp, build/environment identifiers, pass/fail/not-run,
expected versus actual status, sanitized family/count observations and exact suite
entry points. Separate local SDK mocks, installed Dev behavior, UAT, Android emulator,
provider sandbox and physical-device evidence. A deployed route or an empty COMPLETE
response alone is not all-family acceptance.

Remove only explicitly tracked disposable fixture records/accounts using approved
cleanup paths; cancel test work, verify pending jobs are fenced, and verify B and
unrelated resources against the baseline. Restore temporary fault/configuration
changes through the reviewed infrastructure process. Existing retention and backup
limitations remain unchanged. Alert destination is support@andmorethings.com;
SNS publication and actual inbox receipt are separate observations.

Close the release-test story only after all its required cases pass with linked
source and evidence. Keep physical-only exclusions explicitly linked. Source Dev
completion does not imply this release gate has passed.
