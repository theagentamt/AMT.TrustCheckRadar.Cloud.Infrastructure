# V1 local sanitizer integration

Owner authorization: 2026-09-21, resume the shared sanitizer contract and Android
ATCR-79. Lambda implementation and canonical fixtures belong to SECUR4ALL-221;
Android consumes an immutable artifact. Infrastructure coordinates the handoff.

## Scope and infrastructure assessment

The source inspection covers `terraform/api/main.tf`,
`terraform/message-consumer/main.tf`, its operations configuration and README.
Local detection, opaque replacement tokens and a shared test profile do not need
a new API route, Lambda, secret, table, bucket, queue or IAM permission. No
Terraform behavior change is proposed for this increment. This is a source
assessment, not a fresh AWS deployment or drift check.

The legacy `POST /analysis` Unicode/base64 correction has a 65,536-byte wire
limit. Its deployment/qualification remains SECUR4ALL-222. The governed message
contract uses a separate 32,768-byte limit. Neither client nor infrastructure may
replace one with the other or relax a client guard before its backend is ready.

The governed message candidate remains inactive under the existing deployment
and qualification gates. An approved local sanitizer does not qualify a model,
activate a provider or prove live end-to-end processing. The deferred paid
compatibility run is tracked separately in SECUR4ALL-323 and does not block local
masking or offline contract validation.

Review identified residual IPv6 forms that the existing backend privacy check did
not reject. The approved implementation scope includes a narrow mutable runtime
privacy guard before new provider processing, with matching client rejection of
unsupported forms. Immutable candidate artifacts and historical receipt semantics
remain protected. Executable evaluation profile identities must be refreshed when
this guard changes the bound runtime source; historical evaluation packets are
not current authorizations.

## Integration requirements

- Pin the canonical supplemental profile, hashes and shared English/Spanish
  fixtures from the Lambda repository. Do not mutate existing candidate contracts
  merely to add a client detection profile.
- Verify bounded format handling, normalization, repeated-value reuse, overlap
  ordering and reserved-placeholder handling against the same synthetic inputs.
  Supported detection is not a guarantee that arbitrary free-form text contains
  no private information; editable review remains necessary.
- Raw identifiers stay on the device. Generic outbound entity declarations carry
  only approved type/token fields. URL inspection requires its existing explicit
  disclosure path; masking a link does not authorize following it.
- The exact reviewed text/entities must be the submitted and queued projection.
  Existing dispatched request/proof identities cannot be silently rewritten or
  recharged. Old local records need the documented review/migration behavior.
- Preserve account, entitlement, opt-in, retention and deletion boundaries. The
  broader open SECUR4ALL-169/190 acceptance is not completed by this increment.
  No new disclosure, research consent or storage policy is introduced.

## Validation and publication

Record the final contract identity, branch/PR and merged release commits together
with meaningful Lambda and Android checks before declaring implementation done.
Distinguish unit/contract tests, emulator tests, actual deployment and final
physical-device acceptance. ATCR-148 retains the already agreed end-of-V1 device
qualification. Unrun checks are not passes.

New work targets `release-V01`. Validate locally; do not dispatch GitHub checks
for feature/release branches or promote `main`. Any later legacy deployment uses
the existing manual review process and exact packaged artifact.

## Validation evidence, 2026-09-21

Android's full local gate passed 491 tasks, including Dev 703, UAT 662 and
Production 662 host tests (2,027 total, no failures/skips). Coverage was 92.2126%
lines and 85.2781% branches against unchanged 90/85 thresholds, with no new
exclusions. Build, lint and release assemblies passed. The final APK passed all
34 targeted native emulator cases, including English/Spanish, 200% font,
light/dark, review/edit/cancel/Back, existing governed submission and legacy
review regression. Real-device and spoken TalkBack checks remain ATCR-148.

The canonical supplement has 41 curated cases, all exercised by Android's actual
sanitizer. Independent review verified all five mirrored files byte-for-byte and
the four-file digest manifest. Manifest SHA-256:
`912ec487bbb976ba8b482fa988ea93f3dee107bcd9b558d8fca07484b1147f57`.
Fixture SHA-256:
`ed48135e3d4a6fc6e00a506c584cf3461368f43c24515af8a59f87fa91aa7282`.

Lambda owner gates passed 208 legacy/sanitizer tests with 16 subtests, 460
evaluator/tooling tests and 269 consumer/authority integration tests, using Python
3.14.7. Source-only package checks verified inclusion of the exact changed runtime
files and exclusion of evaluation tooling; these are not deployed artifacts.

Independent Lambda checks passed 127 sanitizer/wire tests, 12 selected consumer
integration cases, and one legacy handler test with three subtests. These overlap
the owner's broader suites and are not an additional unique-test total. Reviewed
behavior preserves authenticated abuse-attempt counting; privacy rejection occurs
before check creation, entitlement/provider work. An old raw-content replay may
now require privacy review, while contentless reconciliation returns its original
stored outcome/accounting without a new charge.

Runtime guard changes require rebuilding the deferred evaluation manifest. The
current controlled GPT-4.1 mini profile is
`5388372f8d67d8032779308e0ef8585e4d5011eb1720031431225e375df160e3`.
Prompt/schema digests are unchanged. SECUR4ALL-323 retains the owner's approved
eight-count/eight-generation/USD 0.25 scope; access/pricing and exact execution
authority remain unresolved. No paid test or activation occurred.

## Published implementation

| Repository | PR | Reviewed source | `release-V01` merge |
| --- | --- | --- | --- |
| Lambda | [24](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/24) | `cdb69621ab718acd0ba8f79c1d7f3f2fbdd86d7f` | `f0e54b6345b3a2bb18ffa1bb63eb32aa63302272` |
| Android | [19](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/19) | `4352d95df9b4159b0b0874b41cc389dfa6729cf5` | `b88094f1246cd34ab84c8aa401335e374babef9d` |

Both reviewed commits passed independent final review. The Android repository
contains `docs/v1/android-sensitive-masking-validation.json` and the platform
handoff; Lambda contains `docs/SEC221-SANITIZER-HANDOFF.md` with its source
acceptance matrix. Redacted changed/staged secret scans passed.

The immutable shared artifact was handed off to ATCR-79 and iOS ITCR-13/92 in
verified tracker comments 7-1298/1299/1300. This gives both clients the same
versioned contract; it does not claim iOS implementation. SECUR4ALL-323 comment
7-1301 supersedes the prior evaluation profile identity for future execution.

This closes the Android implementation and Lambda source/contract handoff scope
once publication verification is recorded in their stories. SECUR4ALL-222
deployment, broader privacy/quality/activation work, the paid evaluation and
ATCR-148 physical-device acceptance remain open under their own criteria.
