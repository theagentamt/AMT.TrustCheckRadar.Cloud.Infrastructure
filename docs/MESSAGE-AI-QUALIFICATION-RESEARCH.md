# V1 message AI: qualification research and proposed next increment

Date: 2026-09-21. Tracks SECUR4ALL-240/229, ATCR-120 and operations SECUR4ALL-237/243.
Status: research and proposals; no qualified model, paid execution or activation approval.

## Recommendation

Build a separate, initially offline evaluation harness before running a paid experiment. Compare three dated models on development data, choose one, freeze its complete request profile and then evaluate it on untouched, independently labeled English/Spanish data. Existing unit/emulator passes establish implementation behavior, not model quality.

| Candidate snapshot | Proposed role | Standard input/output USD per million tokens |
| --- | --- | --- |
| `gpt-4.1-mini-2025-04-14` | Baseline with the fewest expected adapter changes; non-reasoning | $0.40 / $1.60 |
| `gpt-5.4-nano-2026-03-17` | Lower-cost classification challenger, reasoning `none` | $0.20 / $1.25 |
| `gpt-5.4-mini-2026-03-17` | Quality comparator, reasoning `none`; quality must be measured | $0.75 / $4.50 |

Sources: official [GPT-4.1 mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini), [GPT-5.4 nano](https://developers.openai.com/api/docs/models/gpt-5.4-nano), and [GPT-5.4 mini](https://developers.openai.com/api/docs/models/gpt-5.4-mini) pages, retrieved on the research date. All list Structured Outputs and the dated snapshots above. The 5.4 models document `none` as their default reasoning effort. These are comparison candidates, not a claim that any meets our quality or latency targets. Account access/rate limits have not been inspected.

The current [GPT-5.6 Luna page](https://developers.openai.com/api/docs/models/gpt-5.6-luna) lists only an undated model ID, and default medium reasoning. Our runtime deliberately requires a dated ID and a single assistant-message response. Defer Luna unless version identity and a reviewed request profile can satisfy those constraints; do not weaken the qualification gate simply to accept it. The model used by Codex to develop the app is a separate decision and is unchanged.

## Compatibility and missing engineering

Reviewed Lambda release `d35dcf7f5ec4443c5f8a87954c0bd1b8f83a2846`, including `src/message_evaluator/ai_provider.py`, `proposer.py`, candidate.2 contracts and `docs/sec229-ai-qualification-plan.md`.

- Existing bounds: 8,000 Unicode message characters, a 32 KiB public request, 128–512 configured output tokens, model timeout at most eight seconds and an overall evaluation deadline of 18 seconds. These are not an input-token budget.
- The AI parser accepts exactly one completed assistant message with one output-text item. Reasoning items, tool output, refusal, incomplete output, duplicate keys and wrong snapshot are rejected. The first real calls must test exact response shape and schema acceptance before any quality inference.
- Base-model schema keywords appear consistent with documented [Structured Outputs support](https://developers.openai.com/api/docs/guides/structured-outputs). Documentation does not prove live acceptance. Do not use fine-tuned variants as substitutes.
- No evaluation runner currently exists. Production `assess()` requires an already-approved qualification record. The evaluation runner must call shared request/transport/parser functions under its own explicit experimental controls; never fabricate a production approval record or enable the mobile service to obtain qualification data.
- Freeze all effective options, including explicit `reasoning.effort=none` for 5.4, model, prompt, schema, output limit and deadline. Bind the full request profile in qualification evidence and runtime validation before eventual activation. A request-option change must invalidate prior qualification.
- Add measurement of actual input/output/reasoning tokens and outcome/latency codes without exporting message content. A timeout or invalid output can still incur provider cost. Unknown cost stays unknown, with its budget reservation retained.
- Test Unicode/code-point spans, sanitizer placeholders, Spanish punctuation/accents, emoji, long messages and five-category/three-span responses at the 512-token ceiling. Truncation must remain an uncharged failure; do not silently enlarge the ceiling to make a model pass.

## Staged experiment proposal

Stage A: at most **660 provider attempts**, allocated as 20 smoke calls plus 200 development calls for each of the three models. Split each model's smoke calls evenly between EN/ES and cover response compatibility, refusals, truncated responses and Unicode spans. Split its development set into 100 examples per language: 30 benign, 30 warning, 20 ambiguous/out-of-scope and 20 adversarial. Ensure every warning category is represented. Compare identical cases across models; they remain development material permanently. Stop a candidate on incompatible transport/schema behavior before using its remaining allowance. A prompt revision or rerun consumes the same total attempt cap.

Stage B: only after choosing and freezing one model/profile and agreeing on labels and release criteria, run **1,800 untouched held-out cases** plus at most **1,000 separate operational calls**. Maximum 2,800 attempts, no automatic retries. The held-out plan remains 900 per language: 300 benign, 300 warning, 150 ambiguous and 150 adversarial, with at least 50 examples per warning category. Operational cases assess latency, errors and costs; repeated load cases do not increase independent quality sample size.

These limits count generation attempts. Any separate token-count endpoint calls must be disclosed and bounded separately, including any applicable cost. Keep model-eligible dispatch metrics separate from whole-pipeline outcomes: deterministic guards can skip AI, so their passes cannot inflate model accuracy or the 1,000 actual provider latency samples.

Use permitted synthetic/licensed material with source/provenance records, group related scam templates across splits, and prevent paraphrase/translation leakage. The existing proposal calls for two independent bilingual reviewers and adjudication before model execution; reviewers and material are not yet arranged. This is a bounded prelaunch validation task, not staffed customer escalation. Model-generated examples may help engineering, but model agreement/self-grading is not independent ground truth. Synthetic performance alone does not demonstrate representative customer accuracy.

The numerical gates in the existing Lambda qualification plan remain proposed: separate EN/ES error bounds, completion/coverage thresholds, ambiguous-context abstention and zero observed mandatory safety violations. Freeze those criteria before the holdout. Failed qualification requires a revised candidate and fresh untouched holdout, with a separately reviewed additional budget. Report warnings, no-warning, abstentions, provider errors, schema rejection and timeouts separately. Include independently supported threats and whole-pipeline billing/recovery tests, not only model classifications.

## Cost calculation and proposed caps

Arithmetic uses published standard uncached token rates, no tools, no batch discounts and one provider call per attempt. It is a planning estimate, not measured usage or a subscription margin forecast.

Illustrative workload: **2,000 total input tokens plus 512 output tokens per attempt**. Input includes instructions, schema and message; actual sizes must be measured.

| Model | Per attempt | 200 attempts | 10 trial attempts |
| --- | ---: | ---: | ---: |
| GPT-4.1 mini | $0.0016192 | $0.32384 | $0.016192 |
| GPT-5.4 nano | $0.0010400 | $0.20800 | $0.010400 |
| GPT-5.4 mini | $0.0038040 | $0.76080 | $0.038040 |

These totals are AI tokens only. AWS, Google Web Risk, possible VirusTotal, store/payment fees, taxes, corpus licensing and reviewer labor are excluded. Two hundred completed customer checks can require more than 200 billable provider attempts because unsuccessful attempts do not consume the customer's allowance. The trial has the same distinction. Production attempt/rate/cost controls remain necessary.

For the experiment runner, propose a separate **8,192 total input-token admission ceiling** and **512 output-token ceiling**. Enforce a validated upper bound for the entire serialized model input/schema before dispatch; character count and an unverified local token estimate are insufficient. The counting/bounding method is still to be implemented and validated; until then the calculated ceiling is conditional, not an existing hard cap. This evaluation limit must not silently narrow the app's supported message scope. Over-budget supported messages must be recorded as a coverage gap and resolved before qualification.

At those limits, maximum token cost per attempt is $0.004096 (4.1 mini), $0.0022784 (5.4 nano), or $0.008448 (5.4 mini). Formula: `(input_tokens × input_rate + output_tokens × output_rate) / 1,000,000`.

| Stage | Attempts | Calculated token ceiling | Proposed provider-spend cap |
| --- | ---: | ---: | ---: |
| A: three-model screening | 220 per model; 660 total | $3.260928 | $5 |
| B: one selected model | 2,800 total | At most $23.654400 using mini | $30 |

Combined calculated ceiling $26.915328; proposed combined provider budget $35. Caps are proposals, not spending authorization. Recheck prices before execution. Regional processing uplifts or other enabled pricing features require recalculation. No claim is made that $35 covers AWS or human review.

Before dispatch, atomically reserve the worst-case cost and one attempt in a durable run ledger; stop when either limit would be exceeded. Include failed/unknown requests, preserve reservations across restart, limit concurrency and reject unlisted models/endpoints. A provider dashboard budget is not a substitute for this runner control. Use a separate test project/key and permitted test data. No paid calls have run.

## Data handling and operational dependencies

Official [data controls](https://developers.openai.com/api/docs/guides/your-data) distinguish response storage from abuse-monitoring retention. `store:false` does not itself establish zero retention: default abuse logs may retain content for up to 30 days, with stated exceptions. ZDR/MAM require eligibility/approval and have limitations. Verify the actual project configuration before real customer use; account settings were not inspected. Keep training-data sharing disabled. Our seven-day receipt retention is a separate promise. US app-store availability does not establish provider data residency; regional processing, if required, needs its own configuration review and cost calculation.

The reporting contract `docs/V1-OPERATIONS-CONTRACT.md` is still a draft. SECUR4ALL-237 owns authoritative lifecycle/cost events, deduplication and daily aggregates; SECUR4ALL-243 owns restricted delivery, scheduling, alerts and runbooks. Recipient is already approved: **support@andmorethings.com**. The proposed 08:00 America/Chicago schedule, 30/14/90-day operational retention and numerical alert thresholds are not recorded as approved. In particular, the proposed 30-day linkable reconciliation store is not covered by the approved seven-day result/usage receipts; resolve that boundary before provisioning.

The report must distinguish processing completion from a chargeable complete assessment. The older draft's completed-but-inconclusive terminology must be reconciled with the approved no-deduction policy. Preserve one logical-check denominator, show pending/late corrections and account for provider costs even when the user is not charged. Native Lambda alarms already defined in infrastructure do not implement these application-level reports. `daily_reporting_ready=false` remains accurate.

## Concrete next work

1. Lambda agent: build offline-first evaluation runner, corpus manifest/labeling rubric, request-profile identity, bounded attempts/cost reservations and metadata-only reports. Test it with simulated providers; leave production qualification empty.
2. Orchestrator: establish permitted EN/ES sources/reviewers and present the finalized Stage A payload profile, data handling and $5/660-attempt cap before requesting paid execution.
3. Lambda/infrastructure: refine SECUR4ALL-237/243 event/accounting contract and retention choices, then implement report aggregation/delivery without changing approved customer allowances.
4. After accepted quality, privacy, cost and operational evidence: controlled Dev runtime/Android integration. ATCR-148 physical-device acceptance remains separately pending.

Research validation: official pages fetched; current adapter and reporting contract reviewed; monetary arithmetic recomputed with decimal arithmetic. No runtime code changed, no live model measured, no customer input accessed, and no cloud resource deployed.
