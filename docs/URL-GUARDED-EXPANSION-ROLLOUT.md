# Guarded URL expansion: Dev infrastructure handoff

This is source preparation for the guarded URL candidate, not deployment or live
qualification. The source-only assessment on 2026-10-31 used infrastructure
`cafb83b2f927afc97cc131f498d19a0ec01ab978` and the Lambda worktree
`codex/url-guarded-expansion`, based on
`d2f6a03799b4ee3df6c717f6cd8f8338b1e1abde` with uncommitted changes. Freeze the final
reviewed backend commit and archives before preparing a live plan. No fresh AWS
state, credentials, provider results or deployed versions were inspected here.

## Existing resources fit the candidate

The path remains authenticated HTTP API → URL consumer → private assessment →
isolated resolver. Google lookup stays in assessment; arbitrary HTTP requests
stay in the resolver. Assessment now checks each candidate before requesting one
HTTP response. The resolver never receives the Google credential.

| Component / owning Terraform root | Required package selection | Preserved configuration |
| --- | --- | --- |
| `trustcheckradar-dev-url-resolver` / `terraform/url-resolver` | New immutable `url_redirect_resolver.zip`, published version and `live` alias | Python 3.14 ARM64, 256 MiB, 12 s, existing reserved concurrency (default 5), private subnet/NAT, TCP 80/443 restrictions, no secret/data access |
| `trustcheckradar-dev-url-assessment` / `terraform/url-assessment` | New immutable `url_assessment.zip`, published version and `live` alias | Python 3.14 ARM64, 256 MiB, 35 s, concurrency at most 2, existing Web Risk secret ARN and resolver `live` ARN |
| `trustcheckradar-dev-url-consumer` / `terraform/url-consumer` | New immutable `url_consumer.zip` through `consumer_artifact_override`, version and `live` alias | Python 3.14 ARM64, 256 MiB, 29 s, concurrency 2, JWT routes, identity/device fences, HMAC, allowance/accounting and existing assessment `live` ARN |
| `trustcheckradar-dev-governed-history` / `terraform/governed-history` | Compatible `governed_history.zip`, version and `live` alias | Current reader admission, GSI2/table permissions, retention and current environment |
| `trustcheckradar-dev-account-export-api` / `terraform/api` | Compatible `account_export_api.zip` through `account_export_deployment` | Existing unversioned function wiring and disabled/export admission settings; no new export access |
| `trustcheckradar-dev-v1-entitlements` / `terraform/url-consumer` | Compatible `v1_entitlements.zip` through `entitlements_artifact_override` if the strict pending-receipt reader needs correction | Exact current trial/access cohort, durations, allowance, unrelated worker artifacts and settings |

Source references: [resolver](../terraform/url-resolver/main.tf),
[assessment](../terraform/url-assessment/main.tf),
[consumer](../terraform/url-consumer/main.tf),
[authenticated routes](../terraform/url-consumer/integration.tf),
[History](../terraform/governed-history/main.tf), and
[export](../terraform/api/account-export.tf). These are declarations, not current
live values. Retain actual deployed pins rather than substituting historical tfvars.

No new IAM grant, secret, VPC, subnet, NAT, endpoint, queue, table, index, server,
provisioned concurrency or scheduled worker is justified by this candidate.
Existing assessment permissions already allow the exact resolver alias and one
provider secret; consumer already invokes the exact assessment alias. Resolver
explicit denies on secrets, data stores and role chaining must remain intact.
The new assessment DNS precheck needs no new AWS permission; the isolated worker
still revalidates all answers and pins its socket destination.

Keep the 18 s consumer assessment allowance and 10 s aggregate target/DNS/RPC
budget. The new protocol permits at most five redirects, six target requests and
six Google lookups. Sequential resolver invocations can increase from one to six;
Google's existing six-lookup ceiling does not increase. This adds metered Lambda
requests/coordination overhead, not a reason to raise timeout or concurrency.
Prove the real deadline behavior before changing those limits. The resolver's
existing NAT gateway/public IPv4 has baseline cost; reusing it creates no new
fixed-cost resource. Do not create the optional disposable EC2 fixture or another
NAT for this release. No dollar estimate or fresh billing observation is claimed.

## Compatibility gates before selecting packages

The backend owner must freeze and test these boundaries in the actual archives:

- URL transport `1.0.0-candidate.3` selects assessment contract
  `0.4.0-candidate.1`: private assessment request schema 2/result schema 3, and
  resolver single-response request/result schema 2. Old private schema 1 remains
  available for existing workers. There is no guarded-to-legacy fallback.
- The candidate consumer rejects legacy prepare/submit versions; older receipt
  reconciliation remains explicit. Android must send candidate.3 and request the
  compatible History envelope/header before enabling the new writer. An old
  client encountering a new History item must not silently discard or mislabel it.
- Deploy compatible History, export and strict receipt/accounting readers before
  candidate.3 can write durable receipts. At the source snapshot inspected here,
  `src/shared_check_authority/purchase_usage.py` still accepted only candidate.2
  in its pending paid-receipt validation. This is a backend admission blocker,
  not an IAM problem: require candidate.3 support with strict invalid-version
  rejection and paid-reservation cleanup regressions before rollout.
- Archive tests must cover bundled `shared_url_guarded`, the new consumer mapper
  and schemas, the assessment's vendored resolver/DNS imports, mixed historical
  and new History projections, export and pending-receipt cleanup. Prove installed
  lease-recovery, deletion, maintenance, Message and Play workers remain compatible
  before retaining their current artifacts; do not redeploy every shared-code user.
- Existing Message/legacy private URL paths are not automatically migrated by
  this change. Do not claim all application URL paths use guarded traversal or
  activate AI, legacy routes, export or other services as part of this rollout.

## Ordered rollout under an exact reviewed live plan

1. Freeze backend and Android contracts, immutable ZIP hashes/S3 versions, handler
   imports and compatibility results. Record the exact changed package set.
2. Under separately scoped AWS read/plan authority, verify Dev account
   `107827791950`, `us-east-1`, owning state serial/VersionId/ETag, actual code,
   aliases/revisions, runtime management/ARN, full private environment hashes,
   IAM/network/timeout/concurrency and independent worker pins. Inspect sensitive
   state boundaries before reading it. Use normal refresh and temporary own locks;
   stop on foreign locks, unexplained drift or new access requirements.
3. Preserve current admission through code staging. Any temporary admission pause
   or enablement needs its exact reviewed effect. `activate_engineering` also
   affects entitlement configuration, and governed-trial mode excludes it; do not
   toggle it merely to deploy code or silently change the tester cohort. Preserve
   recovery of existing admitted operations when choosing a quiescence mechanism.
4. Publish and verify compatible durable readers first. Update resolver next,
   verifying both legacy schema 1 and one-response schema 2. Then update assessment,
   verifying both legacy and guarded requests. Only then move the candidate.3
   consumer writer and compatible Android client into the approved cohort. This
   order prevents a new assessor from calling an old resolver and a new writer
   from outrunning strict readers. No weighted mixed-version rollout is assumed.
5. Use the existing artifact selectors for each owning root and inspect full saved
   plans. Permit only the reviewed package/version/alias deltas; retain environment,
   IAM, networking, schedules, non-alarm monitoring and all unrelated resources.
   Do not reintroduce the removed Dev/UAT alarms. A provider-generated published
   version is not known in advance. Bind readback to the actual returned version;
   if direct revision-guarded operations are chosen, review their exact source/state
   accounting first. The Message OCR preservation profile is not a URL deployment
   profile and must not be reused to bypass this review.
6. Verify live code/configuration/alias pins, unchanged protected workers, complete
   state accounting, fresh zero-drift normal plans and released locks. Runtime Auto
   may select a new AWS patch ARN during code publication: stop on an unreviewed
   runtime-pin change and record it, rather than ignoring the field or replaying an
   uncertain update. Then perform the separately authorized bounded Dev acceptance.

## Rollback preserves compatible readers and receipts

Close new guarded admissions using the approved mechanism and retain settled or
in-flight records, allowance and recovery. Keep candidate.3-capable readers and
reconciliation until their retained data can still be handled. Returning all old
packages at once is not backward compatible once new receipts exist.

If no new-format records were admitted and old-client compatibility is proven,
restore the reviewed consumer first, then assessment, then resolver, using exact
prior code/configuration/alias pins. Otherwise retain a compatible consumer's
reconciliation path with new submissions closed; any rollback artifact must
explicitly understand existing candidate.3 records. Reconcile interrupted states
before retrying any mutation. Preserve the old schema-1 path for existing callers
until they have their own migration. Never erase receipts, reset balances, rerun
providers to repair replay, or restore broad admission as a rollback shortcut.

## Required evidence and authority

Local unit/functional and archive regressions are supplementary evidence. They
must prove pre-visit reputation gating at origin and every redirect, no fetch on
threat/provider failure, public-IP and rebinding defenses, no target request for
origin-only input, no raw destination in public results/logs, redirect/latency/RPC
bounds, partial/uncertain contact honesty and one logical settlement. Retain legacy
protocol, mixed-receipt, History cursor/header, export and cleanup compatibility
results, including real Python 3.14 ARM64 archive import checks.

Live acceptance needs an exact approved nonpersonal URL set and existing tester,
current session, provider-secret use limited to the running integration, bounded
Google requests/shared budget, deadlines and no retry of uncertain requests.
Target GET requests can have effects and must be in that approved set. Record
actual provider/target calls separately from user charges and retain evidence of
no target contact after a match. Local mocks cannot prove this ordering in Dev.

This source change authorizes none of those live actions. Package publication,
saved plans/locks, exact deployment/state persistence, any admission changes and
provider-backed acceptance need their concrete scoped approvals and review. No
UAT/production/public activation, secret creation/rotation, IAM/network change or
new paid resource is included. Current blockers are the unfinished backend reader
alignment, immutable release/test evidence and fresh authorized live pins; they
do not justify speculative infrastructure changes.
