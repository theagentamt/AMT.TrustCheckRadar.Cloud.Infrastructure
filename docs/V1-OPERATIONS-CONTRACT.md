# V1 operational reporting and alert contract

Version: 0.1.0-draft.1, 2026-09-20. Owner: Infrastructure, coordinated with Backend. Tracks [SECUR4ALL-178](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-178); implementation remains [SECUR4ALL-237](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-237) and [SECUR4ALL-243](https://andmorethings.youtrack.cloud/issue/SECUR4ALL-243).

This is a reviewable V1-0 design, not an assertion that the reporting service or wider V1 access authority is deployed. Numeric thresholds, reporting time and retention below are proposed engineering defaults pending owner review. They do not grant cloud access, set customer allowances or decide customer charging.

## Established requirements and current evidence

- Every consumer feature requires an account. Built-in checks remain available when cloud access ends. External work requires authoritative trial, paid or complimentary access; research consent never buys access.
- A logical user check can involve multiple internal attempts/providers but must not cause duplicate deductions on retries. Operational counts, provider costs and customer charging are separate measures.
- Alerts go to **support@andmorethings.com**. The Dev resolver SNS subscription and a direct SNS test were confirmed. This proves that email path, not every alarm transition or a human response SLA.
- The private Dev resolver is deployed on Python 3.14. Current alarms are at least one runtime error or throttle in five minutes, and at least five partial resolutions in five minutes. Missing data is non-breaching; alarm and recovery transitions notify the confirmed topic. These resolver invocation metrics are not user-check counts.
- No submitted message, URL, QR image/payload, account/device identifier, research demographic, token, provider response or model explanation belongs in operational reports or logs.
- User recovery guidance is automated. Operational escalation below means service remediation; it does not offer a human scam-analysis service.

## Sources and ownership

Backend emits versioned, validated lifecycle facts only after authoritative access and idempotency decisions. Android/iOS must not directly increment billable or outcome counters. Infrastructure owns aggregation, bounded storage, alarms, delivery, redaction verification and the runbook. The product owner approves reporting policy; the support mailbox receives notifications.

`SECUR4ALL-190/110` own result semantics; `230/231/232/241` own access/accounting. The report consumer must reject or quarantine unknown schema versions and invalid enum transitions without copying rejected payloads into logs. Validation failures produce a fixed counter. No permissive fallback to legacy FREE balances.

## Minimal event projection (proposed)

The versioned event vocabulary is `check_accepted`, `check_terminal`, `attempt_finished`, `check_reconciled` and `delivery_status`. It is a backend-to-operations contract, not a mobile HTTP endpoint. Lambda owns its executable schema and publisher; the following is the required privacy boundary, not a second wire schema.

Allowlist fields: schema version; server event time; environment; service; input kind (`message`, `url`, `qr_url`); access class (`trial`, `paid`, `complimentary`); lifecycle/outcome/reason enums; finite provider name; attempt index; duration bucket; integer provider request units; nullable estimated cost in integer micro-USD; terminal revision. Reject arbitrary tags, free text and negative/unbounded counters. Do not make request identifiers CloudWatch metric dimensions.

A restricted reconciliation store may additionally hold random server-generated event/check/attempt references and acceptance time. They must not encode subject information, URLs, user-supplied IDs or hashes of content. References exist solely for deduplication and corrections, are excluded from reports/metrics/email, and remain potentially linkable operational data while source mappings exist. They are not anonymous research records. Apply access controls and deletion semantics agreed in the account-data contract; do not duplicate subject mappings in this store.

Proposed retention: event/reconciliation records 30 days from acceptance; diagnostic logs 14 days (matching the resolver); daily aggregate revisions 90 days. TTL is a cleanup mechanism, not proof of exact deletion: expire access at the retention boundary, verify physical deletion and document backup lifecycle before activation. No new tables or retention changes are deployed by this document.

## Counting and reconciliation

- `received`: unique logical checks accepted by the authoritative service in the reporting cohort. Replayed idempotent submissions do not increment it. Raw HTTP requests, validation rejections and technical attempts have separate counters.
- `completed`: terminal assessments with sufficient contracted processing coverage, including inconclusive or unknown verdicts. A verdict of unknown does not by itself mean a technical failure.
- `partial`: terminal assessments with explicitly incomplete coverage. They cannot be relabeled completed merely because a provider returned some data.
- `failed`: terminal service processing failures; `cancelled`: terminal cancellations confirmed by the backend. Closing the app is not evidence that server work stopped.
- `pending`: accepted checks with no authoritative terminal record at the report's `asOf` time. Pending is not silently converted into failed when a client timeout occurs.
- For each cohort: `received = completed + partial + failed + cancelled + pending`. Access-denied, invalid and rate-limited requests rejected before acceptance are outside this denominator and reported separately.
- Report `failed / received` and `(partial + failed) / received` with explicit labels, numerator and denominator. With zero received checks, show `N/A`, not 0% or 100%. Never describe inconclusive verdicts as confirmed threats or all incomplete checks as provider failures.
- Deduplicate identical events and attempt IDs. Out-of-order events are reconciled by valid monotonic lifecycle revisions; arrival time cannot overwrite a newer terminal outcome. Contradictory terminal revisions raise a reconciliation fault. Never multiply logical counts to compensate for lost events.
- Provider attempts and cost belong to their actual event-time period. Label them separately from the accepted-check cohort. Sum only unique attempt records; a missing cost is `unknown`, never zero. Label estimates and coverage; invoices remain authoritative.
- Customer deductions/refunds come from the accounting ledger. Reports observe ledger outcomes but cannot decide partial-result charging, issue credits or restore allowances.

## Daily report semantics (proposed)

Reporting timezone: `America/Chicago`; one daily report at 08:00 local time for the prior local calendar day. Compute half-open local-midnight boundaries using the IANA timezone, then store their UTC instants. Daylight-saving days have 23 or 25 hours and must not be treated as fixed 24-hour periods.

Each report includes environment, local date/timezone, exact UTC range, report revision, generated/as-of times, received and all lifecycle counts, clear failure reasons, rejection/attempt totals, provider-unit estimates and unknown-cost coverage, and a data-completeness indicator. Do not put check-level samples in email. Report Dev and Prod separately; no cross-environment totals.

Pending checks remain attributed to their acceptance day. Late terminal outcomes revise that original cohort within the 30-day reconciliation window. Publish a new immutable report revision referencing the previous revision and delta; never silently edit a delivered report or count the check in today's received total. After expiry, record an uncorrelated late-event counter and disclose the correction limitation. A failed report delivery retries twice with backoff and an idempotent `(environment, date, revision)` delivery key. Exhaustion raises a fixed delivery-failure alarm without recursively trying to alert through the failed reporting job.

Synthetic examples (specification only):

| Received | Completed | Partial | Failed | Cancelled | Pending | Failure rate | Incomplete terminal rate |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 100 | 75 | 5 | 15 | 2 | 3 | 15/100 = 15% | 20/100 = 20% |
| 0 | 0 | 0 | 0 | 0 | 0 | N/A | N/A |

If two of the first cohort's pending checks later complete and one fails, revision 2 has completed 77, failed 16, pending 0; received remains 100. A retry of any existing event changes none of these totals.

## Proposed service-wide alert policy

These thresholds are a starting policy for future implementation, separate from the currently deployed resolver alarms. Derive service faults from allowlisted processing reasons; hostile/invalid inputs and unsafe verdicts are not availability failures.

| Condition | Evaluation | Action/recovery |
| --- | --- | --- |
| Sustained technical failures | At least 20 distinct terminal checks (completed + partial + failed) observed in each five-minute window; technical failures / those terminal checks >=10% in two consecutive windows | Open one incident; recover after two observed healthy windows. |
| Low-volume faults | Three distinct technical failures in 15 minutes, regardless of total traffic | Open one incident; deduplicate with the rate alarm for the same service/cause. |
| Stuck processing | Accepted check has no terminal outcome after 15 minutes, or reconciliation backlog exceeds its documented processing target | Raise aggregate stuck-work alert; show count and oldest age bucket, never IDs. |
| Missing service telemetry | Two consecutive failed, owned synthetic probes at five-minute intervals; or missing expected reporting/heartbeat job | Mark unavailable/unknown, not healthy. Zero customer traffic alone is not an outage. |
| Access/accounting invariant broken | One verified server event for provider use without authority, repeated deduction, or conflicting terminal ledger decision | Critical; stop affected provider dispatch by an explicitly tested control and notify. No automatic refund or destructive repair. |
| Report missing or incomplete | No completed prior-day report by 09:00 local, or reconciliation incomplete | Alert and label stale/incomplete data; do not emit a fabricated zero-volume report. |

Deduplication key: finite environment/service/cause, excluding customer or request IDs. Send on open, material severity change and verified recovery; if unresolved, at most one reminder per hour and six per 24 hours for that incident. Aggregate suppressed notifications in the daily report. Insufficient data is not proof of recovery. Keep an incident's state in bounded operational storage, not unbounded metric dimensions.

Initial escalation target remains the same confirmed support mailbox. After 30 minutes unresolved, add the runbook step and severity to the next allowed notification. Automated retries/fallbacks stay bounded. A human may need to resolve credentials/provider outages; there is no promise of staffed 24/7 response. Design targets: detect sustained faults within ten minutes and produce the daily report by 08:15 local; these are not measured SLAs.

## Implementation and acceptance handoff

Backend (237) supplies authoritative lifecycle publishers, schema validation, event dedup/revision semantics, accounting projections, provider units and bounded backfill. Infrastructure (243) supplies restricted destinations/store, retention, aggregation, scheduled delivery, least-privilege IAM, alarms and actual recipient verification. Mobile supplies privacy-safe diagnostic codes only; local-only actions are not silently uploaded for usage analytics.

Before activation, attach evidence for:

1. Duplicate and out-of-order events, technical retries and contradictory terminal revisions; accounting identities remain true and one logical check stays one.
2. Zero/low/high traffic, partial versus unknown verdict, access rejection, cancellation and missing telemetry; denominators remain explicit.
3. Late correction, replayed correction, failed delivery and repeated scheduler invocations; revisions/delivery are idempotent.
4. Chicago DST boundaries, midnight crossover and delayed terminal outcomes; fixture counts stay in the right cohort.
5. Raw URL/body/token/account-ID injection in every event field and provider exception; rejection emits only fixed counters. Inspect actual logs, destinations and report outputs.
6. Sustained and low-volume alarm opening, suppression, recovery and a failing notification path in Dev. Confirm an actual alarm email to support@andmorethings.com; existing SNS test alone is insufficient.
7. IAM denies mobile/public publishing, cross-environment reads and unauthorized recipients; TTL/backup lifecycle and deletion are verified.
8. Load/cost/cardinality bounds, event loss and reconciliation backfill. Mark partial evidence honestly; simulated tests do not establish live acceptance.

## Remaining owner choices

Review the proposed timezone/schedule, 30/14/90-day retention and alert thresholds/notification limits above. The paid/trial limits, partial/cache charging and URL minimization decisions remain with their own V1-0 contract stories. Their unresolved status must not be replaced by invented operational defaults. Once decisions are recorded, version the accepted contracts and update the linked implementation stories before marking them ready.
