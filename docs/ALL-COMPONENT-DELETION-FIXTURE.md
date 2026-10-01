# Isolated all-component deletion qualification

The existing campaign completion fixture accepts an explicit `--fixture-kind
all-components` option. Default behavior remains the original three tables.
The option adds exactly nine run-prefixed tables: devices, recovery, abuse,
outbox, entitlements, history-control, history-content, authority and tokens.
The journal binds all twelve names to the same account, region, run ID and tags;
unknown kinds, extra tables and substituted application tables are rejected.
Old three-table cleanup journals remain valid.

Only the ledger has the existing KEYS_ONLY recovery index. No fixture table has
streams, backups or restore inputs. Runtime seed/cleanup IAM references the exact
fixture tables and existing single HMAC test key. It grants no Cognito, provider,
S3, secrets access or general KMS decryption. The optional runner gets 120 seconds
for its bounded SDK composition; default campaign fixtures retain 60 seconds.
All other concurrency, memory, namespace and cleanup checks remain unchanged.

Five provisioner boundary tests pass both normally and with Python optimization.
This qualifies containment, not component semantics or application IAM. The Lambda
runner source and package must be independently reviewed before any cloud fixture
is created. Real producers must create their own receipts; injected Cognito is
reported explicitly and does not count as live identity removal.
## September 26 AWS result

Lambda PR62 source `a612733c162cf2ef6f6ecc740d3ca14683f62c45` was independently
packaged and ran all 52 cases successfully in AWS Python 3.14 ARM64. The four
additional cases composed eleven real upstream receipt producers and the finalizer
with nonempty paginated data, lost acknowledgments, unknown recovery state and
History retry. Identity calls were injected; paid and inventory state was synthetic.
This does not establish native Cognito removal, store verification, historical
coverage or production-role permissions.

All twelve temporary tables, the function and the execution role were subsequently
confirmed absent. The test HMAC key is PendingDeletion for October 3, not destroyed.
See `evidence/live-account-deletion-2026-09-26/all-component-runtime.json` and
`all-component-cleanup.json` for bounded evidence and explicit limitations.

## Separate actual-identity mode

`--fixture-kind all-components --real-cognito` selects a separate, independently
packaged `cognito_qualification.lambda_handler`. One new run and subject are
required for each destructive case. This does not change the default 52-case
injected-identity fixture.

The provisioner creates an admin-only email-username Cognito pool with exact
run tags/name, no hooks, no automatic verification or messaging. It suppresses the
new synthetic user's welcome message, then verifies actual Username equals its
unique sub and the generated example.invalid email. Runtime receives only the
exact pool and subject and four pool-scoped actions: DescribeUserPool, AdminGetUser,
AdminUserGlobalSignOut and AdminDeleteUser. The checked wrapper binds every
identity operation to this subject; it cannot touch an existing app pool/user.

The journal records creation attempts before calls. Cleanup checks exact resource
ownership, removes the designated identity and pool, and confirms pool absence.
An unknown pool-creation result uses bounded complete discovery by exact run name
and tags; ambiguous/incomplete discovery remains an explicit cleanup failure.
No lookup or deletion of existing application accounts occurs. Fourteen boundary
tests pass normally and with Python optimization.

Actual identity deletion in this isolated setup will still not establish application
API authentication, deployed app-role IAM, production inventory coverage, paid
store verification, or general live-deletion activation. Preserve these distinctions
in execution evidence.

The first actual Cognito attempt (source `b964c5f`) rejected configuration before
seeding data because the provider returned a canonical UUIDv7 subject and the
fixture assumed UUIDv4. Its complete disposable pool, function, role and twelve
tables were removed; its test key is pending deletion. Lambda PR65 removes only
that unsupported fixture restriction and retains exact canonical spelling plus
independent pool/Username/sub checks. Production subject parsing was already
version-independent. UUIDv4 requirements for application-generated operation IDs
remain intact. A fresh fixture is required for acceptance; the rejection is not
reported as a successful identity test.

## Actual Cognito acceptance

With reviewed source `2f497f13ff4276aef696a3622f46157776f228af` (Lambda PR65),
two fresh isolated AWS runs passed `identity_complete` and
`identity_delete_lost_ack`. Each composed the real eleven upstream receipt
producers with the shared finalizer and actual Cognito AdminGetUser,
AdminUserGlobalSignOut and AdminDeleteUser. An independent post-run lookup
confirmed UserNotFound for each designated subject. The acknowledgment-loss
case deliberately raises after a successful provider deletion, preserves the
original request, then completes through verified absence without a fabricated
identity receipt.

These are actual identity/provider calls, with synthetic account data, inventories,
paid records and scoped fixture IAM. No client session was issued, so the calls do
not prove rejection of a previously minted JWT. No application account was touched
or public API opened. The two successful fixtures and earlier rejected fixture
were removed: pools, subjects, twelve tables each, roles and functions. Their three
test HMAC keys remain PendingDeletion until the scheduled October 3 deadlines,
not destroyed. See the `cognito-*-runtime.json` and cleanup readback evidence.
