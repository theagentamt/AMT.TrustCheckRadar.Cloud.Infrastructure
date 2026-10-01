# ATCR-121: exposure selection review

Status: proposed, not approved. Prepared 2026-09-21.

## What changes

Add a single multiple-choice question to signed-in post-scam help. People may
select any of the five existing categories. The app shows the relevant existing
English or Spanish paragraphs, once each, without asking for an incident narrative
or using AI. Existing approved recovery text and official destinations are unchanged.

This review covers the new selection behavior and interface wording below. It does
not repeat the approval of `recovery-basics-1.0` recorded in SECUR4ALL-163 comment
7-1198. SECUR4ALL-163 requires explicit content-approver review of exposure
combinations; the earlier approval explicitly excluded that extension.

## Proposed selection and display rules

Checkboxes use the five existing approved category titles, in their existing order:
opened a link; shared credentials/code; shared financial/identity information;
sent a payment; installed software/gave device access.

Selected paragraphs appear in this fixed presentation order:

1. Sent money, gift cards, or cryptocurrency.
2. Shared a password or verification code.
3. Shared financial or identity information.
4. Opened a suspicious link.
5. Installed software or gave device access.

Payment guidance goes first because the existing approved text calls for immediate
contact with the payment provider. These are presentation ranks, not a guarantee
of the best recovery sequence for every incident. The approved paragraphs remain
intact; this increment does not introduce new individual urgent/follow-up actions.

- Selecting a suspicious link also includes the device paragraph below it, because
  the approved link text refers to those steps if a download occurred. This does
  not assert that a download occurred or that the device is compromised.
- Multiple selections produce the union of their paragraphs, with no duplicates.
  Click order cannot change the resulting order.
- No selection, “I am not sure”, or “Show all basic steps” shows all five paragraphs.
- The account/limitations introduction and official-help section always remain.
- Selections stay only in screen memory. Clear them on leaving the screen,
  backgrounding the app, or changing/removing the account. No saved state, history,
  analytics, logs, research contribution, network request or shared link contains
  these choices.
- Until this proposal is approved, the questionnaire stays hidden and the existing
  approved all-basics screen remains available in its original order.

## Exact additional interface wording

The seven English/Spanish pairs below are the only proposed new interface text.
Category titles and recovery paragraphs reuse the existing approved snapshot.

| English | Spanish |
| --- | --- |
| What happened? Select all that apply. | ¿Qué ocurrió? Seleccione todas las opciones que correspondan. |
| I am not sure | No estoy seguro de lo ocurrido |
| Show all basic steps | Mostrar todos los pasos básicos |
| Choose categories only. These choices stay on this screen and are cleared when you leave or put the app in the background. | Elija solo categorías. Estas opciones permanecen en esta pantalla y se borran al salir o al poner la aplicación en segundo plano. |
| Built-in steps | Pasos incluidos en la aplicación |
| These bundled steps work offline while your account session permits access. Official websites require a connection. Guidance updates arrive with app updates; this screen does not check for updates. | Estos pasos incluidos funcionan sin conexión mientras su sesión de cuenta permita el acceso. Los sitios oficiales requieren conexión. La guía se actualiza con las actualizaciones de la aplicación; esta pantalla no busca actualizaciones. |
| AI explanations are not available in this version. Reading or choosing these built-in steps does not use an analysis check. | Las explicaciones con IA no están disponibles en esta versión. Leer o elegir estos pasos incluidos no consume un análisis. |

## Existing access and content policy carries forward

An account is required, using existing authenticated-session rules. No subscription
or remaining allowance is needed to view built-in help. This adds no offline login
or expired-session exception. No analysis check or provider call occurs.

Keep the original approval date (2026-09-20) and 180-day review-due notice, retaining
the basic text when review is due. App updates replace or withdraw bundles. Known
withdrawn/incompatible actual content is unavailable; an offline installation
cannot learn of a withdrawal until updated. New selector unavailability must not
withdraw still-approved basic content.

Official FTC/identity-recovery/reporting destinations remain the existing static
HTTPS links, opened only after explicit confirmation with the domain visible.
Attach no incident/account/query data and make no automatic report or reputation
request. AMT promises neither recovery nor human recovery support.

## Evidence and remaining scope

The current [FTC English recovery guidance](https://consumer.ftc.gov/articles/what-do-if-you-were-scammed)
and [Spanish recovery guidance](https://consumidor.ftc.gov/articulos/que-hacer-si-lo-estafaron)
were checked on 2026-09-21. They support prompt contact with payment providers;
the fixed combination ordering above is an AMT product proposal, not an FTC
prescribed sequence. No new recovery advice is introduced here.

This increment needs no new AWS resource or Lambda deployment. The Lambda
repository owns the shared, versioned contract and combination fixtures; Android
owns the on-device flow and lifecycle behavior. Infrastructure owns this cross-repo
handoff. iOS implementation is outside ATCR-121.

The optional AI explanation service does not exist yet. It remains unavailable
under SECUR4ALL-235; this review does not authorize a new model, provider call,
charge, activation or incident retention. Its failure/accounting acceptance cannot
be claimed from a disabled-capability test. More granular urgent/follow-up playbooks
also remain open under SECUR4ALL-163. ATCR-121 stays In Progress until its full
criteria are satisfied or the owner explicitly approves a documented scope change.
Physical-device/TalkBack qualification remains in the approved ATCR-148 follow-up;
independent bilingual qualification is not replaced by implementation tests.

## Decision

Approve these exact seven interface pairs and selection/display/privacy rules to
enable the deterministic selection increment, or specify edits. This is not a
request to declare ATCR-121, SECUR4ALL-163 or SECUR4ALL-235 complete.
