# Dev closed Play lifecycle deployment

SECUR4ALL-244/125 selects reviewed Lambda source
`39cce61623794a123e61d25f5248b0c081eccf4a`, integrated by Lambda PR42 at
`d3eb738a10dc40e60012bf4c4d20104a13a2f36e`. Infrastructure definitions were
reviewed and integrated by PR56 at `3d308af120044c842bb9c76e593d7bf9bb10a379`.

The Lambda owner published thirteen full Python 3.14 ARM64 dependency packages
and verified exact S3 versions by independent download. This deployment selects
only eight functions: three new lifecycle handlers, existing Play handoff, and
four existing URL/authority handlers. The remaining message, recovery, feedback,
account-export and account-data packages remain published candidates; this change
does not provision or activate those services.

[Publication manifest](evidence/play-lifecycle-dev-2026-09-23/publication.json)
contains immutable versions, source hashes and deployed handler names.
[Saved-plan review](evidence/play-lifecycle-dev-2026-09-23/reviewed-plans.json)
contains only resource addresses/actions and private-plan fingerprints:

- play-lifecycle:55 creates, no updates/deletes. Existing foundation table/key are unchanged.
- play-verification:3 creates,2 updates; optional preparation route, scoped token
  permissions and pinned closed handoff code.
- url-consumer:8 updates, no creates/deletes; four functions and their aliases.

All preparation, purchase, authority, token cleanup, lifecycle and checkpoint-policy
gates remain false. Schedules and the deletion mapping remain disabled. The Dev
subject allowlist remains empty. No Google notification endpoint/subscription is
selected because the dedicated external identity is not yet verified. Preparation
inherits the existing API default throttle; its separate dedicated throttle must
be selected and verified after the closed route exists, before activation.

The exact saved plans were manually applied to Dev on 2026-09-23 UTC after
independent plan/source review and PR57 release integration at
`3fb3569357fbeb97da4eaf836409939e9f822434`. Applied counts matched all three
plans. Each fresh post-apply plan returned detailed exit code 0 (no drift).
[Applied summary](evidence/play-lifecycle-dev-2026-09-23/applied-summary.json)
and [configuration readback](evidence/play-lifecycle-dev-2026-09-23/runtime-readback.json)
confirm exact hashes/handlers/Python3.14 ARM64 for all 8 live aliases, no weighted
alias routing, false gates, empty applicable allowlists, two disabled schedules,
one disabled five-record deletion mapping and JWT-protected preparation route.
Execution roles have no attached managed policies; inline policy hashes are
recorded. Missing-heartbeat actions remain off.

Installed live versions: new ingress/worker/token-deletion1, Play handoff2,
URL consumer/lease recovery/entitlements7 and authority deletion6.
[Prior versions](evidence/play-lifecycle-dev-2026-09-23/prior-runtime-versions.json)
were recorded after verifying those five functions were already disabled.
[Independent publication download verification](evidence/play-lifecycle-dev-2026-09-23/publication-download-verification.json)
matched every one of the thirteen immutable objects. These configuration checks
do not invoke a handler or read account rows/secret values. Synthetic deployed
handler evidence is recorded separately by the Lambda owner. Neither local tests nor empty-event smoke prove Google
purchase/acknowledgment, renewal, token expiry/erasure or inventory qualification.
The proposed five-minute checkpoint policy still awaits the owner's decision.
Google Pub/Sub API enablement/configuration, account-deletion/export inventory,
qualified expiry and coordinated remaining writers remain explicit activation
dependencies. No physical testing or Android Actions are involved.

## Data-key permission correction

A post-deployment IAM simulation found that the original GenerateDataKey Allow
used unsupported `kms:DataKeySpec`. The simulator denied generation, and isolated
condition checks identified that condition. AWS documents
[`kms:EncryptionAlgorithm`](https://docs.aws.amazon.com/kms/latest/developerguide/conditions-kms.html#conditions-kms-encryption-algorithm)
for GenerateDataKey; it evaluates the symmetric algorithm used to encrypt the data
key even when the request has no explicit algorithm parameter. Replace the invalid
condition with `kms:EncryptionAlgorithm=SYMMETRIC_DEFAULT` in the foreground,
ingress and reconciliation roles. The Lambda request separately selects AES_256
and checks the returned key length. Exact CMK and purpose/environment restrictions
are unchanged. No processing was enabled and no customer operation used the old
permission.

[Corrective saved plans](evidence/play-lifecycle-dev-2026-09-23/kms-correction-reviewed-plans.json)
change only those three inline IAM policies. Root compared every before/after
policy and confirmed the single condition substitution is the entire change.
The nine lifecycle and eleven foreground Terraform cases pass, including a
regression against reintroducing the unsupported condition.
[Candidate identity-policy simulations](evidence/play-lifecycle-dev-2026-09-23/kms-correction-candidate-simulation.json)
passed28 per-resource evaluations: required secret reads, role-specific key
permissions and wrong-purpose/environment/extra-context denials. These simulations
do not invoke Secrets Manager/KMS or fully qualify SCP/key-policy/service behavior.
The independently reviewed saved plans from source
`da76e91f58078cd6289d50c71947814e12102835` were applied: exactly three inline
policy updates and no function/storage/activation changes. Both fresh affected
stack plans returned detailed exit code 0. All 28
[installed role identity-policy evaluations](evidence/play-lifecycle-dev-2026-09-23/kms-installed-permission-simulation.json)
then passed, and the refreshed eight-function readback preserved every closed
gate and disabled trigger. Simulation used per-resource results, which distinguish
the deletion role's allowed HMAC secret from its denied Google credential.

The Lambda owner's [PR44](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/44)
is merged at `b2a84785c0dfb2c10ba0b0485b7b33df8ca4e756`. Its eight empty-event
AWS checks returned the expected HTTP503 or enabled=false without FunctionError.
No provider/customer operation occurred. These calls qualify disabled entrypoints,
not enabled encryption, cleanup, allowance or Google transaction behavior.

## Closed Google callback deployment

After the manual Google setup recorded in [the notification runbook](PLAY-NOTIFICATION-SETUP.md),
PR61 selected verified subject `105021781538297478987` and merged into release-V01
at `c20a5ffca1160b86becf667f0d6e75ff8ecf1d77`. The independently reviewed saved
plan added seven callback resources and updated only the ingress function/alias.
The four Pub/Sub identity fields were the only environment changes. Nine lifecycle
Terraform tests and formatting checks passed; the exact saved plan was applied
and a fresh plan returned exit code 0 (no drift).

The actual callback URL is
`https://h8w7swnmqe.execute-api.us-east-1.amazonaws.com/v1/notifications/google-play`.
Its JWT audience remains the separate stable
`https://api-dev.andmorethings.net/v1/notifications/google-play` claim.
Ingress live alias is now version **2**, with the same immutable code hash as
version 1. Google issuer/audience, exact POST route permission, burst/rate limits
4/2, and metadata-only access log fields were verified through AWS readback.
Synthetic requests with missing authorization and an invalid bearer token both
returned **401**. These are authentication rejection checks, not proof of
authenticated Google delivery. Processing gates remain false and subjects empty;
no Google subscription, Play notification delivery or AWS cleanup was activated.

[Deployment evidence](evidence/play-lifecycle-dev-2026-09-23/callback-deployment.json)
and [callback readback](evidence/play-lifecycle-dev-2026-09-23/callback-readback.json)
record the applied scope and checks. This supersedes the initial deployment's
absence of a selected callback; export/deletion/cleanup and delivery acceptance
remain open.
