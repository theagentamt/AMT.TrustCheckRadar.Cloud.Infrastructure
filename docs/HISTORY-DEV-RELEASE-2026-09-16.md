# Dev History and Badges release

Status: deployment preparation, not mobile acceptance.

The owner authorized Lambda deployment and main publication on September 15
(America/Chicago). This release targets account 107827791950, us-east-1, Dev only.
UAT and Prod remain unchanged. Full-account export/deletion remains disabled.

## Immutable artifacts

Lambda main is `8d25e19b691d82caf630edc7ebd84c0b45de0c5c`.
CI run 35043326119 and artifact publication run 35043356126 succeeded.
S3 object versions and SHA-256 metadata were read from the Dev artifact bucket
and matched to the reviewed History, device and publisher artifacts. Exact
versions and base64 hashes are pinned in the Dev Terraform inputs.

Only selected functions use this release. The existing global release remains
unchanged for other functions. CI-built dependency archives can differ from
local builds; do not substitute local dependency-package hashes for S3 hashes.

## Deployment order

1. Apply the SNS policy admitting same-account Dev History alarms.
2. Deploy the locator-aware campaign publisher before the analysis producer.
3. Stage the lifecycle/History deletion bridge with their schedules disabled.
4. Deploy compatible device registration/recovery, analysis and History APIs.
5. Seed the cursor signing secret outside Terraform state and without logging it.
6. Obtain release-scope and disposable-test-account approval; verify authenticated
   isolation, replay, badge qualification, cleanup and alert delivery before
   enabling mobile use. These approvals and results are not implied by a deploy.

History feature flags, cleanup schedules and consumer device recovery remain
disabled in the staging configuration. The support-only recovery endpoint uses
AWS_IAM; it is not a consumer recovery API.

## Preflight evidence

The CLI identity is an AdministratorAccess SSO session in the expected account.
A bounded COUNT-only read of each History table and the campaign outbox returned
zero items and no continuation key. These eventually consistent observations
are not frozen inventory, physical-erasure proof or legacy locator acceptance.
The existing SNS topic has a confirmed support@andmorethings.com subscription.
Delivery and recovery tests remain outstanding.

Validation: all eleven Terraform roots validated, with 118 mocked Terraform
tests passing; all 27 helper tests and campaign guardrails passed. Formatting
and diff checks passed. The reviewed API plan adds 31 resources, updates four
and replaces only the legacy recovery invocation permission. No table or
customer-data deletion is planned. Planned Lambda environment maps fit the
4 KB limit; all History flags are false.

The Dev SNS source policy was applied. Bootstrap prerequisite plans are limited
to the Dev History lifecycle/reconciliation and monitoring deployment policies:
one addition and one update, no UAT/Prod changes. A targeted bootstrap plan is
intentional because unrelated shared bootstrap changes are not part of this
release; do not apply that stack broadly.

## Proposed cleanup sizing

The Lambda owner recommends 100 items and 64 bucket queries per sweep, erasure
batches of 25, a 168-hour expiration reconciliation window, 300-second stuck
completion detection and 60-second rechecks. The schedule remains five minutes,
with 256 MB and concurrency one. These are operational sizing proposals, not
changes to the approved 90/120/7-day retention periods.

For independently verified empty tables, bootstrap one UTC hour before actual
activation. Never reuse that bootstrap for a restore or non-empty store. Let
the first successful sweep conditionally initialize its four checkpoints;
do not seed arbitrary checkpoints or enable writes before sweep acceptance.
The runtime-policy input remains null pending the live activation sequence.

The Lambda smoke harness is available on its feature branch at `69e8b6b`.
Its plan-only mode makes no network calls. Execution and synthetic accounts
remain unapproved; no authenticated acceptance result is claimed here.

## Remaining acceptance

History/Badges and full-account data management are distinct release scopes.
The latter still lacks complete entitlement cleanup, identity finalization and
full-account export. It must not be advertised as implemented. See
ACCOUNT-DATA-RECOVERY-HANDOFF.md and HISTORY-OPERATIONS.md for the remaining gates.
