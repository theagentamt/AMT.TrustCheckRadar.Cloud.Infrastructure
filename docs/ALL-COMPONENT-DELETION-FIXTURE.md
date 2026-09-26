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
