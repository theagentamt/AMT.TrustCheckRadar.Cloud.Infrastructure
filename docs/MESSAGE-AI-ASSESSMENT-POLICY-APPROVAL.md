# V1 broader AI assessment policy — approval record

Status: **APPROVED FOR IMPLEMENTATION; NOT ACTIVATED**.

On 2026-09-21 the owner replied **“approved”** to the completed broader AI policy
review. That approval covers the proposed scope, capped AI-only risk level, fixed
English/Spanish wording and complete-AI-check billing rule. It does not claim
provider/model qualification, deployed infrastructure, mobile readiness or release
acceptance.

## Exact approved source

- Repository: `AMT.TrustCheckRadar.Cloud.Infrastructure`
- Source commit: `8cc87c59f8d74dbc14a3dd810bea33cef43ca1dd`
- File: [MESSAGE-AI-ASSESSMENT-POLICY-PROPOSAL.md](MESSAGE-AI-ASSESSMENT-POLICY-PROPOSAL.md)
- SHA-256: `d6e9fff12225540bef9ba7833cce457cca4b9c791af3b49dd8a4f1601d204349`
- New policy version: `message-ai-2026-09-21-v1`
- New transport version: `1.0.0-message-candidate.2`
- Verified tracker approval comments: SECUR4ALL-229 `7-1244`, SECUR4ALL-190
  `7-1245`, SECUR4ALL-230 `7-1246`, SECUR4ALL-242 `7-1247`, ATCR-120 `7-1248`,
  and ITCR-92 `7-1249`.

The historical proposal is retained byte-for-byte, including its draft heading.
This record supersedes that heading's approval status. It does not rewrite the
existing candidate.1 contract or its `message-rules-2026-09-20-v1` policy.

## Approved behavior

Clearly label probabilistic AI findings, keep AI-only findings at suspicious or
no-warning, and preserve independent high-risk evidence. Use closed categories
and fixed bilingual explanations rather than model-generated actions or text.
Unsupported, ambiguous, hostile, contradictory or incomplete input cannot become
a fabricated reassuring result.

A fully completed qualified AI assessment can consume one check, including a
no-warning result. Partial, failed and inconclusive checks consume none. Actual
hostile stops remain blocked/unknown, with supported independent threats retained.
Authoritative settlement determines deductions; uncertainty remains pending until
reconciliation. Monthly/trial allowances and approved retention are unchanged.

Candidate.2 must bind new requests and receipts to their own contract and policy.
Candidate.1 retries and receipts retain their original semantics throughout the
seven-day recovery period. Initial Android links remain withheld and partial;
future complete joint text/link coverage needs separate implementation and
qualification.

## Remaining gates and owners

Lambda owns SECUR4ALL-229/228 implementation and SECUR4ALL-190/230 contract and
accounting dependencies. Android owns ATCR-120 binding, bilingual presentation,
versioned receipt migration and evidence-preserving refresh. ITCR-92 retains the
corresponding iOS implementation dependency; Android-first completion does not
close it. Infrastructure owns SECUR4ALL-242 configuration, exact credential scope,
monitoring and rollback.

Model/prompt/schema selection, predeclared numerical quality thresholds, held-out
independent bilingual evaluation, actual provider data controls, cost and abuse
budgets, runtime qualification and operational reporting remain activation gates.
SECUR4ALL-237/243 retain the reporting and operations dependencies. ATCR-148 retains
the previously agreed physical/device acceptance. Policy approval does not supply
missing evidence or approve unrelated prospective retention/reporting settings.

All implementation is integrated through `release-V01`, with local validation and
verified GitHub publication. No activation or main release is implied by this
approval record.
