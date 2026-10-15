# SEC233: offline implementation and future scoped Dev qualification

Status: tested feature implementation; not deployed, activated, integrated or Done.
Exact branch publication/readback is recorded in the source-story checkpoint.
Owner approval covers offline fixture/Moto/mock work. The later request to explain
synthetic/mocked data was not retention or live-provider approval. All new gates
remain false and no environment tfvars, account, binding, allowance, subscription
or runtime selection has been changed.

Source: [SECUR4ALL-233](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-233).
Accounting prerequisite: [SECUR4ALL-230](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-230).
Existing open release qualification: [SECUR4ALL-334](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-334),
Backend V1-5 - Release qualification. Existing iOS testing handoff:
[ITCR-98](https://andmorethings.youtrack.cloud/issue/ITCR-98),
iOS Sprint 3A - Manual Dev verification; sources ITCR-92 and ITCR-70.
These records stay open/in progress. No duplicate testing story or invented sprint.
QR live testing remains owner-held; this implementation adds no QR activation.

## Source and component boundaries

Infrastructure feature: `codex/sec233-scoped-url-qualification`, based on published
release-V01 plus a local merge of published main. Lambda uses the same feature
name in its separate repository. Neither feature is authorized to merge into main/release. Publication state and
exact source heads are recorded in the tracker; a local or remote feature commit
is not release integration. Local incorporation of main is not a promotion into main.

Infrastructure changes are opt-in modules, configuration, IAM and offline guards.
Lambda changes are owned by the Lambda agent, including the cleanup handler and
shared qualification store. Its committed companion page has this same document
path in AMT.TrustCheckRadar.Lambdas. No mobile code is modified here.

Public URL transport stays `1.0.0-candidate.2`, assessment `0.3.0-candidate.1`.
Existing prepare/submit/reconcile routes and wire envelopes remain unchanged.
No successful message check is required before a standalone URL check. The
private assessment calls the resolver and Google Lookup only; this work adds no
Evaluate, AI or VirusTotal path. No new public contract was necessary.

`url_qualification=null` preserves each existing function's environment and IAM.
Any explicitly supplied runtime profile, including explicit false or malformed
partial configuration, closes new work rather than falling back to the old
private provider path. Future plans must compare against fresh live source pins;
repository baseline tfvars are not proof of the currently deployed configuration.
In particular, existing v1_entitlements live17/current-source compatibility is
pending SEC230 work and must not be replaced with an older package by this slice.

## Proposed storage policy: decision pending

Synthetic means fabricated public test inputs; mocks simulate provider/AWS
responses. Current tests use both, without real provider requests or customers.
A future real-provider Dev run is separate and requires its own approval.

The isolated proposed table stores only run and target IDs, threat codes, original
provider clocks, public-manifest integrity digest and aggregate counters. It
contains no account/subject IDs, raw URLs, device bindings, check IDs, messages,
payload hashes or original consumer proofs. A random lock owner is a coordination
nonce, not an account credential. The public-manifest digest excludes identity.
The manifest itself contains reviewed public synthetic URLs in trusted runtime
configuration; it must never contain private or actual customer URLs.

Proposed periods remain unapproved:

- Budget rows expire at the run end plus seven days.
- Positive matches preserve Google's exact observedAt/validUntil. A lifetime over
  seven days is not cached; a confirmed threat still appears once, with its lock
  retained through run end to prevent another fetch. No-match has no invented
  validity and is not cached. A cache hit never extends the original validity.
- Match physical expiry is the exact Decimal ceiling of provider expiry; logical
  validity remains the original fractional deadline. Locks expire at run end.
- Expired indexed rows are proposed for deletion within 15 minutes. TTL alone
  does not establish that promise. A five-minute bounded cleanup sweep, stale
  heartbeat closure and alarms support qualification; actual AWS lag remains
  untested. No physical-erasure guarantee is claimed from mocked tests.
- CONTROL/CLEANUP contains only the latest successful sweep clock. The operational
  heartbeat's storage/disposition is part of the pending policy decision too.
- Cleanup diagnostics use fixed codes and a 14-day log group. PITR is false;
  table backups must be excluded from account-wide AWS Backup selections before
  any activation. Tags alone do not prove exclusion.

Source approval is not a retention answer. `URL_RETENTION_APPROVED=false` is
retained everywhere. No store is provisioned by default.

## Trusted profile, limits and rollback

The trusted manifest has exactly these fields (illustrative fixture, never an
approved execution manifest):

```json
{"version":1,"runId":"1800000000_fixture","startEpoch":1800000000,"endEpoch":1800000600,"syntheticOnly":true,"targets":[{"id":"safe","url":"https://example.com/"}]}
```

Run ID includes the immutable ten-digit start epoch plus a 1–32 character suffix.
Window is start-inclusive/end-exclusive, at most one hour. There are 1–16 unique
IDs and exact URLs; IDs contain only letters, digits, underscore or hyphen. No
userinfo, fragments, control/non-ASCII characters or backslashes; existing
canonicalization and public-destination/SSRF restrictions still apply. Each
redirect target must match the manifest before its DNS/HTTP contact, with another
check before connect/GET and the provider request. A manifest entry is not an
SSRF bypass or permission to open the URL in the app. Full UTF-8 key/value size
is limited to 4096 bytes for each complete Lambda environment at Terraform plan.

Independent flags (all false by default):

| Flag | Scope |
| --- | --- |
| URL_QUALIFICATION_ENABLED | Explicit scoped URL mode |
| URL_NEW_ADMISSION_ENABLED | Consumer prepare/new submission |
| URL_PROVIDER_ENABLED | Private assessment/resolver external work |
| URL_RECONCILIATION_ENABLED | Existing original-proof consumer recovery |
| URL_RETENTION_APPROVED | Recorded owner retention decision |
| URL_CLEANUP_ENABLED | Scheduled cleanup execution |

Only the consumer receives the separate URL_SUBJECT_ALLOWLIST_JSON, exactly one
canonical UUID; private workers receive no subject/JWT configuration. New work
still requires actual adult/account/device/access authority. The independent
selection does not create an account, register a binding, activate a trial,
grant allowance, or extend Message/History admission. Preserve appreview and its
existing Android binding; never replace its selection to manufacture a new actor.

Hard bounds are ten NEW admissions and sixty provider-attempt permits per run.
Admission increment joins the same Authority transaction as reservation/receipt
creation, so conflict/replay cannot consume extra NEW slots. Permits increment
before provider work and are never refunded; an uncertain permit response does
not authorize a request. Failed/partial NEW attempts spend a run slot, independently
of customer billing. Only completed checks deduct one allowance unit; partial,
failed and inconclusive results do not. Reopening/reconciling cannot create a new
charge. Known-match partial output is still partial, not a completed check.

Shutdown closes new admission/provider/mode while retaining reconciliation and
AUTHORITY_ENABLED for the original selected account/proof. Recovery needs no
current device, trial, provider window or cleanup heartbeat, but account ownership,
deleted-account fences and receipt retention still apply. Never release locks,
reset counters, rewrite allowance or delete authority receipts as a retry method.
Keep authorized cleanup running for already stored synthetic data; removing its
retention approval also stops cleanup and requires explicit disposition handling.

## Resources and least privilege

`terraform/url-qualification` creates zero managed resources by default. Future
selection can create an encrypted on-demand Dev table (PK/SK, expiry-only GSI1,
TTL, deletion protection, prevent_destroy, PITR off). A separately pinned cleanup
artifact can add a Python 3.14 ARM64 function, alias, logs, restricted execution
role, scheduler role/group/schedule and Errors/Throttles/missing-Invocations
alarms to the existing support alert topic. Schedule and alarm actions remain
disabled. No routes, identity/billing resources, provider secrets or new topic.

Cleanup queries only the expiry GSI, at most four pages of fifty rows, conditionally
deletes observed expired run rows and updates CONTROL only after a certain full
sweep. It cannot scan, read customer tables, invoke providers or access secrets.
Incomplete sweeps raise a fixed error, making the existing Errors alarm effective.
Missing/stale/future heartbeat closes new admission/provider work; startup needs
one successful authorized sweep. A bounded batch is not a 15-minute guarantee.

Consumer gains only control GetItem and transaction-enclosed run UpdateItem.
Assessment gains exact-table control/run item operations and explicit denies for
other tables, scans, backups and bulk writes. Resolver gains only control GetItem
and retains its secret/identity/write denies. Existing VPC/DNS/HTTPS/HTTP limits
remain. DynamoDB LeadingKeys restricts partitions, not sort keys: runtime validates
BUDGET/MATCH/LOCK/CONTROL sort keys and transaction ownership/expiry conditions.
Do not represent IAM alone as sort-key authorization or conditional deletion.

## Offline reproduction and evidence

Use Terraform 1.12.1 and Python 3.14. Initialize providers with backend disabled;
all Terraform test providers are mocked. These commands do not authorize a real
plan/apply, workflow dispatch, endpoint call or provider request:

```sh
terraform -chdir=terraform/url-qualification init -backend=false -input=false
terraform -chdir=terraform/url-qualification validate
terraform -chdir=terraform/url-qualification test
terraform -chdir=terraform/url-consumer test
terraform -chdir=terraform/url-assessment test
terraform -chdir=terraform/url-resolver test
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
terraform fmt -check -recursive
git diff --check
```

Initialize the other three roots with the same backend-disabled init when needed.
On this host the provider plugin required an unrestricted local process to start;
the successful runs still used mocked providers and no AWS service credentials.
New store tests are plan-only because prevent_destroy must not be weakened for
mock teardown. Existing unrelated test files may use mock apply; none are AWS applies.

Final infrastructure suites: consumer 87, assessment 8, resolver 17, store 9
(**121 mocked cases passed**). The helper suite passed **462 cases**; Lambda final impacted checks passed
**715 cases**, including 44 scoped cases, against source
`a83d5b208949c17c709759bcae561b6254bb0f4b`. Its final docs/source branch head is
`ed83d9c28c9f95a9319cbe74ab8f51f0a10bef1d`. The new
helper's twelve cases include bad plans, broadened IAM, unknown/private values,
wrong-account roles, changed protected selections, alias/package mismatches,
manifest manipulation, shutdown recovery and diagnostic redaction.

`verify_url_qualification_plan.py` is an offline review guard for closed installation
and recovery-only rollback. It checks full managed inventory, retained runtime
fields/selections, exact independently reviewed before/after artifacts and IAM,
Dev identity and immutable packages; prints only fixed scope/count and a digest.
The expected-policy file is a trusted review input and must not be copied blindly
from a plan. Existing allows/denies cannot broaden, except the exact replacement
of broad DDB denies with the isolated-store permissions. Pass is not approval.
No workflow calls it automatically yet; this helper cannot approve activation.
Future active-plan/workflow integration is retained implementation work, not
waived acceptance or a testing follow-up that makes unfinished code Done.

For private future plan files, the verified guard entry point is:

```sh
python3 scripts/verify_url_qualification_plan.py /private/path/plan.json --expected /private/path/reviewed-pins-policy.json --root consumer --phase install-closed --revision EXACT_40_HEX_INFRA_REVISION
```

Replace placeholders after review, keep files private and never publish raw plan
JSON, identities, tokens, proofs or exact private selections. Other roots are
assessment/resolver; rollback-recovery is consumer-only. This command has only
been exercised with offline fixtures, not an actual AWS plan.

## Existing test handoff: future execution stays pending

Execution owner: backend/infrastructure team for service/IAM/provider qualification;
mobile QA for simulator/emulator journey and later human review. Source scope does
not depend on physical hardware. Reuse SEC334 and ITCR98; don't create duplicates.

Before a live Dev run, obtain the retention decision, approve the exact synthetic
manifest/window, prepare a separately approved disposable adult account/binding and
eligible access under SEC230, independently review published immutable artifacts,
complete the active-plan/workflow guard and protected current-state inventory, and
approve exact CI/CD plans. Confirm backup exclusion, cleanup startup/lag/alarms,
provider caps and rollback digest. No existing actor/trial/device/History widening.
No UAT/Production change. A missing owned redirect fixture stays pending; never
substitute an arbitrary public shortlink. No live execution runner is provided by
this offline infrastructure slice; reviewed automated runner integration is still
required before live acceptance.

Expected later cases and evidence, all unperformed here:

1. Scoped synthetic standalone submission to the current version, complete
   explanation, one reservation/settlement, original accounting receipt. Record
   exact source, pins, plan digests, versions and redacted correlation references.
2. Duplicate/concurrent submissions and lost responses recover the original
   result with its original proof; no second provider work or charge. Partial,
   technical failure, stale evidence and denied targets remain honest/unbilled.
3. Match repeated within validity uses original clocks; expiry never slides.
   No-match does not claim freshness. Run caps reject the eleventh NEW admission
   and sixty-first provider permit; wrong actor/device and unapproved redirect
   are denied before unauthorized egress. Record only aggregate counts/timing.
4. Stop admission/provider/mode; recover outstanding proofs with authority and
   reconciliation retained. Verify unrelated Message/History/access/identity,
   deletion/export/badge/billing selections and artifacts are unchanged.
5. Allow approved cleanup to finish and independently verify physical lag,
   heartbeat and Errors alarms. Verify SNS delivery separately from receipt at
   support@andmorethings.com. Do not reset counters or erase locks to make a retry.
6. Mobile: explicit synthetic URL confirmation, typed completion, app restart and
   proof recovery. Governed History ingestion/list/detail/freshness for this new
   actor is a separately gated dependency: do not claim it works from these tests
   or widen existing History/Message gates. Screenshots/private messages must
   never enter History. Physical-only work stays in existing follow-ups.

Evidence must label mocks, real Dev, provider sandbox, simulator/emulator, human
review and later release testing distinctly. A deployment is not behavioral proof.
SEC233/230/334 and ITCR92/70/98 remain in their existing states until their retained
acceptance and publication/integration requirements are actually satisfied.
