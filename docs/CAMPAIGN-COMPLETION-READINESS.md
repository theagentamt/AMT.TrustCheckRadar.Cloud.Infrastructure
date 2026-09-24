# SECUR4ALL-207 campaign completion readiness

## Scope and current status

The campaign completion path remains disabled. This work does not approve an
inventory, create a completion receipt, alter retention, or enable live deletion.
SECUR4ALL-207 remains In Progress until its remaining implementation and
qualification requirements are met.

Lambda PR52 integrated the read-only retained-period assessor at source
`7409df873d0a22b1db50fb0469d65d758837a386`, release merge
`834245ebd5e77f17acaaa8f5b1d4d560a694aa55`. Its final focused suite passed 39 cases.
The assessor is not connected to a handler and always reports `complete=false`
and `receiptEligible=false`. It validates bounded retained periods, inventory and
command identity, strong partition traversal and retained key metadata. Unknown,
changed or incomplete evidence blocks coverage. It is not an erasure receipt.

## Infrastructure IAM correction

Candidate campaign policies previously conditioned ConditionCheckItem on
`dynamodb:EnclosingOperation`. The AWS DynamoDB service authorization reference
lists LeadingKeys and ReturnValues for that action, but not EnclosingOperation:
https://docs.aws.amazon.com/service-authorization/latest/reference/list_dynamodb.html
The generic transaction IAM example differs; the existing profile-writer actual
IAM qualification also established this incompatibility.

The candidate correction separates checks from mutation grants. Checks retain
exact table ARNs and partition prefixes, with ReturnValues restricted to NONE
when present. Publisher, cluster and deletion guarded mutations retain their
transaction-only restriction. The lifecycle worker's existing standalone write
behavior is unchanged. Legacy-mode policies are preserved.

Nineteen Terraform tests pass. The reviewed-shape Dev plan contains exactly four
in-place runtime inline-policy updates, with no function, environment, schedule,
stream mapping or storage changes. See [policy plan](evidence/campaign-completion-2026-09-24/iam-plan.json).
This saved evidence is a plan, not an apply or effective-policy acceptance.
Actual [synthetic IAM qualification](evidence/campaign-completion-2026-09-24/synthetic-iam-qualification.json)
passed 202 recorded cases across four temporary assumed roles and five
synthetic tables. Permission checks, forbidden returned values/partitions,
transaction-only mutations and atomic guard cancellation passed; all temporary
resources were removed. The harness has 13 offline tests. This qualifies the
reviewed DynamoDB write/check policy shape, not deployed worker semantics,
streams, queues, KMS or table/index reads. Final deployment readback remains pending.

## Read-only Dev observations

The [runtime audit](evidence/campaign-completion-2026-09-24/runtime-before.json)
records four worker configurations and inline policies, three disabled event
mappings, three disabled schedules and selected table/TTL/backup metadata. It
reads no application items, secrets or log events. A separate
[role audit](evidence/campaign-completion-2026-09-24/role-managed-policies.json)
confirmed that all four roles have no attached managed policies or permissions
boundary. These observations do not qualify historic exports, restored copies,
key history or full erasure coverage, and do not prove direct invocation impossible.

The [schema counts](evidence/campaign-completion-2026-09-24/repair-schema-counts.json)
were captured with bounded, strongly consistent `Select=COUNT` scans. Four
separate traversals each scanned two rows and returned zero matching current
contributions or repair checkpoints, including zero missing-schema matches.
No item values or pagination identifiers are persisted. Separate scans are not
one frozen snapshot. Presence/version checks do not validate actual field values.
These counts do not approve inventory, establish historical absence, or prove
that expired, restored or external copies are erased.

Reproduce only the aggregate audit with:

```sh
python scripts/audit_campaign_repair_counts.py --profile trustcheckradar --output /tmp/campaign-repair-counts.json
```

The executable pins the Dev account, region and table; has bounded pages and
call-start time budget; uses one SDK attempt and bounded network timeouts; and
rejects responses containing Items. An in-flight call may finish after the
call-start deadline. The output explicitly declines inventory/erasure approval.

## Remaining work

- Reconstruct candidate lexical, signal and indicator metadata from retained
  contributions during deletion repair; reject unsupported legacy schemas.
- Qualify complete retained-period/key/legacy and restore coverage with reviewed
  writer inventory. Empty current tables do not satisfy this requirement.
- Establish publication ordering and safe retirement of HMAC keys and tombstones.
- Implement and qualify durable backlog reconciliation beyond stream retention.
- Produce completion receipts only from stable, complete qualified evidence.
- Review immutable artifacts, effective IAM and runtime readback before any
  separately authorized activation. Keep account deletion and campaign gates off.

See [account deletion dependencies](ACCOUNT-DELETION-READINESS-2026-09-24.md) for
identity mapping, other receipt producers and full-account inventory requirements.
