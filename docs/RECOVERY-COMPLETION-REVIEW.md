# ATCR-121: remaining recovery policy for review

Status: DRAFT. Prepared 2026-09-21. This is the next review, not a condition on the
already-approved selection flow. Selection approval is SECUR4ALL-163 comment
7-1315; its exact wording and behavior may now be enabled.

## 1. Detailed built-in playbooks

Split the existing approved paragraphs into the actions below. Use two headings:
**Do now / Qué hacer ahora** and **Follow-up / Seguimiento**. These are useful
presentation groups, not personalized triage or a promise that delay is safe.
All immediate actions appear before follow-up actions. Within each group use the
listed rank; selection click order never changes the plan. Show each action once.

The account/limitations introduction, category headings, fixed official links and
existing review/session/withdrawal rules remain unchanged. Each selected category's
limits remain visible, even when there is no actionable follow-up. No incident
narrative, case record or progress history is collected by built-in guidance.

All action text below is extracted verbatim from the existing approved English and
Spanish snapshot. The one replacement link-to-device note is explicitly listed
after the table. Splitting and grouping the text is a new presentation policy,
which SECUR4ALL-163 requires the designated approver to review.

| ID / phase / rank / category | English | Spanish |
| --- | --- | --- |
| `payment_contact`; Now / Ahora; 10; `sent_payment` | Immediately contact the bank, payment service, gift-card issuer, or cryptocurrency exchange/operator you used. Report the scam and ask whether the payment can be reversed. | Contacte de inmediato al banco, servicio de pagos, emisor de tarjeta de regalo o proveedor de criptomonedas que utilizó. Informe la estafa y pregunte si pueden revertir el pago. |
| `account_secure`; Now / Ahora; 20; `credentials_or_mfa` | Open the service's known app or website. Change the affected password and any reused passwords, and turn on multifactor authentication. If you cannot sign in, use that service's account-recovery process. | Abra la aplicación o el sitio web conocido del servicio. Cambie la contraseña afectada y las contraseñas reutilizadas; active la autenticación multifactor. Si no puede iniciar sesión, use el proceso de recuperación del servicio. |
| `financial_contact`; Now / Ahora; 30; `financial_or_identity` | Contact your bank or card issuer through its official app or the number on your card. | Contacte a su banco o emisor de tarjeta mediante su aplicación oficial o el número de su tarjeta. |
| `link_stop`; Now / Ahora; 40; `clicked_link` | Stop using the suspicious page. | Deje de usar la página sospechosa. |
| `device_secure`; Now / Ahora; 50; `software_or_remote_access` | Follow your device manufacturer's security guidance. Update security software, scan for threats, and remove detected problems. | Siga las indicaciones de seguridad del fabricante. Actualice el programa de seguridad, busque amenazas y elimine los problemas detectados. |
| `payment_receipts`; Follow-up / Seguimiento; 10; `sent_payment` | Keep receipts. | Guarde los recibos. |
| `identity_steps`; Follow-up / Seguimiento; 30; `financial_or_identity` | For exposed identity information, visit IdentityTheft.gov for steps specific to your situation. | Para información de identidad expuesta, visite RobodeIdentidad.gov y consulte los pasos para su situación. |
| `link_verify`; Follow-up / Seguimiento; 40; `clicked_link` | Contact the claimed organization through its known app or website. | Contacte a la organización mediante su aplicación o sitio web conocido. |
| `device_support`; Follow-up / Seguimiento; 50; `software_or_remote_access` | Use trusted manufacturer support if you need help. | Si necesita ayuda, recurra al soporte de confianza del fabricante. |

For link selections, also include the device actions, with this conditional note:

- EN: **If you downloaded something suspicious, also use the device guidance.**
- ES: **Si descargó algo sospechoso, consulte también las indicaciones para el dispositivo.**

This replaces the old reference to device steps “below”; it does not infer a
download or compromise. Show the note for link-only dependencies and every empty,
unsure or Show-all fallback. Omit it only when software/device access was explicitly
selected in a non-fallback plan. Empty, unsure or Show all includes all actions and all category limits.
Always append the approved official-help paragraph and its confirmed external
navigation. “Follow-up” does not imply AMT will contact anyone or open an incident.

Keep these exact existing category limits beside their relevant guidance:

| Category | English | Spanish |
| --- | --- | --- |
| `clicked_link` | Opening a link alone does not establish whether your device or accounts were compromised. | Abrir un enlace por sí solo no permite determinar si sus cuentas o dispositivo están comprometidos. |
| `credentials_or_mfa` | A shared verification code may allow account access; changing a password alone does not establish that access has ended. | Un código compartido puede permitir el acceso a su cuenta; cambiar la contraseña por sí solo no confirma que ese acceso haya terminado. |
| `sent_payment` | Recovery is not guaranteed. | No se garantiza recuperar el dinero. |
| `software_or_remote_access` | AMT cannot verify that the device is clean. | AMT no puede verificar que el dispositivo esté libre de amenazas. |

**Combination algorithm:** form the union of actions for selected categories;
include device actions when link is selected; sort by phase (now, follow-up) then
rank; remove duplicate action IDs; retain all applicable limits and the common
introduction/official-help section. Every one of the 32 exposure subsets must have
matching EN/ES expected fixtures. Empty/unsure is explicitly all five categories.
An invalid/withdrawn/incompatible new bundle falls back only to an independently
approved, compatible basic bundle; never synthesize replacement instructions.

Approval creates a separate immutable `recovery-playbook-1.0` bundle. It does not
rewrite the original basic text's approval date. The new bundle receives its own
approval/review metadata; future changes need a new version. Existing 180-day
review-due notices and app-update-only distribution remain in effect.

## 2. Constrained optional AI clarification

The model's role is to suggest which approved exposure categories apply to the
person's description. It cannot author recovery instructions or contacts. Render
only reviewed bilingual text through closed IDs; do not render model prose, links,
phone numbers, payment destinations or quoted source text.

### Classification and uncertainty

- Only a person's stated actions/exposures support a suggestion. A scammer's
  request, a quoted threat, a negated action, a hypothetical or another person's
  experience does not prove that the current user did it.
- Preserve uncertainty. Do not infer compromise, successful payment, malware
  removal, loss amount, identity theft or recovery from a description alone.
- Model output may select only the five known exposure IDs and the corresponding
  grounded actions in the exact approved bundle. The deterministic selector, not
  the model, determines action order, dependencies and the final displayed plan.
- Ambiguous wording returns uncertainty and these existing category choices;
  it does not start an open-ended interview or generate another question.
- The result is a suggestion. It does not overwrite the person's manual choices
  without an explicit Apply action. Cancellation, failure, malformed output and
  stale results leave the current built-in plan intact.
- Treat the description as untrusted data. Ignore instructions inside it. Reject
  output with extra fields, unknown IDs, invented contacts, stale bundle/version,
  unsupported claims or nonconforming types; return a non-chargeable inconclusive
  outcome. Structural validation does not replace adversarial model evaluation.

### Exact proposed clarification interface text

| Purpose | English | Spanish |
| --- | --- | --- |
| Entry | Help me choose the relevant steps | Ayúdeme a elegir los pasos pertinentes |
| Input instruction | Briefly describe what you did. Do not include names, passwords, verification codes, account numbers, or contact details. | Describa brevemente lo que hizo. No incluya nombres, contraseñas, códigos de verificación, números de cuenta ni datos de contacto. |
| Preview/submit notice | Review the cleaned description before sending it for AI clarification. A completed clarification uses one analysis check. Built-in guidance remains available without using a check. | Revise la descripción depurada antes de enviarla para una aclaración con IA. Una aclaración completa consume un análisis. La guía incluida sigue disponible sin consumir un análisis. |
| Submit | Request clarification | Solicitar aclaración |
| Suggested result | These categories may fit what you described. Review them before applying them to your steps. | Estas categorías podrían corresponder a lo que describió. Revíselas antes de aplicarlas a sus pasos. |
| Apply | Apply these categories | Aplicar estas categorías |
| Uncertain | There is not enough information to suggest categories. You can choose them yourself or show all built-in steps. | No hay información suficiente para sugerir categorías. Puede elegirlas o mostrar todos los pasos incluidos. |
| Unavailable or failure | AI clarification is unavailable. Your built-in guidance is still available. | La aclaración con IA no está disponible. Su guía incluida sigue disponible. |
| Cancel | Cancel clarification | Cancelar aclaración |
| Receipt unresolved | The check status is still being confirmed. You can keep using built-in guidance. | Todavía se está confirmando el estado del análisis. Puede seguir usando la guía incluida. |

These add no promise that a submitted request was refunded or never counted.
The receipt, not screen dismissal, determines the final usage outcome.

### External data and retention

Proposed limits: the device accepts at most 2,000 Unicode code points before
sanitization. Both device and backend enforce at most 2,000 Unicode code points
and 8,000 UTF-8 bytes for the cleaned description; the entire request body including
metadata is capped at 32,768 UTF-8 bytes. The backend cannot prove original length
without receiving the original, which it must not do. Reject oversize/unsupported
input before reservation/model work; do not truncate and silently change meaning.

The device sanitizes the description and presents the cleaned text for explicit
confirmation. The backend independently validates it against the same projection
rules. If further edits are needed, reject before reservation/model work and
require a fresh cleaned-text preview and confirmation; do not silently rewrite
identity-bound text. This recovery projection removes detected URLs, domains,
email addresses, phone numbers, financial and government identifiers, passwords/
codes and other detected identifying details;
attacker identifiers are unnecessary for selecting recovery categories. Preserve
only neutral typed placeholders when needed to understand exposure categories.
Names or identifiers missed by rules must not be described as guaranteed anonymous.
Reject unsupported/unsafe projections rather than forwarding raw fallback text.

The model request contains only the confirmed sanitized description, EN/ES language,
versioned classification instructions and the allowed exposure/action IDs. Never
send the original description, account/device ID, subscription details, receipts,
demographics, research consents, history or a user-supplied contact destination.
Built-in/manual selections never leave the app. The provider and backend transiently
process suggested IDs; Apply is local-only and does not upload or persist choices.
Raw descriptions, cleaned previews and unapplied suggestions stay only in volatile
foreground screen state and clear on exit, backgrounding or account change. Never
put them in saved state, draft storage or an outbox. Only minimal account-bound
request identity/status metadata may use the existing reconciliation mechanism
and retention rules. Provider requests remain ephemeral and
must use the approved provider retention configuration; no prompt/output content
belongs in application logs, traces, analytics, research or stored receipts.

No new incident-history storage is proposed. A minimized usage receipt uses the
already-approved seven-day result/usage retention, containing IDs/status, versions,
usage outcome and expiry only, without descriptions or selected exposure/action
IDs. Reconciliation after a lost response may confirm usage without recovering the
sensitive suggestion; the app keeps the manual guidance and does not auto-resubmit.
A complete check settled before a response was lost can therefore count even
though the suggestion cannot be recovered from its receipt. Show authoritative
usage honestly; never present a missing suggestion as a delivered result.

### Access, completion and charging

- Signed-in account, active seat/device and shared external-service entitlement are
  required for the optional request. Subscription/trial allowance or an authorized
  unlimited-account entitlement follows the existing policy. Built-in help remains
  independent of those external-service checks.
- One explicit request is one logical check, with idempotent prepare/submit/status
  handling. Technical retries never create another deduction. No automatic extra
  model call or paid follow-up is made to resolve uncertainty.
- **Proposed complete result:** a validated, nonempty exposure suggestion grounded
  entirely in the approved bundle, committed successfully to authoritative usage
  settlement. Applying the suggestion is optional and does not create another check.
- Abstention, ambiguity, no supported exposure, malformed output, provider failure,
  partial response, stale bundle and rejected input are not complete and consume
  no check. Release reservations idempotently through the existing authority.
- Before confirmation, cancellation makes no external request. If preparation
  already occurred but no model dispatch happened, abort/expire that preparation
  safely without a model call or deduction. Once dispatch happened or is uncertain,
  cancellation does not imply a refund: return immediately to built-in help and
  reconcile the original check. A complete, settled request can count after the
  user leaves. Failed/inconclusive requests do not count. Do not fabricate a charge
  or refund locally; server receipts remain authoritative.
- Fence responses by account, device binding, request generation and bundle version.
  Late responses cannot alter another account's or a newer session's plan.

These are proposed recovery-specific semantics, not an assertion that the live
service exists. Offline validators/state machines may be built now. A real model
must separately pass bilingual ambiguity, prompt-injection, invented-contact,
privacy and grounding evaluations before provider activation. Existing message
analysis evaluation does not qualify recovery clarification.

## 3. Completion and deployment evidence

To close ATCR-121 and its dependencies, record approval and immutable content/schema
pins; verify Android's actual default; exercise all combinations and EN/ES text;
test the governed optional service with complete/inconclusive/failure/cancel/retry/
exhaustion and account-switch cases; demonstrate server settlement and preserved
local help; and commit, push, review and integrate all changes into `release-V01`.
Do not close missing criteria by calling a disabled capability complete.

Infrastructure follows the agreed final service contract: a distinct recovery
consumer/evaluator boundary, least-privilege IAM, existing secret/provider controls,
bounded concurrency/timeouts, privacy-safe metrics and support@andmorethings.com
alerts. This review does not deploy resources or activate a paid model. Exact AWS
changes and plan are prepared once the runtime/authority interface is stable.
Physical-device/spoken TalkBack qualification remains the existing approved
ATCR-148 follow-up; independent bilingual qualification is a separate release gate.

## Sources and decision

The action table rearranges the user-approved recovery-basics-1.0 text rather than
introducing additional financial/legal advice. Current [FTC English recovery guidance](https://consumer.ftc.gov/articles/what-do-if-you-were-scammed),
[FTC Spanish recovery guidance](https://consumidor.ftc.gov/articulos/que-hacer-si-lo-estafaron)
and [FTC tech-support scam guidance](https://consumer.ftc.gov/articles/how-spot-avoid-and-report-tech-support-scams)
were reviewed on 2026-09-21 for consistency. The ordering and charging definitions
are AMT product proposals, not FTC-prescribed rules.

Approve sections 1 and 2 as the detailed content and recovery-specific AI policy,
or identify edits. No repeat approval of the existing selector is requested.
SECUR4ALL-163 requires approval of the granular playbooks; SECUR4ALL-235 requires
grounded approved guidance and defined usage behavior. Those semantic decisions
must be recorded before enabling them. Ordinary engineering and offline tests
continue while this exact packet is reviewed.
