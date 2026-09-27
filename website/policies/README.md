# SECUR4ALL-92: bilingual policy review package

**Draft, not effective or published.** This directory is a reviewable replacement
for the three current public policy pages, plus Spanish equivalents. It is not
a website deployment, store submission, activation or legal-compliance claim.

Owner confirmed on September 27 that **AndMoreThings Labs LLC** and the monitored
**privacy@andmorethings.com** contact remain correct. Owner selected in-app deletion
as primary and a verified email fallback for V1; no automated web flow is authorized.
An email is a request, not proof of ownership or authority to erase an account.

## Owner decisions approved September 27, 2026

- Real V1 customer submissions must not be opted into provider model-training
  sharing. Actual OpenAI organization/project settings remain unverified; this
  decision does not claim Zero Data Retention or change provider settings.
- Support correspondence is to be deleted 30 days after resolution. The owner
  reports no current rule. Identify the mail provider and closure mechanism,
  configure the rule, and check trash/archive/backup exceptions before publishing
  an enforced deadline. Any separate verification audit needs its own policy.
- Send independent deletion confirmation to the verified email already on the
  account; do not rely on the incoming sender or a requester-supplied replacement.
  Only after verified explicit intent may an authorized operator proceed. Lost
  mailbox access requires a separately reviewed recovery path. SECUR4ALL-333 must
  qualify this actual workflow; no new public web portal was authorized.

These approvals supersede the earlier unanswered policy questions, but do not
resolve operational verification. Draft paragraphs explicitly distinguish the
approved target from settings that have not yet been implemented or inspected.

## Preview and source

Edit `content/en/*.html` and matching `content/es/*.html`, then run:

```sh
python3 website/policies/render.py
python3 -m http.server 8092 --bind 127.0.0.1 --directory website/policies/preview
```

Open `http://127.0.0.1:8092/privacy-policy/`. All six pages have reciprocal language
links and localized navigation. Existing canonical English paths remain unchanged.
Android EN/ES currently open the same canonical URLs; readers can select Spanish
on the site without a mobile allowlist change. Direct Spanish mobile URLs would
require a separate reviewed allowlist change. No scripts, forms, external fonts,
tracking or deployment credentials are added. The preview is deliberately marked
DRAFT with no effective date and noindex. The renderer has no publish mode.

## Evidence and decisions

- Android PR45/source `5260a8865c2682959069997e4012a21eee64fa7d`: actual signup
  includes name, email, phone, password and adult Boolean; local OCR/QR, exact URL
  allowlist, protected account storage and ordinary feature gates. No automatic
  SMS/contact/call-log/notification collection found. A +1 validation is not proof
  of US residence; the policy states the intended US offering, not enforcement.
- Lambda PR77/source `19cb7a7096f1f9b231ff9eb603a5a2e45343649c`:
  [backend attestation](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/blob/19cb7a7096f1f9b231ff9eb603a5a2e45343649c/docs/backend-retention-attestation-2026-09-27.md).
  The subsequent SEC332 numeric-counter correction changes no retention policy.
- [Infrastructure reconciliation](../../docs/ATCR-95-RETENTION-RECONCILIATION.md):
  current Dev TTL/PITR/log configuration, public drift and limits of that evidence.
- [Approved account-data decisions](../../docs/ACCOUNT-DATA-POLICY-DECISIONS.md):
  recovery/audit intervals, direct export, deletion acceptance/local cleanup,
  restoration and suppression boundaries. Existing owner-approved plan: $4.99,
  200 completed checks/period, explicitly activated 7-day/10-check trial.
- [Google Play account deletion guidance](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en):
  outside-app request path required; an email path can qualify. In-app-only
  redirection cannot serve users who uninstalled the app. This is a policy-source
  review, not evidence of approval by Google or fulfillment of an email request.
- [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data):
  documented defaults distinguish application state from abuse monitoring; defaults
  do not attest this account's data-sharing, retention or regional controls.
- [Web Risk lists](https://docs.cloud.google.com/web-risk/docs/lists) and
  [Google service terms, section 46](https://cloud.google.com/terms/service-terms):
  Lookup sends the actual URL. Do not apply the separate Evaluate/Submission reuse
  clause to Lookup by assumption. Exact Lookup request retention remains unverified.
- [FTC privacy guidance](https://www.ftc.gov/business-guidance/privacy-security/consumer-privacy):
  public representations must match actual practices. No blanket compliance
  certification or state-law applicability determination is made here.

## Change map

| Existing public claim | Replacement |
| --- | --- |
| SecurityForAll; account optional | TrustCheck Radar; account required; operator preserved |
| Screenshots/images uploaded | Current analysis images processed locally; reviewed text/URLs leave device |
| Broad research permission through use/terms | Independent optional research; separate demographic/commercial choices; unavailable features clearly conditional |
| Sanitized/de-identified means anonymous | Residual identifying context and purpose-bound pseudonymous records disclosed |
| Generic indefinite retention | Distinct receipts, History, security, purchase, consent, research, deletion and backup limits |
| Data deletion equals immediate total erasure | Acceptance, local cleanup, server completion, retained suppression and independent copies distinguished |
| Credits and unspecified premium features | Approved individual allowance/trial, completed-only deductions, no automatic overage |
| One English page | Six linked EN/ES drafts with consistent material meaning |

## Required before effective publication

1. Confirm the actual supported email verification/execution/response procedure,
   including requests from people unable to use the app. Do not promise a working
   route merely because a mailbox exists. No credential collection or synthetic
   user token is acceptable. Any missing operator adapter remains implementation.
2. Establish support-mail retention and provider account/contract practices. Do not
   infer zero retention, no training opt-in, a specific processing country or
   erasure of processor records from `store:false` or our TTL. Record the actual
   OpenAI controls and Google agreement, and reconcile provider erasure requests.
3. Reconcile the exact release's gates/SDKs and iOS differences before implying
   both platforms ship the Android behavior. Conditional source capability is not
   a claim that general export, research or online checks are currently enabled.
4. Review final public EN/ES language, existing liability/governing-law clauses,
   applicable privacy-request rights and any required notices with the owner and
   qualified policy reviewer. Terms changes here are limited to product alignment;
   no new venue, arbitration, sale permission or waiver is introduced.
5. Remove editorial review paragraphs only after resolving their facts, approve an
   effective date and exact final text, then perform the reviewed publication.
   The current draft renderer intentionally does not produce publishable output.
6. Verify public bytes, language navigation and current in-app links; align actual
   store forms in SECUR4ALL-94. ATCR-95 retains its policy/store dependency.

These are concrete unfinished acceptance items, not manual QA that can be silently
moved out of the story. No change to data collection/retention is implied.

## Publication and rollback preparation

Current serving assets identified read-only: CloudFront `E1ESXUYOU4XS2A`, alias
`andmorethings.com`, S3 origin `temp-web-root` (empty OriginPath), existing keys
`privacy-policy/index.html`, `terms-of-use/index.html`, `data-deletion/index.html`.
No authoring repository/CMS was established; this directory versions the candidate
replacements without claiming ownership of the remainder of the website.

Before a later authorized upload, read the distribution's current routing/cache
settings and exact object metadata and preserve old bytes/version IDs/hashes for
all touched keys. Verify how `/es/<page>/` resolves; do not assume CloudFront uses
nested index.html routes. Use reviewed routing/configuration if needed. Publish
only the six approved page objects (and any separately reviewed routing change),
with explicit content-type/cache metadata and private origin access preserved.
Invalidate only affected canonical and object paths; verify public status, bytes,
links, EN/ES selection, layout and no accidental draft markings. Rollback restores
the preserved bytes/metadata or deletes only newly introduced Spanish keys, then
invalidates the same paths. Do not replace unrelated root/style/script assets.
Record evidence and exact Git/source/object revisions before closing the story.

## Later release QA handoff

Reuse ATCR-62's existing policy/link checks and ATCR-148 for physical-only work.
For the actual released APK, record build/configuration and open privacy/terms
from Settings in EN and ES, follow the site language selector, check deletion is
prominent without login, and compare the pages to the approved manifest. Check
large text, keyboard/screen reader semantics and no clipping. A mailto link opening
is not delivery, verification or erasure evidence. Execute an email deletion
journey only against a separately authorized disposable account using the approved
procedure, then independently verify completion and unrelated-data preservation.
Record unexecuted cases as pending. No UAT, Production, physical or destructive
test is authorized by this handoff; required publication validation remains here.

## Validation recorded on September 27

Independent review found material EN/ES parity and supported retention/consent
boundaries. Its two findings were corrected in both languages: in-app deletion
now precedes the email fallback, and local cleanup requires Android to receive
and validate matching acceptance. Six generated hashes, embedded fragments,
HTML language/headings, draft/noindex markers and local destinations were checked.
English and Spanish privacy pages were visually inspected in the local in-app
browser; this is not a physical-device or screen-reader test.

Read-only live CloudFront routing inspection found viewer-request function
`to_index_function` (ETag `ETVPDKIKX0DER`) appends `index.html` to slash paths and
`/index.html` to extensionless paths. Thus the proposed `/es/<page>/` URLs use the
existing nested-index rule; no routing mutation is currently indicated. The
original distribution config ETag was `E1VC38T7YXB528`. Re-read before publication
rather than assuming these resources stayed unchanged. No S3 write, CloudFront
update or invalidation occurred.
