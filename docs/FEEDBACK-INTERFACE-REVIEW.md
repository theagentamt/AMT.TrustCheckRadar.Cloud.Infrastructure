# ATCR-122 proposed interface wording

Draft implementation copy for the owner's bounded feedback policy review. No approval, service availability, receipt retention, or research permission is inferred from this packet.

| Key | English | Español |
|---|---|---|
| feedback_title | Give feedback on this result | Opina sobre este resultado |
| feedback_question | What would you like to report? | ¿Qué quieres informar? |
| feedback_legitimate | I think this is legitimate | Creo que esto es legítimo |
| feedback_scam | I think this is a scam | Creo que esto es una estafa |
| feedback_unclear | The result is unclear | El resultado no está claro |
| feedback_unhelpful | The result was not helpful | El resultado no fue útil |
| feedback_privacy | Only your selected category and the identifiers needed to link it to this result are sent. The original message, image, and URL are not sent again. | Solo se envían la categoría seleccionada y los identificadores necesarios para vincularla con este resultado. El mensaje, la imagen y la URL originales no se vuelven a enviar. |
| feedback_boundary | Feedback does not change this result or use an analysis check. This is not a live support service, and a personal reply is not promised. | Tus comentarios no cambian este resultado ni consumen una revisión. Este no es un servicio de asistencia en vivo y no se promete una respuesta personal. |
| feedback_send | Send feedback | Enviar comentarios |
| feedback_sending | Sending feedback… | Enviando comentarios… |
| feedback_already_received | Feedback was already received for this result. No additional report was saved. | Ya se recibieron comentarios sobre este resultado. No se guardó otro informe. |
| feedback_received | Feedback received. Your original result is unchanged. | Comentarios recibidos. Tu resultado original no ha cambiado. |
| feedback_unconfirmed | Delivery is not confirmed. You can retry this same report. | No se ha confirmado la entrega. Puedes volver a intentar enviar el mismo informe. |
| feedback_retry | Retry this report | Reintentar este informe |
| feedback_denied | Feedback cannot be accepted for this result. Your original result is unchanged. | No se pueden aceptar comentarios sobre este resultado. Tu resultado original no ha cambiado. |
| feedback_sign_in | Sign in to send feedback on your own result. | Inicia sesión para enviar comentarios sobre tu propio resultado. |
| feedback_unavailable | Feedback is unavailable in this version. Your original result is unchanged. | Los comentarios no están disponibles en esta versión. Tu resultado original no ha cambiado. |
| feedback_cancel | Cancel | Cancelar |
| feedback_wait | Please wait before retrying this report. | Espera antes de volver a intentar enviar este informe. |

## Concrete integration points

- `MessageCheckScreen`: validated settled receipt + the displayed current message assessment with identical check ID and transport version (candidate1 or candidate2), authenticated foreground account, nonnull proof and receipt ID. No inference from a legacy score or parser-only fixture.
- `UrlCheckScreen`: validated settled receipt + displayed current URL assessment with identical check ID, fixed URL consumer contract, authenticated foreground account, proof and receipt ID. QR uses this same native route and receipt family.
- If a sticky older threat assessment is preserved across a failed or contradictory refresh, do not link it to an unrelated/new receipt or claim current eligibility. An exact target must remain tied to the displayed assessment's immutable check and retained owned result.
- No standalone feedback form without a result. No feedback on local preview, invalid input, pending/unknown receipt, legacy historical results, or recovery clarification in this slice.
- Keep report intent/category/ID in foreground memory only. Freeze category/identity on first send. Repeated taps cannot create concurrent reports. Explicit retry reuses exact intent; no automatic retry or background outbox. Cancel, background, account/result switch clears local form and ignores late responses; never assert remote cancellation or erasure.
- Backend enforces one report per retained result, so returning/recreating cannot create unlimited duplicate stored reports even if the transient client ID is lost.
- Account authentication is required; no paid/provider access lookup should gate this private report. Server ownership/deletion/expiry remains authoritative.
- Unconfirmed includes timeout/offline/response loss. Do not say “not sent” after uncertain dispatch. Only an authoritative accepted/already-accepted acknowledgment can display received.
