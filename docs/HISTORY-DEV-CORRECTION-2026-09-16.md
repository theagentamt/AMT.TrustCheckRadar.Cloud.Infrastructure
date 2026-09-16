# Dev History correction and testing handoff

Status: verified source prepared for the existing Dev release workflow. This is
not feature activation or authenticated mobile acceptance.

## Scope

Both History API roles need `dynamodb:GetItem` on the Dev device-bindings table
to read the authoritative active pointer and device row. The new statement is
limited to that table and `USER#*` leading keys. The existing exact GSI1 Query
permission and `USER#*#ACTIVE` condition remain separate. Neither role gains
device-binding writes, Scan, or wildcard table/index access. These role-level
prefix conditions do not replace the handler's token-subject authorization.

The paired Lambda correction is release
`c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca`. Analysis now retains a reference to
its request Update instead of assuming it remains first after authority checks
are prepended. This prevents a KeyError when History is cleared after acceptance.
Clear still preserves recognition progress if its independent generation is
current. A recognition reset prevents the old generation from awarding progress.

The existing History deployment object pins read, mutation and analysis together.
The read/mutation hashes are unchanged; only their release keys/object versions
move. Analysis has the changed package. Other packages retain their existing pins.
Dev only: no UAT/Prod changes, activation, new test accounts, customer-data
mutations, or paid analysis calls are included.

## Evidence

- Terraform API validation and all 55 mocked API tests passed.
- IAM regression tests check exact actions, resources and leading-key conditions
  on both handlers, with no extra binding statements or wildcard resource grants.
- Lambda owner reports 21 focused tests, 326 full tests and 162 subtests passing,
  plus compileall, shellcheck, package checksum and campaign package checks.
- [Lambda CI](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/actions/runs/35150797286)
  and [immutable Dev artifact publication](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/actions/runs/35150836412)
  succeeded at the exact release revision.
- S3 version/hash metadata was independently checked for all three pinned
  artifacts. Exact version IDs and base64 hashes are in `environments/dev/api.tfvars`.
- The initial IAM-only Dev plan had exactly two inline-policy updates and no
  package, flag, route, or data-resource changes. The reviewed combined release
  plan contains exactly five in-place updates: two inline IAM policies and three
  pinned function package references. No Lambda environment changes, additions,
  replacements or deletions are planned.

## Testing Handoff

Implementation/testing issue IDs for this correction are not yet verified.
YouTrack write restrictions remain in effect; this document does not substitute
for a linked testing story or authorize story closure. ITCR-77 is the existing
iOS testing story, not a claimed backend testing story.

1. Run `terraform -chdir=terraform/api test -no-color`, validation, formatting
   and diff checks. Expect all 55 API tests to pass, including both IAM roles.
2. Review the Dev API plan: only two inline policies and three pinned function
   package references may change. Feature flags must remain false. No replacement
   or deletion is expected.
3. After the normal Dev workflow succeeds, read both deployed inline policies
   and verify exact table GetItem and GSI1 Query permissions and conditions.
   IAM simulation with synthetic keys should allow user-key GetItem and active
   index Query, but deny foreign-prefix reads, Scan and binding writes. Simulation
   is not an authenticated endpoint test and reads no customer records.
4. Verify deployed analysis CodeSha256 matches its pin and every changed function
   reports Active/Successful. Confirm feature flags and cleanup schedules remain
   disabled, and unauthenticated History/Progress requests remain rejected.
5. After separate disposable-account and activation approval, test access-token
   subject isolation, missing/stale/revoked binding rejection, bootstrap, list,
   detail, pagination and progress with two synthetic accounts.
6. In the approved mutation test phase, clear History after analysis acceptance.
   Expect no stale content, a content-free replay tombstone and atomic quota
   completion. Preserve current-generation recognition; a concurrent recognition
   reset must prevent old-generation progress. Retrying must not double-charge.

## Mobile Boundary

Authentication uses the Cognito access token and device-binding fingerprint;
callers must not choose another user through query/body fields. Correcting IAM
does not activate reads or mutations: clients must still respect 503/403 and
must not infer empty History or reset progress from an unavailable response.

Read readiness and mutation acceptance are separate. Bootstrap is persistent,
idempotent account initialization, not a mandatory per-session operation. Clear's
current 200 COMPLETE response means a logical generation change with erasure
queued, not proof of physical purge. History clear does not reset badges.
Full-account export/deletion and consumer recovery remain outside this release.

Activation still requires approved test accounts, release-scope confirmation,
cleanup/reconciliation and alert acceptance. No such acceptance is asserted here.
