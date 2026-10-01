# ATCR-95: current retention and disclosure evidence

Assessment date: September 27, 2026. Infrastructure baseline:
`112140d1ee14570ccbb2a6d3698b7f1185a944cc` on `release-V01`.
This is a documentation and read-only evidence increment. It changes no runtime,
retention setting, collection, feature gate, deployment or public policy.
It is not a release-readiness or legal-compliance declaration.

## What changed since the September 21 audit

| Earlier gap | Current evidence | Boundary |
| --- | --- | --- |
| Post-confirmation log group had no expiration | Fresh metadata observes 14 days on all 33 matching Dev Lambda/API Gateway log groups, including post-confirmation. The reviewed adoption was applied September 23. | Configuration evidence; no log content was read and no claim that every possible log destination is inventoried. |
| Recovery control table absent | `device-recovery-control` now exists with `expiresAt` TTL enabled and 7-day PITR. | This establishes storage configuration, not every recovery journey or final store disclosure. |
| Export and deletion still unimplemented/unqualified | SECUR4ALL-200/207/236 and ATCR-94 are Done. The linked acceptance records distinguish automated component checks, actual Dev behavior, scoped temporary access and later qualification. | Ordinary Android gates and general export access remain closed. Deletion retains its previously qualified subject scope; ATCR-95 does not broaden it. |
| Research notice couples participation to extra free scans | Revised source and runtime migration are documented in the research migration record. Legacy incentive claims must not be reused as current product copy. | SECUR4ALL-217/218 remain In Progress; independent access and source migration do not mean new research joins/publication are available. |
| Public policy/deletion content behind current behavior | All three configured public pages returned HTTP 200 on September 27. Each SHA256 is identical to the September 21 Android audit. | Reachability is not alignment. SECUR4ALL-92/94 remain open. |

The old evidence remains historical. Use this assessment alongside the current
Android inventory and Lambda attestation, rather than treating old missing-feature
statements as current blockers.

## Fresh Dev storage metadata

The existing `scripts/audit_account_data_storage.py --environment dev` collector
checked the expected AWS account and region, described the 13 named tables,
their TTL/PITR configuration and matching Lambda/API Gateway log groups. It read
no application records, log events, secrets, queue bodies or backup contents.
The collector hash, source baseline and limitations are included in
[the metadata report](evidence/atcr95-retention-2026-09-27/storage-metadata.json).

| Store group | TTL configuration | PITR window |
| --- | --- | --- |
| Users, analysis abuse control, device bindings, purchase entitlements, Web Risk cache | `expiresAt` enabled | 35 days |
| Deletion ledger | Disabled | 35 days |
| History content/control and device recovery control | `expiresAt` enabled | 7 days |
| Campaign intelligence | `expiresAt` enabled | 35 days |
| Campaign outbox/pipeline and Play encrypted-token store | `expiresAt` enabled | Disabled |

TTL configuration is neither a per-row expiry audit nor evidence of immediate
physical erasure. PITR is a recovery window, not a substitute for a data class's
active retention policy. Disabling PITR does not prove absence of every other
copy. The deletion ledger deliberately retains suppression and audit/control
records; do not promise that every account-linked record disappears at acceptance
or exactly 120 days merely because a policy interval was approved.

The separate September 27
[campaign control-plane inventory](evidence/sec207-period-dev-deployment-2026-09-27/retention-control-plane-before.json)
covers five exact campaign/account-control tables, native backups, AWS Backup,
service export history, queues and operational settings. Within that scope the
backup/export listings were complete and empty, with no replicas/restored tables
observed. Its recorded queue retention is 4 days for cluster work and 14 days for
the dead-letter queue. These are transport/control observations, not a guarantee
that untracked historical copies or other accounts/regions do not exist. The
owner reported no known manual copies/restores during the prior inventory.
No new historical-erasure or native-backup-restore claim is made here.

## Deletion, export and provider boundaries

- [ATCR-94 engineering evidence](ATCR-94-ENGINEERING-CLOSURE.md) records the actual
  Android accepted-deletion request, owned local cleanup, matching-session
  sign-out and the independently observed twelve backend completion receipts.
  The temporary Dev scopes were restored. Acceptance and completed erasure are
  separate states; user-saved export copies and store cancellation are separate.
- [Connected export](ATCR-94-CONNECTED-EXPORT-DEV.md) and
  [SECUR4ALL-236](SECUR4ALL-236-DEV-ACCEPTANCE.md) establish their tested producer,
  continuation, minimization and deletion-fence boundaries. Downloads are observed
  over time rather than a frozen cross-store snapshot; direct export does not
  create an extra server payload copy. Do not imply that export is ordinarily
  enabled or that cancellation separately revokes an issued continuation token.
- [SECUR4ALL-200](SECUR4ALL-200-DEV-ACCEPTANCE.md) and
  [SECUR4ALL-207](SECUR4ALL-207-DEV-ACCEPTANCE.md) provide actual cleanup, suppression,
  lifecycle and expiry evidence with precise scope. Their dated pre-publication
  status paragraphs are historical; current tracker readback is Done. Native
  backup restore remains SECUR4ALL-245; assembled release cases remain separately
  tracked. No missing Dev implementation is recategorized as manual QA here.
- [Research runtime migration](DEV-RESEARCH-RUNTIME-MIGRATION.md) records installed
  replacement source and retirement of legacy paths. Research enrollment,
  publication and the commercial/demographic future choices must be described
  from the selected configuration, not roadmap promises.
- Store expiry, logs, backup windows and provider processing have different
  purposes and deadlines. A minimized seven-day receipt does not establish
  seven-day retention of every associated copy. An OpenAI `store:false` request
  does not attest provider zero retention. US market availability does not attest
  processing exclusively in the US. Provider settings/contracts require their
  own verified evidence under SECUR4ALL-92/94.

## Public disclosure handoff and retained blockers

[The current link report](evidence/atcr95-retention-2026-09-27/public-policy-links.json)
records metadata and hashes of complete HTTP responses without republishing policy text.
The configured pages still use the older SecurityForAll branding and conditional
account descriptions. The privacy/terms pages retain image-upload, generic
retention, broad research-use and scan-credit descriptions that need reconciliation
with the actual selected V1 flows. The deletion page correctly distinguishes
Google Play cancellation, but does not describe the current account requirement
or bounded export/deletion behavior precisely. These are engineering consistency
findings, not proposed new legal terms.

| Existing owner/story | Concrete next acceptance |
| --- | --- |
| SECUR4ALL-92: public policy | Review and publish EN/ES policy and deletion guidance from the current inventories; distinguish required accounts, local image processing, residual identifiers, optional research/commercial consent, provider processing, active versus backup retention, export limits, deletion acceptance and subscription cancellation. Confirm the support/manual-request process rather than inventing an automated web deletion service. |
| SECUR4ALL-94: store mapping | Map actual distributed variants and SDK/provider paths to the forms, with evidence for collection, sharing/exemptions, encryption, purposes, optionality and deletion. An unverified draft or a structural JSON validator is not an approved/submitted form. |
| ATCR-95 | Integrate reviewed Android/Lambda/infrastructure evidence, retain explicit unknowns, and finish final alignment once SECUR4ALL-92/94 satisfy their own acceptance. Keep In Progress meanwhile. |
| ATCR-62: existing V1 QA handoff | After policy/store alignment and release configuration are ready, perform the repeatable manual checks below. This follow-up does not excuse unresolved policy/source work in ATCR-95. |

## Repeatable release/manual checks

Use the actual candidate APK and published release configuration. Record artifact
hash, environment, selected gates, locales and evidence date; use a synthetic
account. Do not enable features merely to execute this document.

1. In English and Spanish, open Settings privacy/terms/deletion links. Record
   resolved URLs, visible language and dated policy versions. Compare them with
   the approved SECUR4ALL-92 text and store listing in SECUR4ALL-94.
2. Compare each advertised capability with the selected gates: unavailable export,
   research or deletion must not promise a working flow. Confirm no extra scans
   for research, preselected consent, anonymity or immediate-total-erasure claim.
3. For approved enabled account controls, reuse ATCR-62's existing export/deletion
   cases and artifact pins. Check acceptance versus completion, saved-copy limits
   and the separate Google Play subscription link. Do not delete an existing
   customer or execute a paid transaction under this audit's authorization.
4. Capture EN/ES large-text, theme and screen-reader evidence under the existing
   QA plan. Emulator checks are not physical-device or spoken-accessibility proof.
   Physical-only work remains ATCR-148. Discard synthetic downloaded copies after
   the run according to the test plan; redact submitted content and credentials
   from evidence.

These cases are pending manual execution, not passes. No UAT/Production promotion,
store submission, public policy publication or physical test occurred in this
increment. Operational alert contacts remain `support@andmorethings.com`.
