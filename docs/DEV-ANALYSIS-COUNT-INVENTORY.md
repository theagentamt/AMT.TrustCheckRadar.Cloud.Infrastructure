# Dev analysis count inventory

## Approved Scope

The owner approved the read-only Dev inventory after being told it would report
counts and expiry buckets, fetch no submitted text or analysis results, and
never display/log pagination keys. This is not approval for mutation, deployment,
activation, unrestricted field discovery or reads of unrelated inventory families.

`scripts/audit_analysis_record_counts.py` enforces a fixed account
107827791950, Region us-east-1 and only the Dev analysis-abuse-control and
deletion-ledger tables. STS and both table ARNs are checked before any scan.

All scans use Select=COUNT, service-side filters and explicit pagination. A
private worker uses the SDK bundled with the installed Python-based AWS CLI
and its authenticated profile. It receives pagination keys through stdin,
not command arguments or files; logging is disabled and CLI history is bypassed.
No Items are requested or accepted. Unexpected response shapes fail closed.
Only fixed labels, counts, expiry buckets and operational scan metadata can
reach the report. CLI stdout/stderr and exception details are never forwarded.

Coverage:

- REQUEST, RATE, SCAN_RATE and CONSUMPTION family counts.
- Nonempty families: missing/nonnumeric expiry, expired records and remaining
  lifetime buckets through 15 minutes, 24 hours, 7 days, 120 days and beyond.
- Fixed known REQUEST status counts, not arbitrary status discovery.
- The six known ACCOUNT_DELETION component receipt keys: aggregate counts and
  retainUntilEpoch buckets, including missing/nonnumeric values. No receipt
  content, operation identifiers or subject identifiers are returned.

This cannot prove exact schema, original retention, History provenance, subject
ownership, operation binding or complete deletion. Counts are separate eventually
consistent scans, not a shared snapshot. Empty families skip detail scans.
Unknown fields and unknown component keys are not discovered.

Bounds: 25 evaluated items/page, 10 pages/aggregation, 80 scan calls, 300 seconds,
and stop before another page after 64 consumed read-capacity units. A time or
capacity threshold can be exceeded by one bounded in-flight call/page. Calls
are sequential with a delay and SDK retries disabled. Incomplete counts are
labeled partial, never represented as complete. Count-only filters still consume
read capacity: [AWS Scan reference](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Scan.html).

## Execution Status

After the owner renewed SSO, direct STS verification succeeded. The retry
exposed a separate helper bug: the installed CLI's parameter handlers read
file:///dev/stdin more than once, causing invalid JSON before the request.
The helper now uses the installed CLI's bundled SDK with private stdin input.
Its verified max_attempts=1 configuration means one total attempt in that SDK.
No dependency installation, login automation or credential output was needed.

The completed count-only inventory has asOfEpoch `1789507599` (2026-09-15):

| Scope | Count | Complete |
| --- | --- | --- |
| Analysis REQUEST | 0 | Yes |
| Analysis RATE | 0 | Yes |
| Analysis SCAN_RATE | 0 | Yes |
| Analysis CONSUMPTION | 0 | Yes |
| Six known account-deletion component receipt keys | 0 | Yes |

Five scans, 10 consumed read-capacity units, no continuation keys returned.
Each scan reported ScannedCount=0. Detailed expiry/status scans were skipped
because no records were observed. No legacy request rows or known old component
receipts requiring migration were observed in this scope at execution time.
This does not prove future absence, backup absence or readiness for deployment.

To repeat the same approved scope with a valid session:

```sh
python3 scripts/audit_analysis_record_counts.py
```

No AWS changes, row mutations or activation occurred. The full helper suite
passes 27 tests, including 15 count-inventory tests for
scope guards, pagination privacy, response rejection, bounded execution and
redacted errors. These are local synthetic tests, not live inventory evidence.
