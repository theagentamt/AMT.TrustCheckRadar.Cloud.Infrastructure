# Restricted Play test-account readiness

The owner selected an existing Dev app account and confirmed a dedicated Android
profile and Play license tester. Targeted read-only checks found a confirmed,
enabled, email-verified Cognito identity, matching ACTIVE/age-verified profile and
no account-deletion fence. The account has no ACTIVE_BINDING pointer. Its private
subject/username stay outside this repository; do not fabricate a device binding
or reuse another installation's fingerprint.

The authority retained-key marker exists and reports VERIFIED_COMPLETE with one
retained key. That observation is not a new audit of historical issuance or a
secret-value comparison. PURCHASE#CONTROL/OWNERSHIP_INVENTORY is absent; no purchase
can be admitted until independent coverage evidence justifies initialization.
New V1#CHECKPOINT cursor rows are absent after the recent disabled deployment;
first-run traversal qualification remains pending. No marker was written here.

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
