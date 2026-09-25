# SECUR4ALL-207 durable campaign cleanup recovery

The recovery candidate preserves unfinished account-owned cleanup after stream
expiry. Source preparation and the Dev index selection do not enable producers,
workers, campaign processing or live account deletion. SECUR4ALL-207 remains In
Progress: atomic completion/sealing and historical/restore qualification are
still required before completion receipts can be emitted.

## Storage and ownership

The existing deletion ledger gains a sparse `CampaignRecoveryDueIndex` using
`campaignRecoveryPartition` and numeric `nextAttemptAtEpoch`, with KEYS_ONLY
projection. Sixteen partitions are `CAMPAIGN_RECOVERY#<environment>#00` through
`#15`. The existing table key, billing mode, backups and stream are preserved.

Lambda creates one `ACCOUNT#<subject> / CAMPAIGN_RECOVERY#<operation UUID>`
sidecar and maintains the same account's `CAMPAIGN_RECOVERY_CONTROL` count in the
command-creation transaction. No global account-key pagination checkpoint,
original content, new subject field, or new retention period is introduced.
Records remain tied to unfinished owned cleanup and existing backup policy.
GSI emptiness does not establish erasure or historical coverage.

Qualified future withdrawal completion must consume its job and decrement the
control atomically. Account CAMPAIGN completion must consume the last job,
transition OPEN1 to SEALED0 and write the qualified receipt atomically. The
finalizer requires SEALED0 before identity deletion and removes it in the terminal
transaction. These completion builders are still unimplemented; no gate in this
increment enables or substitutes for them. Backfill only builds guarded actions;
it has no executor or automatic approval-marker writer.

## Infrastructure preparation

Foundation selects the index in Dev only. API and campaign-processing recovery
preparation remain unselected by normal environment files. When separately
selected against the applied exact foundation contract, they prepare:

- Producer base-table account queries and transactional counter updates, with
  `CAMPAIGN_RECOVERY_WRITES_ENABLED=false` forced after caller environment maps.
- Worker Query on only the exact index and sixteen shard keys, exact inventory
  reads/checks, and transactional account-owned retry updates. No new worker
  completion Put/Delete or Scan grant.
- A disabled five-minute Scheduler target with static, content-free input. Trust
  is restricted by account and schedule-group ARN.
- Eight disabled-action alarms for heartbeat, failures, unverified attempts,
  malformed sidecars, original pending age, overdue commands, exhausted bounds
  and truncated shards. The existing campaign topic has confirmed
  `support@andmorethings.com` email delivery configuration; no test alert was sent.

The selected Lambda asynchronous invocation configuration sets age60/retries0
for all unqualified asynchronous calls to the deletion function, including any
other `$LATEST` asynchronous caller. It does not change stream event-source
retry settings. Review this shared-function impact before selecting preparation.

Preparation outputs describe intended gates, not independent live API/worker
observations. Existing account-data Get/Put/Delete grants allow all ACCOUNT# sort
keys and standalone operations; new transaction-only statements cannot override
another Allow. IAM does not prove the authenticated subject or a particular sort
key. Unrelated purchase-check IAM statements remain outside this correction.
New recovery permissions still require actual AWS synthetic qualification; the
previous 202/44-case campaign IAM reports do not cover this increment.

## Bounds and validation

The candidate worker rotates sixteen shards, reads at most two pages of eight
candidates per shard and attempts at most four cleanups per tick. It checks the
six-second remaining-time floor before each SDK call and before cleanup. Retry
time advances transactionally before work, while the original erasure deadline
is preserved. Strong command/control/inventory reads and transaction predicates
validate eventual index discoveries. A poisoned oldest candidate is skipped;
more than sixteen poisoned candidates in one shard can still require operator
reconciliation. Bound alarms expose that limitation. These are bounded retries,
not a whole-backlog or deadline-SLA qualification.

Local mocked Terraform validation: foundation8, campaign-processing24, API63
cases pass, including cross-account/index rejection and closed-gate assertions.
Campaign guardrails and formatting/diff checks pass. Independent review covers
foundation/campaign setup and API IAM. Lambda has separate SDK/Moto, ordinary
regression and package evidence; none is presented as AWS execution evidence.

[Current aggregate counts](evidence/campaign-recovery-2026-09-24/current-command-counts.json)
returned zero pending account commands, pending withdrawals and recovery metadata
in three independent bounded strong COUNT traversals. These are not one frozen
snapshot or historical/restore inventory approval. No item data or pagination
identifiers were retained.
[The index plan](evidence/campaign-recovery-2026-09-24/index-plan.json) changes only
the existing ledger's attributes and GSI. No worker, producer or policy is selected
by that targeted plan. Full foundation planning is required after application.

## Remaining acceptance

1. Qualify new effective recovery/producer IAM on disposable AWS fixtures, review
   exact package pins and select disabled API/worker preparation separately.
2. Qualify all historical producers, retained keys, legacy/restore copies and
   controlled pending-job enrollment before treating the count as authoritative.
3. Implement stable completion proof and atomic job consumption/sealing/receipts;
   qualify overlapping withdrawals, account deletion, retries and restore races.
4. Review publication ordering, HMAC-key and tombstone retirement, full account
   inventory pins and actual runtime evidence before requesting activation.

No Android or physical-device dependency blocks these backend steps.
