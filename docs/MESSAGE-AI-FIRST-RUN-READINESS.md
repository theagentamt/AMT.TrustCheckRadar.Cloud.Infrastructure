# First message AI compatibility run: readiness

Assessment date: 2026-09-21. Owner: infrastructure orchestrator, with Lambda
tooling owned by the Lambda agent. This is work under SECUR4ALL-240, which stays
In Progress. SECUR4ALL-321/322 completed the adapter and operations handoff;
they did not authorize a paid run or qualify a model.

## Observed account state

Read-only inspection of the signed-in OpenAI Platform found one Default project
and no dedicated evaluation project. No project, credential or account setting
was created or changed, and no provider request was dispatched.

| Area | Observed state | Remaining requirement |
| --- | --- | --- |
| Project | Default project only; Global residency | Create a dedicated evaluation project and verify its actual settings before use. US app availability does not establish US provider residency. |
| Sharing | Feedback, evaluation/fine-tuning data, and API input/output sharing disabled | Recheck the dedicated project's applicable controls. |
| Retention | API call logging shown as enabled per call; project table shows retention `None` | `None` is not proof of zero retention. Review processing/retention for both endpoints. |
| Service tier | Standard default; other tiers available | Runner explicitly requests `default`; it does not opt into another tier. |
| Credential/model access | No key inspected; no request attempted | Dedicated restricted credential, selected dated-model access and route permissions remain unverified. |

Official [data controls](https://developers.openai.com/api/docs/guides/your-data)
distinguish stored response state from abuse-monitoring retention. `store:false`
does not establish zero data retention. This record omits account identifiers,
email, balance and credential material because they are unnecessary for review.

## Proposed first experiment

Use eight existing synthetic development cases, four English/Spanish translation
pairs: `dev-001-en/es`, `dev-007-en/es`, `dev-011-en/es`, `dev-019-en/es`.
These exercise an account-code request, benign urgency, missing context and
Unicode/emoji/accented text. Preserve every original case, family, provenance,
`development` split and `engineering_only` review status. Draft labels are not
independent quality evidence.

Use only `gpt-4.1-mini-2025-04-14`. Proposed limits are eight input-count attempts,
eight generation attempts and USD 0.25 in combined conservative reservations,
with no retries. Source limits remain 8,192 input and 512 output tokens. This
checks the provider envelope, structured output, request/count binding and usage
parsing; it does not exercise customer billing or the full app verdict pipeline.

The current [model page](https://developers.openai.com/api/docs/models/gpt-4.1-mini)
lists USD 0.40 per million input tokens and USD 1.60 per million output tokens.
At those uncached rates, eight maximum-sized generations reserve USD 0.032768.
The total is `0.032768 + 8 * evidenced_count_request_maximum_usd`. To admit all
eight under USD 0.25, the count upper charge must be at most USD 0.027154 each.
That is an affordability boundary, not a count-price claim. The official
[counting guide](https://developers.openai.com/api/docs/guides/token-counting)
establishes the route; this review has not established its billing terms.
Refresh prices and record an evidenced count-charge bound before authorization.

No paid run has been approved. Ordinary failures may consume the remaining
authorized attempts: the current CLI is not stop-on-first-error. Count/usage or
pricing-tier drift halts admission globally. Failed and unknown calls retain
reservations; they never create retry credits. A later expanded experiment must
explicitly account for this run if it shares the proposed Stage A allowance.

## Reproducible proposal identity

Lambda release: `74316e9faa2f5d0e5dbb114cdfcbcbdb7adb33aa`.
Infrastructure baseline: `87422f97c1d572137348f25b9f9e259b7104a7e6`.

| Artifact | Canonical SHA-256 |
| --- | --- |
| Controlled baseline model profile | `8bf3ddc823d15213cf25ab35b5f4ae3547e161cda06141ec9c6f199345bcb1bf` |
| Original 40-case development corpus | `eb0d016b8091a3873811afc4a64f0a2da06d86e8e34dd8de54650866fcb60419` |
| Eight-case proposal | `340fa953d1790ae8658b77796ebd982dee9f4188295f504edb27eda24cfcd37e` |

To reproduce the proposal from the pinned Lambda release, select the eight case
IDs above from `evaluation/message_ai/development_packet/engineering/development-corpus.json`
without changing their order or contents. Retain `schemaVersion: 1`, set
`corpusId: "amt-api-compatibility-draft-v1"`, and hash with the Lambda profile's
canonical JSON digest. Recompute identities after any edit. The approval registry
remains empty; these hashes are a proposal, not a grant.

## Remaining setup and execution gates

1. Create the proposed `trustcheckradar-evaluation` provider project. Review actual
   sharing, retention, residency and model access. Do not borrow the AWS runtime
   credential. Limit a new project credential to the permissions required by
   input counting and Responses generation; inspect available controls before
   granting access. No organization-admin credential is required.
2. Establish the count-request maximum charge and reconfirm generation rates.
   Unknown pricing is still unknown, including when the project has credit.
3. Approve external processing of these exact synthetic inputs by both routes,
   with the observed provider retention. Independent human labels are not a
   prerequisite for a compatibility-only test; they remain a quality requirement.
4. Freeze the execution host, private durable authority path, credential
   fingerprint, expiry and evaluation-artifact retention. Use an owner-only
   non-synced location outside repositories and temporary directories. Suggested
   artifact policy, pending approval: retain minimized results and reconciled
   ledger for 30 days after completion; preserve unresolved liability evidence
   until reconciled, and retire the experiment credential after execution.
   This is separate from the application's approved seven-day receipts.
5. Obtain the concrete owner authorization for eight/eight/USD 0.25 and the exact
   manifest. Prepare the seven evidence files described in the
   [controlled-evaluation handoff](MESSAGE-AI-CONTROLLED-EVALUATION.md), then have
   the Lambda agent review and pin its digest. Do not invent evidence or edit a
   registry merely to make preflight pass.
6. After approval, run explicit `init`, `preflight`, `run`, and read-only `report`
   through the reviewed adapter. Report known usage and unresolved liability
   separately. A stop prevents subsequent admission, not an in-flight request.

A clean compatibility result requires eight valid bound count results and eight
valid generation envelopes with the selected dated model/tier and consistent
known usage. Fewer results, refusal, truncation, schema rejection or unknown usage
remain visible findings. No model-quality percentage, latency qualification,
production activation or mobile device acceptance follows from this small run.

## Next Android work

The Android agent inspected release
`1a56ac24b545354bd8d0b6af36e7ed8f726b2920` and recommends **ATCR-79**, expanding
on-device redaction beyond the current URL/email recognition. Scope includes
the complete agreed entity set, normalized repeated-value token reuse within a
submission, deterministic overlaps, editable review, English/Spanish adversarial
fixtures and exact agreement between reviewed and submitted payloads. Victim vs.
attacker ownership inference remains excluded.

Coordinate the contract and fixtures with Lambda **SECUR4ALL-221** before coding.
Its legacy 65,536-byte wording must not override the current governed-message
32,768-byte limit or existing contract identities. SECUR4ALL-169 data boundaries
and SECUR4ALL-110 explicit URL inspection still apply. This local work can proceed
independently of model qualification and needs no new infrastructure by itself.
This assessment selects the next story; it does not claim Android implementation
has started. ATCR-121 post-scam guidance follows, subject to its backend dependencies.
ATCR-148 retains physical-device/TalkBack testing after V1 implementation.
