# Account privacy: terminal-safe History receipts

ATCR-94 and its backend/infrastructure dependencies remain In Progress. Delayed
History work must recognize the completed fixed account fence and must not
recreate expired component receipts or restart cleanup for that account.

The optional `account_deletion_terminal_candidate` input prepares the corrected
History bridge and lifecycle worker. It requires the existing immutable,
same-release bridge/lifecycle artifact pins and both deletion and lifecycle
consumers disabled. The candidate cannot be combined with an active stream or
schedule. Existing Dev inputs leave this option false and preserve deployed
packages, runtimes and permissions.

When selected, both History functions use Python 3.14 ARM64. The bridge receives
GetItem on the exact ledger's ACCOUNT partition family. Its HISTORY receipt Put
permission becomes transaction-only, alongside its existing authoritative-command
ConditionCheck. The lifecycle worker separates its existing ledger GetItem from
transaction-only receipt Put/ConditionCheck. Neither gains ledger UpdateItem
permission. Runtime code must restrict PutItem to the exact HISTORY receipt sort
key and enforce the command schema; IAM LeadingKeys constrains only the partition
and cannot itself prohibit replacing a different sort key with PutItem. All candidates retain
normal disabled runtime flags and existing fixed reconciliation inputs.

The History root uses AWS provider 6.66.0 under the supported 6.x constraint.
A [read-only Dev plan](evidence/account-privacy-history-provider-plan.json) with
current deployment inputs proposed zero managed changes. Refresh/schema drift
is metadata only and was not applied. This is not a candidate deployment plan:
select exact corrected artifacts, regenerate the plan and review it before apply.

The linked source correction must cover both receipt writers: absent/already
removed History in the account-deletion bridge, and deferred completion in the
History lifecycle worker. Both need an exact authoritative fence check and
transactional request guard; a standalone pre-read cannot close a concurrent
finalization race. Exact completed replay must be a no-op. Lost transaction
acknowledgments require safe idempotent handling without resetting retention.

The same infrastructure follow-on adds the campaign cluster's transaction-only
CANDIDATE partition ConditionCheck, required when capped submissions check the
publication freeze. It does not allow inventory mutation or activate any worker.

Local validation: 22 mocked History tests and 13 mocked campaign tests pass;
Terraform validation, recursive format and whitespace checks pass. Live AWS
transaction/stream behavior, source artifact/runtime qualification, complete
retention/replay inventory and end-to-end deletion remain required. No account
was deleted, no inventory marker approved, and no consumer activated by this
source increment.

Independent review found no blocking configuration/IAM issue. It caught a
provider-version reporting mismatch, now corrected to the actual signed lock and
initialization result: 6.66.0 for History and campaign (the API root remains
6.65.0). Both read-only plan evidence records reflect the provider actually used.
