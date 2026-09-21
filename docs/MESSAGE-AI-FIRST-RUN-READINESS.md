# First message AI compatibility run: readiness

Assessment date: 2026-09-21. Owner: infrastructure orchestrator, with Lambda
tooling owned by the Lambda agent. This is work under SECUR4ALL-240, which stays
In Progress. SECUR4ALL-321/322 completed the adapter and operations handoff;
they did not authorize a paid run or qualify a model.

The subsequent [playbook refinement approval](MESSAGE-ANALYZER-PLAYBOOK-APPROVAL.md)
authorizes a changed Lambda prompt. The original profile identity below is
historical; prepare any new experiment from the revised profile recorded with that
implementation. The proposed eight-case limits and unresolved access, pricing and
paid-run gates are unchanged. Compatibility success would not measure the refined
playbook's scam-detection quality.

The revised controlled `gpt-4.1-mini-2025-04-14` profile is
`101d79ff26c57c65f53db97c7c6794a51dea56ed862612f98ec57616401eb3f7`.
Recompute it from the integrated Lambda source before a concrete authorization.
The original eight-case selection is still a compatibility proposal; supplemental
playbook regression examples do not silently increase its authorized size or cost.

## Observed account state

The dedicated `trustcheckradar-evaluation` project was created on 2026-09-21 and
verified in the project list. The Default project was left unchanged. The new
project's settings and restricted-key form were inspected without creating a
credential or dispatching a provider request. The key list contained zero keys.

| Area | Observed state | Remaining requirement |
| --- | --- | --- |
| Project | `trustcheckradar-evaluation` created; Global residency | US app availability does not establish US provider residency. |
| Sharing | Feedback, evaluation/fine-tuning data, and API input/output sharing disabled | Recheck the dedicated project's applicable controls. |
| Retention | API call logging shown as enabled per call; project table shows retention `None` | `None` is not proof of zero retention. Review processing/retention for both endpoints. |
| Service tier | Standard default; other tiers available | Runner explicitly requests `default`; it does not opt into another tier. |
| Credential/model access | No key created; restricted form offers Responses Read/Write/None and expiration; dated baseline appears in model-policy picker | Effective model access and count-route permission mapping remain unverified. Appearance in a picker is not proof of request acceptance. |
| Spend control | No project spend limit configured; UI describes spend alerts | Do not treat dashboard alerts as an enforced experiment cap. The reviewed local ledger remains required. |

Official [data controls](https://developers.openai.com/api/docs/guides/your-data)
distinguish stored response state from abuse-monitoring retention. `store:false`
does not establish zero data retention. This record omits account identifiers,
email, balance and credential material because they are unnecessary for review.

The proposed temporary key is named `trustcheckradar-compatibility-r1`, scoped to
this project, with Restricted permissions: Model capabilities > Responses =
Write; unrelated capabilities = None. The UI exposes 1-day, 7-day, 30-day, Never
and Custom expiration choices. Prefer a one-day key created when execution is
ready, then retire it after reconciliation. This is a proposal, not a credential
grant. No separate input-count permission was visible; do not infer its mapping
or broaden to All to bypass a failed request. No organization-admin key is needed.

Creating persistent credentials through the browser requires confirmation under
the computer-use tool's action-time access policy. The owner should keep the
secret out of chat and repository files. The inspection form was closed without
submitting it.

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

## Historical proposal identity

Original Lambda release: `74316e9faa2f5d0e5dbb114cdfcbcbdb7adb33aa`.
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

## Revised packet verification

The Lambda agent refreshed the packet against integrated release
`1afa71dd3291a58cb1ca0de3f9a45456e85cc98b`. Local reproduction verified all eight
unchanged cases, the revised profile above and per-case serialized count and
generation request identities, with zero provider requests. The original corpus
canonical identity remains unchanged; its file-byte SHA-256 is
`8455025cc77483fd9f776f5d495d86c1f99332c43049d03857bff53208e15af8`.

Private preparation artifacts are at `/tmp/amt-compatibility-r1-preparation`:
`README.md`, `compatibility-corpus.json`, `request-identities.json`,
`authorization.template.json`, `readiness.template.json`, `operator-commands.md`
and `reproduce.py`. These temporary files are review aids, not durable execution
authority. Unresolved template fields are null and the authorization is
intentionally invalid. No ledger or authority directory has been initialized.
Recreate and verify the packet before execution if temporary files are lost.

The published counting guide and pricing pages did not establish count billing
terms during this review. The following provider question is prepared but has
not been sent:

> For POST /v1/responses/input_tokens with gpt-4.1-mini-2025-04-14, what charges
> apply to successful and unsuccessful requests, and what documented maximum
> charge can we reserve for a request bounded to 64 KiB? Does a project API key
> with Model capabilities > Responses = Write authorize this route, or is a
> separate permission required? Please provide the applicable documentation.

## Remaining setup and execution gates

1. Project creation is complete. Finish review of applicable sharing, retention
   and model access. Do not borrow the AWS runtime
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
