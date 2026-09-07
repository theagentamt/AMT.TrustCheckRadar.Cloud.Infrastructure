# Campaign Participation Contract

- Server and infrastructure story: `SECUR4ALL-217`
- Android implementation story: `SECUR4ALL-218`
- Downstream deletion lifecycle story: `SECUR4ALL-207`

This contract defines voluntary campaign participation across the Android app,
the authenticated API, and campaign processing. It applies independently in
`dev`, `uat`, and `prod`.

## Product Promise

- Participation is unset and inactive until a user explicitly joins.
- Free and paid users can choose **Join the program** or **Not now**.
- Scam checks continue when a user declines or leaves.
- A participating free account receives 15 scans per month instead of the base
  10. Leaving returns the account to the base allowance without removing scans
  already used in that month. Paid-tier limits do not change.
- Leaving blocks new campaign use immediately. Active or linkable campaign
  contributions are deleted within 24 hours.
- Anonymous group trends that can no longer be connected to a person may remain.
- Rejoining begins a new consent period and never restores deleted contributions.
- Uninstalling the app is not a withdrawal or account-deletion request.

## Plain-Language Notice

**Help protect others from scams**

When you join, TrustCheck Radar can use privacy-protected details from the
messages you check to recognize scam patterns.

We do not include images, names, contact details, account information, or
anything that identifies you.

You can leave at any time. When you leave, we stop using new submissions
immediately and delete information that can still be connected to your
participation within 24 hours. Anonymous group trends may remain.

Your scam checks still work if you choose not to join.

Free accounts receive 10 scans each month. Join the program to receive 15 scans
each month while you participate.

The actions **Join the program** and **Not now** must have equal visual weight.
There is no preselected toggle. The notice must be localized for English and
Spanish and reviewed for nontechnical readability.

## Prompt Behavior

The Android app checks participation after account creation, after successful
login, and on each cold app launch. When the server returns `not_enrolled`, it
presents the notice at most once in that session. **Not now** closes the notice
without changing server state, so a later login or cold launch may present it
again. The app does not interrupt an active scan and does not show the notice
while withdrawal is pending.

Settings must show the current state and provide join, leave, and deletion
status controls. Account deletion must also be available outside an installed
app through the account website or support process.

## API

Both routes require the environment Cognito JWT authorizer. Account identity is
derived only from the access token `sub` claim.

```text
GET /v1/users/campaign-participation
PUT /v1/users/campaign-participation
```

The exact update request is:

```json
{
  "schemaVersion": 1,
  "action": "join",
  "noticeVersion": "2026-09-07",
  "operationId": "00000000-0000-4000-8000-000000000000"
}
```

`action` is `join` or `withdraw`. Unknown fields, an invalid UUID, or a stale
notice version are rejected. `operationId` makes retries idempotent.

The response exposes only user-facing state: `not_enrolled`, `enrolled`,
`withdrawal_pending`, or `withdrawn`; notice and policy versions; applicable
effective and deletion timestamps; and the base, participating, and effective
monthly scan limits. Internal keys and account identifiers are never returned.

## Records And Audit

The users table holds the current record at:

```text
PK=USER#<Cognito sub>
SK=CAMPAIGN_PARTICIPATION
```

Each accepted transition also writes an append-only receipt under the same user
partition. A receipt records the consent epoch, server time, notice and policy
versions, action, and idempotency key. It contains no submission content,
features, device data, or network data and expires after 400 days.

Joining, its audit receipt, and a free-tier quota adjustment are one DynamoDB
transaction. Withdrawal atomically changes state, writes its receipt, adjusts
the quota, and adds a `campaign.consent.withdrawn` command to the deletion
ledger with a 24-hour deadline.

After cleanup, the deletion bridge marks the ledger command complete, changes
the current participation state from `withdrawal_pending` to `withdrawn`, and
writes a privacy-safe completion receipt. Failed cleanup remains pending and is
retried; it must never be reported as withdrawn before active/linkable data is
removed.

Quota changes calculate scans already used as `max(0, old limit - remaining)`
and then set remaining scans to `max(0, new limit - used)`. Repeated join/leave
requests cannot create scans.

Campaign publication checks the server participation record in the same
transaction that writes the outbox item. A client consent flag expresses intent
but is never authoritative. Outbox provenance includes the consent epoch and
notice version so a withdrawal race cannot admit a new contribution.

## Operational Gates

- Terraform plan and contract tests pass for all environments.
- The immutable release contains `campaign_participation.zip`.
- Lambda tests cover idempotency, concurrent withdrawal, re-enrollment, quota
  anti-abuse behavior, and the 24-hour deletion command.
- Dev smoke tests exercise GET, join, analysis publication, withdrawal, and
  deletion status before promotion to UAT.
- Legal/privacy review must approve the final localized notice and the 400-day
  audit-receipt retention before Production activation.
