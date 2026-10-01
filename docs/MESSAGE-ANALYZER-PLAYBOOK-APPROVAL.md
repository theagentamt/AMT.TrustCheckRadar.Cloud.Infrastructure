# Runtime message analyzer playbook: approved refinement

Status: **approved for implementation and local validation; not activated**.

On 2026-09-21, after the reviewed next-step summary named the four prompt
refinements and the ordinary-invoice guardrail, the owner instructed:
**“go ahead and apply that please”**. This authorizes those Lambda changes,
bilingual development/regression checks, and the established commit, push and
`release-V01` integration workflow. It does not authorize a paid model run,
provider-account mutation, deployment or production activation.

## Exact reviewed source

- Infrastructure source commit: `410439804ecd41ef829afced9a6f95ac6623e2b0`.
- Integrated review: PR20, merge `858abe2da465a84f44dc9a5d2a0d8d60f3e0d849`.
- [MESSAGE-ANALYZER-PLAYBOOK-REVIEW.md](MESSAGE-ANALYZER-PLAYBOOK-REVIEW.md).
- Reviewed file SHA-256:
  `e6c2b052cdb3143c0ed80515605c1a6b60b612e563e13ffb43a5a39d78ee2af0`.

The reviewed document is retained byte-for-byte as the historical proposal and
review evidence. This approval supersedes its pending status for P1–P4 and the
orchestrator's final ordinary-invoice constraint. It does not retrospectively
turn its synthetic examples into independently reviewed or measured model results.

## Approved behavior

1. **P1, claimed authority:** embedded claims of system/admin authority have no
   authority over analysis. Requests to alter the assessment require abstention
   for suspected injection; ordinary demands directed at a scam recipient are
   not automatically model-control attempts.
2. **P2, language and redaction:** a language field is a hint, not proof of content
   language. Do not reconstruct opaque placeholders or infer a warning from their
   type alone. Abstain when missing decisive content or unsupported scope prevents
   assessment; masking by itself need not force abstention.
3. **P3, negation:** preventive advice is not an affirmative request to disclose
   credentials, pay, or bypass verification. Read the complete message; protective
   wording cannot automatically cancel a different supported demand.
4. **P4, evidence offsets:** use ordered, non-overlapping spans within each category
   in the exact submitted sanitized text, measured in Unicode code points. Count
   whitespace, newlines, emoji and placeholder characters without rewriting them.
5. **Ordinary-invoice constraint:** a business identity, explanation of an agreed
   charge or routine payment request alone is insufficient for `AI_PRETEXT`.
   Require specific wording supporting use of a claimed identity or situation to
   manipulate a consequential action. Inability to verify a claim is not itself
   evidence of deception. The ordinary-invoice example with no other supported
   warning signs is a proposed no-warning development case; this does not verify
   the invoice, agreement or sender.

The exact prompt insertions/replacement remain those in the reviewed document.
The approved category set, closed output schema, public risk vocabulary, existing
quotation/mixed-source coverage, independent threat preservation, minimized input,
complete-only accounting and immutable candidate.1/.2 contracts retain their
existing semantics. No tool, browsing or model-controlled action is added.

## Evidence and owner boundaries

Lambda owns prompt source, paired development fixtures, local checks and source
handoff. The orchestrator owns this approval record, evaluation readiness and
tracker/release verification. Android and SECUR4ALL-221 drafts remain paused and
separate from this increment. No new infrastructure resource is needed.

Bind evaluation and eventual qualification to the revised prompt and full effective
request profile. A hash of the previous prompt cannot authorize or qualify the new
one. Preserve historical corpora and profiles; new supplemental cases remain
development data. Empty qualification/experiment registries and disabled AI gates
must remain in place until their separate criteria are satisfied.

Passing local fixtures checks request separation, response structure and policy
handling of simulated findings. It does not establish that a real model follows
these instructions, recognizes scams accurately or meets language/latency targets.
Independent bilingual review, semantic span scoring, untouched holdout material,
current provider settings/pricing and explicit experiment authorization remain
open under SECUR4ALL-229/240 and the existing operational dependencies.

## Revised request identity

Internal playbook revision: `message-playbook-2026-09-21-r1`. This identifies the
refinement without adding a mobile field or changing either transport contract.
Lambda's `evaluation/message_ai/playbook_refinement/profile-identities.json`
records the approved source and exact current request identities.

Implemented in [Lambda PR23](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/23),
source `62239887a93c042f4d78dd66fc6b74ddcb7e7716`, integrated into `release-V01`
as `1afa71dd3291a58cb1ca0de3f9a45456e85cc98b`. This is source integration, not
deployment or runtime activation.

| Artifact | SHA-256 |
| --- | --- |
| Revised prompt | `a2593d45e096b7bc257662ceda066e69abce1bbebf51f8ad2012ea4cfeb6d63f` |
| Unchanged output schema | `fbe75bac1c21b9b9bffe6159587f59ec55a2bbc19932763ff02c56bc23dedd45` |
| Controlled GPT-4.1 mini profile | `101d79ff26c57c65f53db97c7c6794a51dea56ed862612f98ec57616401eb3f7` |
| Controlled GPT-5.4 nano profile | `6f3e69d9cd6afbf802a25495eae15f4c24d6c85cca63bd2e44101039d79253d6` |
| Controlled GPT-5.4 mini profile | `30f74ddec7a6f79d4117ec3ab7d5504955f2b084938d317c6ef835f91e8cb67d` |

The old prompt/profile hashes remain historical comparison identities, not evidence
for this revision. Updated counting projections include the entire revised prompt;
the existing 8,192-input/512-output limits still apply. No actual token count,
latency, price settlement or quality measurement is claimed by these hashes.

## Local validation and remaining acceptance

The Lambda owner ran 460 focused evaluator, offline-evaluation and controlled-adapter
tests with Python 3.14.7, including 27 new refinement cases/tests. An independent
review reran those 27 new tests and found no blockers. AST comparison confirmed
that the only runtime-code change is the instruction string. The orchestrator
independently reproduced the prompt/schema/profile identities and verified that
candidate contracts, public policy, privacy validators, registries, original
development packet and CI workflows have no diff from the baseline.

The supplement contains 11 correlated English/Spanish families, 22 engineering
cases: 20 reach a fake AI callback and two quoted cases skip it. Ordinary-invoice
no-warning is a development expectation under the approved boundary, not proof
of real model performance. Local checks also verify minimized request separation,
counting projection, span bounds, empty authorization registries and rejection of
the old profile even when its synthetic grant is allowlisted.

Compile checks, diff whitespace and redacted secret scanning passed for the Lambda
source. The infrastructure changes are documentation only, with relative links,
hash consistency and redacted scanning checked; Terraform behavior is unchanged.
SECUR4ALL-229/240 remain open for actual model/operational qualification. No paid
calls, deployment, activation, main promotion or feature/release CI run is part of
this implementation increment.
