# V1 broader message AI assessment — owner review draft

Status: **PROPOSED, NOT APPROVED OR ACTIVE**. Drafted 2026-09-21 for
SECUR4ALL-229, with SECUR4ALL-190/228/230/242 and ATCR-120 dependencies.
The owner requested this draft; that request does not approve its verdicts,
wording, billing changes or activation. The existing approved 2026-09-20 rubric
and immutable candidate.1 contract continue to govern implemented behavior.

## Proposed product decision

Allow V1 to assess ordinary English and Spanish messages using AI, with a visible
**AI assessment** label. Explain warning signs without claiming that AI has
verified a sender, identified a criminal or proven a message safe. AI-only findings
are capped at **suspicious**. Existing independently qualified high-risk rules
and independent URL threat matches can still produce **high risk**.

This expands the currently approved scope: today, messages outside independently
qualified patterns remain inconclusive even if a model proposes a plausible rule.
Under this proposal, a qualified AI assessment could be complete outside those
finite patterns. Schema validity, a second model agreeing and a confidence score
would still not establish factual verification.

## Results and allowance deductions

Use the existing public risk vocabulary. Avoid adding a numerical risk score or
using “moderate” as a second, inconsistent name for “suspicious.” Assessment basis,
required-stage coverage, processing state and accounting are separate fields.

| Evidence and coverage | Result shown | Completed check deduction |
| --- | --- | --- |
| Independent URL threat match, or an existing independently qualified high-risk rule; every required stage completes | High risk, with the specific evidence basis | One, only on authoritative settlement |
| AI detects supported warning signs; every required stage completes | Suspicious — AI assessment | One, only on authoritative settlement |
| AI finds no supported warning signs within the qualified scope; every required stage completes | No warning signs identified — AI assessment; safety is not guaranteed | One, only on authoritative settlement |
| Unclear speakers/context, unsupported language/content, unresolved contradictory findings, or suspected instruction manipulation | Inconclusive, with a fixed explanation | None |
| The existing hostile-input guard actually stops processing | Blocked/unknown; retain independent threat evidence as partial/high risk if present | None |
| A required text or reviewed-link stage fails, is withheld, times out or cannot complete | Partial or inconclusive; show any available findings and limitations | None |
| Independent threat match survives another stage's failure or disagreement | High-risk warning retained; partial if a required stage failed | None for partial results |

The complete joint text/link rows describe a future separately versioned and
qualified implementation. Current candidate.1 message/link matches remain partial,
and Android's initial submission sends no reviewed links. This proposal does not
make the existing link path complete or chargeable.

**Proposed billing change requiring approval:** a complete AI-only assessment,
including a no-warning result, can consume one check. A successful model HTTP
request alone never qualifies. The consumer must verify the current account,
device, entitlement, policy/version, qualified coverage and every required stage
before settling the same logical check. Existing one-check idempotency and unknown
settlement reconciliation remain unchanged. Partial, failed and inconclusive
results never consume a completed-check allowance.

Examples (illustrative outcomes, not a test of accuracy):

- “Your parcel is waiting. Pay a small release fee today.” AI may identify a
  payment pretext and urgency: suspicious, explicitly AI-based. It cannot assert
  that the parcel company or sender is fraudulent.
- “Your parcel arrives tomorrow.” A qualified full assessment may show no warning
  signs, with the limitation that neither sender nor delivery was verified.
- “My bank warned me never to share a code.” Quoting a warning must not become
  a request to disclose a secret. If context remains ambiguous, abstain.
- A reviewed link matches Google's threat list while the model says the text
  looks ordinary: preserve the high-risk link warning. A no-match response alone
  does not establish safety.
- A message contains an unreviewed or withheld URL: show that the link was not
  checked, retain any supported text warning, and do not charge a complete check.

## Proposed AI scope and controls

Initial scope is a standalone incoming message in English or Spanish with a clear
speaker role and sufficient remaining context after sanitization. Quoted or mixed
conversations, unsupported languages, missing decisive information and contexts
outside the qualified evaluation set require abstention or separately qualified
support. No sender-identity verification, diagnosis, factual authenticity guarantee
or resident/person risk scoring is inferred from text.

Use a closed list of AI warning categories: requests for credentials or codes,
payment or transfer pressure, impersonation/pretext, secrecy or bypassing normal
verification, and urgency paired with a consequential requested action. Urgency,
an unfamiliar name, spelling, HTTP alone or a demographic attribute must not by
themselves establish fraud. These are proposed inference categories, not verified
versions of the existing deterministic rule IDs.

Treat every submission and model response as untrusted. Retain independent server
privacy validation, bounded input/output sizes and Unicode/token checks. The model
receives only the approved minimized projection, never operational credentials,
identity records or an allowance ledger. It has no tools, browsing, URL fetching,
code execution, memory of other accounts or authority to select actions.

Validate closed output categories and exact supporting spans internally, check
for contradictory or unusable output, then apply server policy. Span presence is
only a grounding check, not proof of semantic truth. Never render free-form model
instructions, links, contact details, verdict text or confidence percentages.
Adversarial text must not change prompts, policy, billing or tools. Detection of
possible injection is a reason to abstain, not an assertion that all attacks can
be detected. Do not treat ordinary scam instructions as system instructions.

## Proposed mobile wording and contract

| Purpose | English | Spanish |
| --- | --- | --- |
| Basis | AI assessment | Evaluación de IA |
| AI warning | AI identified possible warning signs. Verify the request independently before acting. | La IA identificó posibles señales de advertencia. Verifique la solicitud por un medio independiente antes de actuar. |
| No warning | AI did not identify warning signs in the assessed text. This does not guarantee safety or verify the sender. | La IA no identificó señales de advertencia en el texto evaluado. Esto no garantiza que sea seguro ni verifica al remitente. |
| Inconclusive | We could not reliably assess this message. No check was deducted. | No pudimos evaluar este mensaje de forma fiable. No se descontó ninguna consulta. |
| Unchecked link | This link was not checked. | Este enlace no se comprobó. |

Only show “no check was deducted” when authoritative accounting confirms it. While
settlement is unknown, use separate pending-accounting wording and reconcile the
original check; do not promise a deduction status or invite another paid attempt.

Publish a new independently pinned outcome/transport contract. Preserve candidate.1
bytes and its existing semantics. Add separate closed assessment-basis and AI
reason/copy codes; retain Google reputation evidence in its own evidence field.
Show provenance and missing coverage alongside findings, not hidden in fine print.
Both Android and iOS must eventually support the same semantic contract; Android
is the first implementation. An unsupported client must fail closed.

Version recovery receipts and maintain old-version reconciliation throughout their
seven-day lifetime. Android currently has an unversioned stored receipt and one
global reconciliation version. Its refresh reducer also preserves a high-risk
headline without necessarily preserving the actual prior threat evidence. Fix
both during contract migration; a later AI result must not erase independent
evidence. Do not silently reinterpret an old receipt under the new billing policy.

## Qualification before activation

Policy approval permits implementation; deployment, demonstrated quality and
activation remain distinct. Before enabling broader AI results:

1. Freeze the model version, prompt, rubric, output schema, contract and proposed
   quality thresholds before the final held-out evaluation. Separate English and
   Spanish performance, false alarms, missed warning signs and abstention rates.
   Establish numeric thresholds in a reviewable qualification plan; this draft
   does not claim accuracy or invent measured performance.
2. Use independently labeled held-out benign/scam examples and hard negatives,
   including quotes, negations, changing speaker roles, obfuscated text, mixed
   languages, missing context, sanitizer substitutions and adversarial instructions.
   A model grading itself or passing its own generated fixtures is insufficient.
3. Require zero observed violations in mandatory tests for disclosure, arbitrary
   actions/URLs, lost independent threat evidence, or charging partial/failed/
   inconclusive checks. This test gate is not a guarantee of zero production risk.
4. Verify both contract versions, retry/recovery, allowance races, deletion and
   explicit expiry; test EN/ES user-visible copy and degraded provider behavior.
   Preserve the already-linked physical/device acceptance follow-up ATCR-148.
5. Validate sanitized-data handling against the actual provider project settings
   and policy disclosure. `store:false` does not establish zero retention. Do not
   extend the approved seven-day application receipt policy to imply provider
   retention is also seven days. Keep campaign/demographic/commercial consent
   separate and optional; this proposal introduces no research contribution.
6. Qualify actual AI/AWS costs and independent attempt/failure budgets. Keep
   200 monthly completed checks and the 7-day/10-check trial unchanged. Partial
   requests still cost money, so enforce abuse limits, short deadlines, bounded
   output and circuit breakers independently of deductions. Start disabled; use
   controlled Dev qualification and an explicit rollback before user traffic.
7. Report metadata-only counts by language, policy/model version, result, coverage,
   failure reason and settlement state. Distinguish requests, unique checks and
   retries. Send actionable service alerts and a daily aggregate failure/usage
   report to the established support@andmorethings.com route. No message bodies,
   URLs, supporting spans or identifiable case details in logs or notifications.

## Work allocation after approval

- Lambda / SECUR4ALL-229 and 228: new inference path, privacy/adversarial controls,
  explicit abstention, independent-evidence preservation and evaluation evidence.
- Shared contract / SECUR4ALL-190: new version, provenance/copy/coverage codes,
  fixtures and compatible reconciliation. SECUR4ALL-230: completeness/settlement
  and provider attempt accounting; no change to the purchased allowance totals.
- Android / ATCR-120: pinned new contract, EN/ES labels, coverage presentation,
  evidence-preserving refresh and versioned recovery. iOS: corresponding linked
  story and same contract before iOS activation; do not assume Android completion
  closes iOS work.
- Infrastructure / SECUR4ALL-242: exact evaluator credential scope, reviewed
  disabled-by-default configuration, cost/failure monitoring and rollback; activate
  only after application and operational gates pass.

Owner review requested for the proposed AI scope, capped AI-only risk level, fixed
wording and complete-AI-check billing rule. These decisions have not been applied.

## Technical source notes

OpenAI documents that Structured Outputs can still contain mistakes; matching a
schema is not semantic verification. See [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs).
Its [API data controls](https://developers.openai.com/api/docs/guides/your-data)
describe standard abuse-monitoring retention and separate Responses storage
controls. This draft does not assert that this application's provider project has
approved zero data retention. The layered controls follow the concerns described
in [OWASP's prompt injection guidance](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html).
