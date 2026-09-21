# ATCR-94 account privacy implementation

Status: In Progress. This records the September 21 source work and its remaining
acceptance; it does not declare account export or deletion available.

## Approved behavior and ownership

The owner authorized Android-first work, with Android and Lambda agents owning
those repositories and the orchestrator owning infrastructure and integration.
Current export, purchase-restoration and onboarding decisions are recorded in
[the policy record](ACCOUNT-DATA-POLICY-DECISIONS.md#owner-decisions-2026-09-21--atcr-94).
ATCR-94 depends on SECUR4ALL-200 (deletion), SECUR4ALL-236 (export), and
SECUR4ALL-245 (infrastructure). All four remain In Progress.

The accepted export is a direct authenticated observed-data download, with no
additional server-side payload copy, a fixed fifteen-minute continuation lifetime,
explicit field projections and a scope manifest. It is not a single immutable
cross-store snapshot. Local cancel does not separately revoke an issued token;
deleting the account fences subsequent access. New-account purchase restoration
requires fresh store verification and protection against two active owners.

## Reviewed source foundations

Android PR24 merged into `release-V01` at
`78dfcea5cf64fbd0bf35086abd42523c18e2d634`, from source
`852ab72b120d342e8bdd1454a8310e92c0a72bb8`. Uncertain deletion delivery preserves
local data and describes the uncertainty; cancellation is scoped to the exact
local attempt. The pure deletion contract decoder pins Lambda candidate
`7d6f9dfa99c30b2ba8a24ea59d5d75657dfa5169` and never treats REQUESTED or
completionEligible as whole-account completion. The installed service remains
unavailable until the actual lifecycle is implemented and qualified.

Android reported the complete local gate passing: 455 Gradle tasks, 2,275 host
tests, 20 Pixel 8 API 35 navigation tests, 92.55056% line and 85.29562% branch
coverage. Independent review found no blocking issue. This is emulator/source
validation, not deployed backend, physical-device or complete export acceptance.

Infrastructure updates only the API root's AWS provider constraint and lock to
6.65.0, permitting Python 3.14 for the inactive account-data Lambda. Existing
API Lambda runtimes are not changed by this patch. The former provider 5.100.0
validates runtimes using an SDK enum that stops at Python 3.13. Do not attempt
a 3.14 runtime-only edit with that older provider.

The scheduled invocation permission additionally binds the source AWS account.
Two new five-minute alerts cover reconciliation command failures and failed
scan passes, including errors the worker catches while continuing other accounts.
These use Lambda's exact EMF names and Environment dimension. The optional alarm
set now contains thirteen alarms; missing heartbeat actions remain suppressed
while the schedule is disabled. Select a verified topic delivering to
`support@andmorethings.com` during the eventual reviewed rollout.

## Current Dev inventory

The [configuration-only audit](evidence/account-privacy-dev-storage-audit.json)
observed eleven of the twelve expected table names. The recovery-control table
is absent. Foundation tables and campaign intelligence have 35-day PITR;
History tables have seven-day PITR; campaign outbox/pipeline PITR is disabled.
The deletion ledger's TTL remains disabled. Other observed tables have TTL
enabled; this says nothing about item expiry coverage or physical removal time.
The candidate `trustcheckradar-dev-account-data-api` was independently queried
and does not exist in Dev.

No customer items, log events or secrets were read by this metadata audit.
It does not inventory every historical copy, queue payload, provider record,
Cognito subject mapping or mobile cache. Backup restore must apply current
suppression before serving; active-data cleanup cannot be described as immediate
physical deletion of historical backups.

## Validation and deployment boundary

Terraform 1.12.1 initialization with the pinned signed provider, API validation,
all 60 API mocked tests and all 45 helper tests pass. Repository format checks
pass. Independent review found no issue in the provider/runtime/source-account
patch. The new failure alarms are tied to the subsequent Lambda reconciliation
contract; they require coordinated artifact selection before activation.

Provider 6 introduces per-resource region state; local mock tests are not proof
that a live provider migration is harmless. A reviewed read-only plan against the
current state is required before any apply. The September 21
[read-only Dev plan](evidence/account-privacy-api-provider-plan.json), using the
current artifact release and disabled candidate, proposed zero managed-resource
actions. Refresh reported provider schema additions and existing stage/role state
differences; one output gains the explicit recovery acceptance flag. No saved
state was applied. Regenerate and review the plan when selecting artifacts.
No main merge, workflow dispatch,
AWS apply, public route, consumer activation or destructive cleanup is performed
by this source change.

## Still required for completion

- Qualify the merged export readers and encrypted continuation contract against
  the complete deployed inventory, including legitimate inventories above limits.
  The source candidate uses fresh authentication, completed onboarding and the
  active-device requirement. See [the export handoff](ACCOUNT-EXPORT-CANDIDATE-HANDOFF.md).
- Finish and integrate Android transport, user-selected file save,
  partial-write/cancellation behavior, account isolation and fresh authentication;
  then qualify the complete app/backend flow.
- Atomic purchase ownership/lineage locators, legacy coverage and deletion-safe
  cleanup; no in-place transfer from another active or deletion-pending binding.
- Every required cleanup receipt, final Cognito identity removal, finalizer and
  prevention of resurrection by delayed writers/queues or restored backups.
- Exact IAM/deployment artifacts, retention coverage, isolated live acceptance,
  notification delivery and Android end-to-end/device qualification.

Source publication, release integration, deployment and story completion are
separate milestones. None of the unavailable lifecycle components can be waived
by the passing foundation tests.

## Purchase cleanup and identity-finalization infrastructure follow-on

The nullable `account_data_finalization_candidate` supplies a reviewed manifest
SHA-256, positive integer inventory revision and review reference. It requires
an immutable `account_data_deployment`. Selecting it adds AdminGetUser and
AdminDeleteUser for the exact Cognito pool only; null grants neither operation.
`ACCOUNT_IDENTITY_FINALIZER_ENABLED` remains hard false, as do deletion admission,
stream and schedule activation. No public route is provisioned. Empty pins and
revision zero are safe only while the candidate is disabled.

The account-data role reads the exact `INVENTORY#<environment>` marker and checks
it inside transactions. It can never write that partition. Purchase cleanup
queries only the owned USER partition, reads USER/TOKEN and the exact
PURCHASE#CONTROL marker, and deletes USER/TOKEN rows only in transactions.
Transaction checks cover both inventory markers and the durable account command.
The worker cannot approve its own inventory coverage. IAM LeadingKeys constrains
partition keys; exact sort keys, schemas and subject bindings are runtime duties.

No inventory marker is created by Terraform or this change. Before activation,
prove every current/legacy writer, key lineage, historical copy and replay path,
verify Username/sub mapping, and pin a real reviewed manifest. The account marker
must list all eleven required components and predate each accepted request;
material revisions require a controlled migration or draining pending operations.
A deployment approval reference is not evidence that this coverage exists.

The finalizer's source design checks ten prior cleanup receipts before identity
removal, then records the IDENTITY receipt and completed fixed fence atomically.
The external Cognito call cannot be part of the DynamoDB transaction: if its
acknowledgment or the final transaction is lost, durable reconciliation retries,
using UserNotFound only after the same verified proof set. Freeze inventory
revisions while requests are in flight or explicitly requalify them; do not
rewrite their original timestamps. All downstream workers must understand the
terminal fence before activation. Component receipts describe the approved
120-day informational retention; the completed suppression fence has no automatic
TTL. Neither implies immediate physical erasure of backups.

This source increment does not activate restoration, paid entitlement checks,
store notifications, account cleanup or export. Legacy ownership coverage,
Google Play fresh verification and lineage, delayed-writer fencing, campaign
locator coverage, restore suppression and live disposable-user acceptance still
require proof. New-account purchase restoration remains the owner-approved
behavior after old local ownership is removed under the deletion fence.

Local validation for this follow-on: all 77 API mocked tests passed, API validation,
recursive Terraform format and whitespace checks passed. Independent review
found no blocking issue in IAM, inventory pins or disabled activation defaults.
No AWS apply, marker write, customer-record deletion or identity lookup was
performed for this increment.
