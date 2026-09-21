# Independent research consent migration

Tracks SECUR4ALL-217, SECUR4ALL-218 and SECUR4ALL-241; follows the ATCR-95
retention inventory. This change supplies an optional infrastructure candidate.
It does not deploy a migration, enable mobile consent, approve an inventory, or
establish production cleanup/restore coverage. Phone-number and VoIP work is
outside this change.

## Contract and access

The Lambda contract is `contracts/campaign/research-consent-v2`, schema 2,
notice `research-consent-2026-09-21-v2`, policy `independent-research-v1`.
GET/PUT `/v1/users/campaign-participation` keep JWT authentication. Research is
independent of paid subscriptions, trials, complimentary grants and allowance.
Demographic and commercial consent remain separate choices.

Legacy enrollment requires explicit review; it is not silently upgraded.
Old operation evidence and today's participation are separate. An owned exact
operation lookup can reconcile a dispatched request; absence is not proof that
it never executed. Old owner-less mobile operations cannot be replayed under a
new account. Withdrawal does not require joining under a new notice. The default
`CONSENT_INDEPENDENCE_ENABLED=false` blocks new joins; reads, exact-operation
reconciliation and withdrawal remain available.

The participation role cannot access entitlement tables. The retired analysis
candidate can only replay or report the need for reconciliation; IAM denies
writes, provider secrets, SSM parameter reads and Lambda dispatch. The snapshot
candidate must not synthesize FREE access from a missing or malformed record.
The direct legacy Web Risk candidate has no provider or DynamoDB access. Purchase handoff carries the revised entitlement helper so verification cannot
restore a research bonus; its account/deletion and transaction-only ownership
fences remain required. These
are mandatory behavior changes in the pinned packages, not environment toggles
that can revive an old allowance path.

Preserving entitlement and usage records does **not** establish uninterrupted
paid service. Modern V1 authority/consumers and their mobile routes must be
qualified before legacy cutover; otherwise the rollout must explicitly account
for temporary service unavailability. This candidate alone does not enable them.

## Coordinated infrastructure inputs

1. `campaign-processing`: keep `kill_switch_enabled=true`, select the four
   immutable `account_privacy_artifacts` workers (publisher, cluster, deletion,
   lifecycle), and set `research_consent_migration=true` only for the reviewed
   migration packages. All event sources and lifecycle schedules stay disabled.
   Publisher and cluster must enforce the current notice/policy. Cluster reads
   the original 72-hour outbox event, current consent and deletion fence and
   checks all three in contribution transactions. Missing/expired source
   evidence or an old feature cannot authorize a new contribution.
2. `api`: select `research_consent_migration_deployment` with the same release ID
   and exact S3 object version/base64 SHA-256 for `analysis`, `participation`,
   `snapshot`, `web_risk`, and `purchase`. A review reference is required. Existing routes
   remain authenticated. UAT/Production require their separate promotion gate.
3. API cutover reads the applied campaign state and rejects a different release,
   account or environment, an unselected migration, or unpaused consumers.
   Applied state is composition evidence; check actual Lambda versions, aliases,
   API integrations and consumer state independently before using it as rollout
   evidence. Terraform cannot prove application behavior or prevent subsequent
   out-of-band drift.
4. New consent joins need a separate `consent_enabled=true` selection and a
   `consent_approval_reference`. Android retains its own default-false adapter
   gate. Neither setting grants migration inventory approval. With all campaign
   consumers paused, accepted withdrawals can stop future eligible publication
   but cannot establish completed cleanup.

Null inputs preserve existing deployment configuration. Selecting a candidate
rejects conflicting participation/purchase overrides and active legacy History writes,
recognition or durable replay. An already active History deployment needs a
reviewed retention-aware cutover; do not disable its controls merely to make a
plan pass. Existing source-preservation defaults are not a supported rollback
once cutover has occurred.

## Inventory and migration sequence

Before live cutover, inventory exact aliases/integrations, legacy and V1
entitlement families, purchase/renewal writers, consent versions, requests,
consumption receipts, queued research features and cleanup paths. Use a distinct
read-only inventory role and a scoped operator role for any reviewed application;
runtime roles cannot approve inventory or grant themselves migration authority.
Do not put original messages, URLs, tokens, account IDs or item dumps in a
published report. Keep protected input separate from minimized counts/digests.

Run the Lambda planner in its default dry-run mode against a reviewed inventory.
Classify unknown shapes and stop on conflicts. Preserve paid purchase binding,
trial and complimentary grants, usage, original period/deadline, request ID and
payload hash. Never reset usage or turn the old research bonus into credits or
recurring free access. Preserve ambiguous PROCESSING/RESULT_READY requests for
reconciliation; an expired lease or absent receipt does not prove no dispatch or
no charge. Completed requests may replay only with matching identity and durable
evidence; never redispatch or charge in a new period to recover an old request.

Any operator application needs per-row snapshot/version conditions, account
and deletion guards, an explicit reviewed manifest and resumable evidence. It
must not rewrite historical notice/epoch evidence, extend TTLs, create a grant,
or mark all data erased. A deletion started during inventory takes precedence.
A control marker is not proof that every legacy writer is fenced or every
contribution has been removed.

Qualify source artifacts, locally review plans and IAM, pause the campaign
pipeline, verify actual pause, and deploy the coordinated reviewed candidates.
Then verify old-client join rejection, withdrawal and exact reconciliation,
paid/trial/complimentary independence, no new legacy dispatch, retry/no-double
charge, session switching and deletion races. Keep joins and mobile adapter
closed until inventory, notice, provider policy and cleanup/restore acceptance
are satisfied. Never resume an old publisher to clear a queue. Roll back only to
a reviewed version that retains the new access and publication fences; reverting
to legacy grants, bonus writes or notice interpretation is unsafe.

## Validation evidence

Mocked Terraform tests cover immutable package selection, unchanged null
configuration, closed new-join defaults, entitlement isolation, transaction-only
consent writes, legacy write/provider denies, separate activation/promotion
requirements, History conflicts, same-release paused worker composition, and
cluster consent/deletion/outbox transaction permissions. These tests use synthetic
resources and do not constitute an AWS deployment, customer-data dry run,
physical-device result or cleanup/restore proof.

No environment tfvars, remote state, runtime flags, customer items, Secrets
Manager values or live resources are changed by this source increment.
