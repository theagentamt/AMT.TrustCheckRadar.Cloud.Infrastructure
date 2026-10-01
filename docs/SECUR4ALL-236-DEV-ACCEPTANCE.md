# Protected full-account export: Dev acceptance

September 27, 2026. Source story: SECUR4ALL-236. Retained Dev implementation and
acceptance checks passed, including the corrected original deletion and restoration
of temporary access. Final release integration and tracker closure must reference
the commit containing this record; UAT and general activation remain separate.

## Qualified implementation and immutable versions

The exporter delivers the declared account-owned data through authenticated,
bounded pages without a server-side download archive. It requires completed adult
onboarding, a current device binding and sign-in within 300 seconds. Subscription
status and analysis allowance do not gate export. Continuations preserve their
original operation, subject, device and 900-second expiry; observations are as read,
not a frozen snapshot. Deletion prevents further pages.

| Component | Reviewed source and integration |
| --- | --- |
| Export Lambda | `a25e81f3ef919e65d2ec2fb702637b287e9c79d8`; [PR75](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/75), release merge `de9e58509d6759f10af7a35250e0c701fab67f38` |
| Activation infrastructure | `d86e3e79ec7bf36d95df66c4013cea068c9db6c7`; [PR103](https://github.com/theagentamt/AMT.TrustCheckRadar.Cloud.Infrastructure/pull/103), release merge `1f68282dba6d1a64f8fde73bbe1ad648a5a305e2` |
| Android candidate.3 compatibility | `c2f53210f9fa0ae299decaf2db149bb571997ab6`; [PR42](https://github.com/theagentamt/AMT.Android.TrustCheckRadar/pull/42), release merge `ccd148c9af4f7574b7bdaada661a5619d967ad6a` |
| Cleanup correction found during live acceptance | `9effc4f0a38d7d3191b687cb07c9dbda561d69f4`; [PR76](https://github.com/theagentamt/AMT.TrustCheckRadar.Lambdas/pull/76), release merge `a1eafcecaead9cd1fe7bdaecc6a76e5ce6ac1e4a` |
| Immutable contract | `contracts/account-export/1.0.0-candidate.3` at Lambda producer `39cce61623794a123e61d25f5248b0c081eccf4a`, 20 families |
| Existing account-data/work writer | Preserved at `9147d545b719e54c1f967e35042bc502d79bc0f1`; exact reader/writer compatibility selected in Dev Terraform |

The reviewed ZIP is Python 3.14, ARM64, 5,124,010 bytes, SHA-256
`bc418cde6c1574ea14392068fe534c2d826c892f3438bbe633990f9845dfc42f`.
[Publication evidence](evidence/account-export-dev-2026-09-27/artifact-publication.json)
records the private versioned object. Source membership, generated entry point,
Linux native binaries and unchanged pinned dependencies were checked before upload.
No unrelated Lambda artifact was upgraded.

## Acceptance criteria and evidence boundaries

| Retained Dev criterion | Evidence |
| --- | --- |
| Declared inventory, owned records and explicit safe projections | 96 Lambda export SDK/component tests, including all 20 nonempty families, both minimized Play variants, modern work locators and pagination over 25 entries. Injected Cognito/KMS/resource identities and seeded projections are explicitly local fixture evidence. Actual Dev traversal exercised all family readers with three nonempty families. |
| Retry, expiry, concurrent changes and account/device binding | Component tests cover fixed 900-second expiry, refreshed authentication, as-read retries, foreign/manipulated cursors, size bounds, inventory/device/deletion races and final authorization ordering. Real HTTP rejected wrong device with 403 and malformed cursor with 400. |
| Deletion stops an unfinished export without delaying identity removal | Actual START and CONTINUE returned 200 before the original deletion request returned 202. The still-valid token/cursor immediately received 403 ACCOUNT_UNAVAILABLE afterward. Final asynchronous erasure observation is recorded below. |
| Infrastructure and safe activation | 167 Terraform API mock tests, including 19 scoped activation/compatibility cases, plus 67 campaign-processing mock cases including nine bridge compatibility cases; reviewed runtime-only, JWT-route and restoration plans; actual installed role and immutable artifact readbacks. |
| Bounded mobile consumption | Android 2,604 host tests and 12 synthetic emulator cases passed, including both Play variants in the saved document. This is not a live Android-to-Dev download. ATCR-94 retains that work; mobile gates remain false. |

Lambda suite entry points are `tests/account_export_api` (96 cases) and
`scripts/tests/test_scoped_account_export.py` (21 cases, normal and optimized Python).
The latter validates complete wire envelopes and bounded traversal. Infrastructure
uses `terraform -chdir=terraform/api test` with Terraform 1.12.1. Exact commands and
fixture limitations are also recorded in the Lambda repository's
`docs/account-export-dev-qualification.md` at the reviewed source.

## Actual Dev execution

AWS account 107827791950, us-east-1. One newly created disposable identity had
email delivery suppressed; the real profile writer created its pending profile.
The age-attestation and device-registration HTTP producers completed onboarding.
No subscription, engineering grant, trial or allowance was added. Native app
signup/confirmation was not exercised. Existing customers were not sampled.

A private runtime phase admitted only that identity, followed by an independently
reviewed JWT/scope-protected POST `/v1/users/account-export` route, with rate 2 and
burst 4. The existing cursor AWSCURRENT keyring was reused, not initialized or
rotated. Current table identities and purchase, authority and campaign/work
inventory controls were read back; no inventory approval markers were fabricated.

- [Direct runtime](evidence/account-export-dev-2026-09-27/direct-runtime.json):
  21 pages, all 20 families, COMPLETE. This bypasses Gateway JWT enforcement.
- [Authenticated HTTP](evidence/account-export-dev-2026-09-27/http-runtime.json):
  21 pages, all 20 families, COMPLETE through the real JWT-protected route.
- [Unauthenticated HTTP](evidence/account-export-dev-2026-09-27/unauthenticated.json):
  401 without a token.
- [Installed role audit](evidence/account-export-dev-2026-09-27/role-audit.json):
  exactly the expected policies and Lambda trust; no source-write or analysis-provider
  invocation grants. API invoke permission was scoped to the exact account/route.

Profile, identity and devices each contained one real record; the other 17 families
were empty in the live fixture. All-family populated and cross-account scenarios
are component evidence, not claims of live producer coverage. Credentials, cursors,
source content and the assembled download were kept in memory. Retained reports
contain statuses, counts and artifact metadata only. Exporter permissions prohibit
source writes; no separate whole-account before/after content snapshot was retained.

## Deletion and temporary-access restoration

[The immediate fence report](evidence/account-export-dev-2026-09-27/deletion-fence-initial.json) preserves the first bounded observer, not an erasure claim. The original single DELETE_ACCOUNT request was accepted;
no retry is permitted. The first observer's 240-second window ended after eight
valid receipts while scheduled five-minute reconciliation was still progressing.
The immediate export fence passed independently of that timeout. A later observer reached nine valid receipts and revealed a real integration defect: the modern campaign cleanup resource-binding reader calls DescribeTable through CleanupGuard, whose method allowlist did not forward that read. The narrow guarded-forwarding correction has five passing composed SDK/handler regressions: scheduled OPEN work deletion and receipt creation, stream sealed/retired proof, mismatched binding refusal, budget refusal and unsupported method refusal. The installed role already grants DescribeTable only on the pipeline and outbox; no new IAM is needed. The reviewed correction passed all 37 affected Lambda tests and was deployed through the exact saved plan; the original deletion subsequently completed with all 12 valid receipts. The bridge artifact is selected separately with a reviewed exact source compatibility pair; existing work/inventory sources remain unchanged. The separate
[read-only observer](evidence/account-export-dev-2026-09-27/cleanup-complete.json)
verified the same original operation COMPLETE with all 12 valid component receipts,
strongly read profile absence and empty device partition, and actual Cognito
UserNotFound. No DELETE retry, direct worker invocation or receipt injection occurred.
Total elapsed time from acceptance was 1,331 seconds, including investigation and
the correction; this is not a normal-service latency benchmark.

[Installed correction evidence](evidence/account-export-dev-2026-09-27/bridge-deployment.json)
confirms that only the bridge package changed. Its ZIP has the same 37 members as
the earlier package; only `orchestration.py` differs. All environment settings and
other worker packages stayed unchanged. Terraform deferred three scheduler policy
renderings; installed policy JSON was checked equal to the original permissions.
[The exact plan](evidence/account-export-dev-2026-09-27/bridge-plan.json) and
[package comparison](evidence/account-export-dev-2026-09-27/bridge-package-verification.json)
are retained. No inventory marker or deletion receipt was manually changed.

After actual cleanup completed, the three independently reviewed restoration plans
were applied. [Readbacks](evidence/account-export-dev-2026-09-27/restoration.json)
confirm export disabled, zero export subjects, no export route/invoke permission,
the tested exporter package retained, and the exact original account-data/V1/Play
cleanup lists restored (one original subject each). Both cursor and authority
keyring version metadata are unchanged. [Final Terraform checks](evidence/account-export-dev-2026-09-27/no-drift.json)
found no changes across API, URL-consumer, Play-lifecycle and campaign-processing.
No original cleanup scope was discarded or generalized.

## Remaining release work

[SECUR4ALL-331](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-331) is the open
Backend V1-5 release qualification handoff and depends on this development story.
[Detailed instructions](SECUR4ALL-236-RELEASE-TESTS.md) distinguish actual producer
population, UAT configuration/promotion, assembled mobile journeys, fault injection
and alert delivery. No UAT, production or general customer activation occurred.
Physical-only Android cases remain ATCR-148. Infrastructure SECUR4ALL-245 retains
its broader restore/replay and failure-recovery acceptance; this export increment
does not declare that whole story complete. Future iOS parity remains ITCR-41.
