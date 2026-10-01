# Restricted Play test-account readiness

The owner selected an existing Dev app account and confirmed a dedicated Android
profile and Play license tester. Targeted read-only checks found a confirmed,
enabled, email-verified Cognito identity, matching ACTIVE/age-verified profile and
no account-deletion fence. The account has no ACTIVE_BINDING pointer. Its private
subject/username stay outside this repository; do not fabricate a device binding
or reuse another installation's fingerprint.

The authority retained-key marker matches the current retained keyring through
its deployed validator. Historical issuance qualification remains the existing
engineering record; a current-key match is not a new historical audit.

After independent review, refreshed stable fully paginated scans found no modern
owner/locator records and no unknown row families. All four legacy writers have
only `$LATEST`, no aliases, and explicit mutation denies on the exact table for
every execution role. Known modern writer gates remain closed. The previously
absent `PURCHASE#CONTROL / OWNERSHIP_INVENTORY` marker was conditionally created
and read back at 2026-09-23 03:44 UTC (September 22 local). All five pre-existing
projected rows remained unchanged. This qualifies current empty ownership
coverage only; it does not activate paid access or qualify historical paid usage.

Two expired FREE legacy entitlement records remain intact, including one with
prior usage. No legacy usage was reconstructed, migrated, or deleted. No provider
was called and no grant or account/device state was changed. Any restore, state
copy or table repointing requires closed gates and renewed qualification.

New `V1#CHECKPOINT` cursor rows remain absent; first-run expiry/deletion traversal
qualification and the dedicated physical-device test remain pending.

Evidence: [pre-initialization audit](evidence/play-ownership-preinitialization-audit-2026-09-22.json),
[writer fences](evidence/play-ownership-writer-fences-2026-09-22.json), and
[conditional initialization/readback](evidence/play-ownership-initialization-2026-09-22.json).
The first two files describe their pre-write observations; the last records the
subsequent single control-record write.

## Independent stages

1. Build the explicit canonical-package DevDebug registration-only setup; all
   purchase, snapshot, trial, message and URL analysis capabilities remain closed.
   Inspect the owner's selected connected device/profile, sign in normally and
   explicitly register the installation's generated modern fingerprint.
2. Verify exact profile/pointer/DEVICE consistency through bounded backend reads.
   No admin password reset or captured user password is needed.
3. Finish whole-table ownership/key inventory and legacy-writer checks, plus
   explicit expiry/deletion readiness. Only then review a saved access-only plan
   for the exact selected subject. Lease/expiry scans all authority rows, not just
   the allowlist, so selected-account readiness alone is insufficient.
4. The new `activate_access_engineering` source option leaves URL/provider gates
   false and blocks trial activation while enabling snapshots and monitored
   cleanup. Its evidence-reference input is a review record, not an automatic
   proof of readiness. Committed defaults and actual deployed gates stay false.
5. The Play verifier needs separately reviewed activation and cleanup coverage;
   it remains closed. Actual license-test purchase, acknowledgment, retry and
   restore testing follow that qualification. A test-only server rejection cannot
   undo a real charge made in a mistakenly selected real Play payment method.

Current deployed Lambda source is 28b4da19. Later merged lifecycle code is not
part of this qualification deployment. SECUR4ALL-244/195 and ATCR-91/111 remain
In Progress; this preparatory source increment is not end-to-end acceptance.

## Validation of the preparatory infrastructure source

Terraform validate and all 13 mock cases passed, including access-only behavior,
closed URL/trial gates, monitored cleanup, missing evidence/subject rejection and
mutually exclusive activation modes. The read-only Dev plan contains no resource
changes; only the new output fields differ. All committed/deployed activation
gates remain false. The output-only plan was not applied. See
[default-plan evidence](evidence/play-test-readiness-default-plan-2026-09-22.json).
