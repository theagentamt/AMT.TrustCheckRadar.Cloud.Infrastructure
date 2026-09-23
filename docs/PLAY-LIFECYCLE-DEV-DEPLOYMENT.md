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

This record initially describes the reviewed selection and plans, not an applied
runtime. Applied versions, readbacks and synthetic closed-handler checks will be
recorded after deployment. Neither local tests nor empty-event smoke prove Google
purchase/acknowledgment, renewal, token expiry/erasure or inventory qualification.
The proposed five-minute checkpoint policy still awaits the owner's decision.
Google Pub/Sub API enablement/configuration, account-deletion/export inventory,
qualified expiry and coordinated remaining writers remain explicit activation
dependencies. No physical testing or Android Actions are involved.
