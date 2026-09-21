# ATCR-121 recovery selection integration

## Scope and status

This source increment prepares local exposure selection over the existing approved
`recovery-basics-1.0` text. The new selection policy is **Draft** and stays disabled.
The previously approved all-basics help remains accessible under the existing
account-session rules. ATCR-121, SECUR4ALL-163 and SECUR4ALL-234 are In Progress;
this document is not a completion or deployment record.

The exact owner review packet is [RECOVERY-SELECTION-REVIEW.md](RECOVERY-SELECTION-REVIEW.md),
first published at infrastructure commit `b95d1cf1bb6b2133727250fa69d7962fbd1a2838`.
Its SHA256 is `158b44a11d6f96637993fc5765618a10a7703f7c2da83c74fc603969d9dc45f4`.
SECUR4ALL-163 comment 7-1308 records that approval is pending. Do not infer approval
from test fixtures, a synthetic Approved enum, or the instruction to implement.

## Shared contract

[Lambda PR25](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/25)
is merged into `release-V01` at `7e85a3b7265670b4b3c11105a492c05e19324345`, from
reviewed source `0509d0b4b1a82b196b3f308ac01f9fc146369158`.
Files live under `contracts/recovery-selection/1.0.0-candidate.1`.

| Artifact | SHA256 |
| --- | --- |
| SHA256SUMS | `42d160ffd096d2099744e39f4ccf1696b93546434c52e107eb604e3fa78a4e75` |
| selection-policy.json | `637f12fda128fcf2acc81295c14eaa765de091b901457413c788a9edc276ea54` |
| fixtures.json | `6217a5c56a7673ac6907a833d8fd7bd6860ed8096d6d26adbc09c8c6797c473b` |
| recovery-basics-approved.json | `c27e15bf60134526e698952ad105a37865d029362a0420cd4673dfc9d55689f2` |

The content snapshot is unchanged from the existing approved Android bundle.
The contract fixes five closed exposure identifiers, all 32 subsets in each
language plus unsure cases, presentation order, deduplication, link-to-device
dependency, version/fallback rules and an explicitly unavailable AI capability.
The executable reference is outside Lambda runtime packages. There is no callable
recovery endpoint in this increment.

Validation: 89 focused tests passed, independently repeated by the reviewer.
Review verified the manifest, exact approved content bytes, fixed official links,
closed schemas, selection-order independence and seven new interface pairs against
the owner packet. No actionable shared-contract defect remained. Synthetic approval
in tests exercises mechanics; the published policy remains Draft.

## Android integration

[Android PR20](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/20)
is merged into `release-V01` at `518f9c77a8f182b07e2a4ec6a17202010c4ecddb`, from
reviewed source `20be8ae80ace1e59f58b78da47fb04a13a0aa2f6`. It mirrors all ten shared
files byte-for-byte and implements volatile screen choices, lifecycle clearing,
account gating, accessible EN/ES selection and unchanged confirmed official-link
navigation. The exact tested source is pushed and integrated.

The exact final-source local quality gate passed: 491 tasks; 708 Dev, 667 UAT and
667 Production host tests (2,042 total), with no failures, errors or skips. Line
coverage is 92.2442% and branch coverage 85.3083%; the 90%/85% thresholds and
exclusions are unchanged. An initial compiler memory-exhaustion attempt was
recovered by rerunning the same tasks with two workers and larger local heaps,
without repository configuration changes.

All 18 emulator cases passed: nine new selector cases, six existing journey cases
and three account-access route cases. These include all-basics Draft fallback,
signed-out/withdrawn-content behavior, combined selection, background/account/
saved-state clearing, replaced policy/bundle observer and confirmation handling,
fixed-link cancellation/failure, and English/light plus Spanish/dark layouts at
actual Compose 2x font scale. Candidate tests explicitly inject engineering
approval; they do not enable or approve the shipped selector.

Independent review found and verified fixes for stale lifecycle observer captures,
policy-replacement confirmation state and a test-only large-font setup issue. Final
review checked host XML, native logs, all ten mirrored files and the APK hash with
no remaining actionable findings. Android records reproducible evidence in
`docs/v1/android-recovery-selection-validation.json`.

Dev debug APK SHA256:
`4a1ab8ffcc69b116c9c59a7efee88a6801ce1a948f986fc0cc34cf06d56d757f`.

## Infrastructure and service boundary

No Terraform resource, new Lambda function, API Gateway route, secret, storage,
permission or deployment is needed for on-device deterministic selection. The app
does not send exposure choices to AWS, analytics or research. There is no analysis
receipt, provider entitlement check or deduction for local help.

The existing paid-analysis authority is not bypassed or repurposed. Any future
optional AI explanation is separately governed by SECUR4ALL-235 and its approved
contract, provider qualification and activation gates. No new provider capability
or AWS behavior can be inferred from a shared contract file.

## Acceptance still open

- Owner approval of this exact selection/copy proposal, followed by an immutable
  approved revision, updated Android pins and verification of the enabled default.
- SECUR4ALL-163 detailed urgent/follow-up content and combinations beyond the
  whole-paragraph basic selection provided here.
- SECUR4ALL-235 real bounded AI classification/explanation, approved action
  grounding, injection/contact rejection, shared access/accounting and failure/
  cancellation behavior. A disabled notice does not fulfill this acceptance.
- ATCR-121 final integration acceptance, with physical-device/TalkBack work tracked
  under the existing approved ATCR-148 deferral. Independent bilingual release
  qualification remains distinct from string and fixture parity.

All feature work targets `release-V01`; no main promotion or cloud deployment is
included. Local validation is required under the main-only GitHub CI policy.

## Next backend work for SECUR4ALL-235

The service is absent, but its engineering preparation is actionable. A separate
closed contract should accept a bounded sanitized recovery description and a
known bundle version, and return only allowed exposure/action/question IDs or
explicit uncertainty. Fixed approved bilingual explanations avoid unrestricted
generated instructions. Offline fixtures can test injected instructions, unknown
contacts/IDs, stale bundles, provider failures and cancellations before paid calls.

Lambda's `src/message_evaluator/proposer.py` provides reusable bounded transport;
the message-specific prompt and schema in `src/message_evaluator/ai_provider.py`
do not qualify a recovery model. `src/shared_check_authority/core.py` needs an
explicit recovery scope, payload identity and summary validation while reusing
account/device/entitlement, reservation and complete-only settlement. Existing
message or URL receipts cannot be relabeled as recovery receipts. Consumer patterns
in `src/message_consumer/service.py` and `src/url_consumer/service.py` can support a
separate disabled evaluator/consumer with injected offline providers.

Before enabling real clarification, review the exact explanation/question text,
classification/uncertainty policy, external sanitized-data projection and definition
of a complete clarification. Partial answers, failed calls and inconclusive results
remain non-chargeable under existing policy. Provider qualification and activation
must be recovery-specific; the pending message-provider experiment is not evidence
for this feature. This assessment introduces no new authorization requirement for
ordinary offline engineering, and does not represent implemented service code.
