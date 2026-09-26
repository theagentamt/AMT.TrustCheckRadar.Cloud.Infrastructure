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
