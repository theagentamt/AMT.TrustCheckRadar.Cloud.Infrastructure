# Recovery implementation and activation boundaries

The owner approved both sections of the recovery completion review on
2026-09-21. The immutable approval record is
[RECOVERY-COMPLETION-APPROVAL.md](RECOVERY-COMPLETION-APPROVAL.md).
The review SHA256 is
`173132b8d5a16d3d5a8ccdbc7355a631f8384634945772993200a3559c89da72`.

## Completed built-in dependencies

SECUR4ALL-163 and SECUR4ALL-234 are Done. The published Android default uses the
approved English/Spanish detailed playbook and deterministic selection contract.

| Repository | Reviewed source | Release merge | Pull request |
| --- | --- | --- | --- |
| Android | `bb0b4b3923cf011d29391fb9085590edc1b28101` | `3d40d514f055cba258102333ad18d22e1e5bd678` | [21](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/21) |
| Lambda artifacts | `8527af05dea8570722e909505028f1f25847cb23` | `fece1e640d82c180b4c4a158d02714e43d0e9b75` | [26](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/26) |
| Inactive infrastructure | `f973702fa7fdf67cae803679782b3de870c2556f` | `a00eaa550070ec9b313e1e2717aa5afbc8f72011` | [25](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/pull/25) |

Source ancestry, remote release heads, clean local release checkouts and unchanged
main heads were verified after these merges. All six source/merge heads had zero
GitHub Actions runs. Local gates passed: 2,063 Android host tests, 21 native emulator
cases, 303 Lambda artifact tests, 11 mocked Terraform tests and 44 infrastructure
helper tests. The independent artifact review also checked 1,304 ordering and
language permutations. Physical-device/spoken TalkBack testing remains ATCR-148;
these results do not claim completed human bilingual release QA.

## Recovery transport binding

The initial immutable service/client contract is Lambda commit
[`0528bfeb96508e14c3bc3535df82f62f15a24188`](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/tree/0528bfeb96508e14c3bc3535df82f62f15a24188/contracts/recovery-consumer/1.0.0-candidate.1).
Its manifest SHA256 is
`0fee081f312d0a7693f25684af1c7858156d3b93d2a5e3e57f923d49947a36f5`.
Policy approval and this engineering candidate are distinct from model
qualification and live endpoint availability.

The three authenticated POST operations are prepare, submit and reconcile under
`/v1/recovery-clarifications`. Prepare binds the exact reviewed projection and
versions to a proof without reserving allowance. Submit admits one logical check.
Reconcile uses only the minimal identity/proof; it does not repeat model work.
Changed text requires a new explicit preview and identity.

Only the fresh response can return transient suggested exposure/action IDs.
Receipts retain seven-day usage metadata without descriptions or suggestions.
Replay/reconcile can report a completed, charged check with `outcome: null` and
`resultAvailability: not_retained`. That is the explicitly approved lost-response
tradeoff. Complimentary accounts may have complete outcomes with zero charged
checks. Pending or unknown accounting must remain unknown; the client must not
infer a refund from an absent suggestion or HTTP status.

The mobile app retains its built-in guidance on every failure/cancellation path.
Suggestions require local Apply and cannot replace the person's selections without
confirmation. Account/device/request-generation and playbook-version fences apply.
Sensitive text and unapplied suggestions are foreground-only, with no history,
saved-state draft, content-bearing outbox or research contribution.

## Remaining operational qualification

The Terraform root is an inactive private Dev candidate. Every checked-in
environment remains disabled; no recovery route, provider activation, AWS apply or
paid evaluation is established by the source merges above. Runtime and Android
service acceptance remain under ATCR-121 / SECUR4ALL-235.

Before a manual Dev plan, bind immutable same-release consumer/evaluator ZIPs and
verify the exact package handlers in isolated archives. Shared-authority consumers
and the lease worker must include recovery usage validation if they process the
new scope. Pin required worker compatibility alongside a recovery rollout.

Before provider activation, supply recovery-specific model qualification covering
both languages, affirmative-self attribution, quotes/negation/hypotheticals,
uncertainty and adversarial input. Bind exact prompt/schema/playbook/settings and
provider retention policy. Message-classifier qualification and its earlier paid
experiment budget do not qualify this separate feature.

Use explicit Dev test-subject, authority timing/rate and provider-attempt/circuit
settings. The current transport timeout cap is 8,000 ms. Future secret access must
be narrowly reviewed: the inactive evaluator explicitly denies Secrets Manager,
so merely adding an Allow cannot activate it. Preserve metadata-only logging and
the existing support@andmorethings.com alert path. Native Lambda alarms are not
the separate daily logical-check/cost/failure report.
