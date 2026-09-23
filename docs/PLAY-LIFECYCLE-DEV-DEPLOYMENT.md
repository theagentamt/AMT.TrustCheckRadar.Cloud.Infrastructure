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
