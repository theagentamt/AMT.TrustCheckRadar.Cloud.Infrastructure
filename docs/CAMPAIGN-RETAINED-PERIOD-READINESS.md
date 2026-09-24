# SECUR4ALL-207 retained-period cleanup readiness

## Observed Dev registry

The [bounded metadata audit](evidence/campaign-completion-2026-09-24/period-registry.json)
found two period registry rows in one complete scan on 2026-09-24:

| Period | Registry | Actual KMS state | Correspondence |
| --- | --- | --- | --- |
| 1479 | ENABLED | Enabled | HMAC_256, GENERATE_VERIFY_MAC and all expected tags match |
| 1478 | RETIRED | PendingDeletion | HMAC_256, GENERATE_VERIFY_MAC and all expected tags match |

The audit reads only the documented period projection and KMS metadata. Expected
tag values become match booleans; arbitrary values, key material, MACs and
pagination identifiers are not retained. It creates no keys, markers or records.
Its five tests cover projection, unexpected fields/ARNs, tag privacy, malformed
retirement fields and bounded traversal. The call-start deadline is not a bound
on an already-running network call; SDK retries and network timeouts are bounded.

This is current registry correspondence, not historical destruction, erasure,
restore or complete inventory evidence. A pending-deletion key cannot regenerate
a contribution token. A missing or retired key must remain unverified rather than
be treated as proof of an empty period. No key deletion was canceled or changed.

## Source and permission dependency

The candidate Lambda retained-period sweep replaces the handler's current/previous
period limitation with a bounded inventory-defined range. A cursor on the existing
request-period tombstone selects one period per invocation; advancing first avoids
starvation when one period is busy or unverified. Existing locator checkpoints
resume on the next cycle. The cursor uses the original deadline and does not
introduce a new table or retention period. Completion stays disabled.

The deletion role needs one additional `ConditionCheckItem` grant on the exact
pipeline table and `PERIOD#*` partition prefix. ReturnValues remains NONE; there
is no registry mutation grant. Each cleanup transaction can then reject key
registry replacement or retirement after token derivation.

The [saved plan](evidence/campaign-completion-2026-09-24/retained-period-iam-plan.json)
contains exactly one inline-policy update adding that statement. All other policy
statements and resources are unchanged. Twenty Terraform tests and fourteen
harness tests pass. The [actual selected-role qualification](evidence/campaign-completion-2026-09-24/retained-period-iam-qualification.json)
passed 44 cases for the deletion policy, including allowed period checks and
rejection of old-value disclosure and foreign partitions. All temporary resources
were removed. Other roles were validated against the plan but not re-exercised;
stream/queue/KMS behavior and application semantics remain outside this IAM test.
Deployment is separate; the broader four-policy correction is already applied with
no drift in [the preceding readiness record](CAMPAIGN-COMPLETION-READINESS.md).

Neither current empty contributions nor this cursor closes the full lifecycle
story. Historical/restore inventory, safe publication and retirement ordering,
durable reconciliation after stream expiry, qualified receipt production and
operational acceptance remain pending. Schedules and stream mappings stay off.
