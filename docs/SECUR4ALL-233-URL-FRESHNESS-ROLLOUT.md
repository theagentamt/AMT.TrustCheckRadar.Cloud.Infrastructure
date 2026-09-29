# SEC233 / ATCR152: provider freshness rollout boundary

The URL consumer baseline requires all worker artifacts to originate from the same
release. Replacing that complete set merely to change URL evidence would also move
lease-recovery and deletion workers alongside entitlements. The optional Dev-only
`consumer_artifact_override` instead selects one reviewed consumer package while
preserving that baseline and the separate deletion correction. Null is unchanged.
The separate `entitlements_artifact_override` selects only the related entitlement
reader, with the same exact-baseline validation. All three overrides can coexist.
They introduce no IAM, route, secret, table, environment or activation changes.

The installed entitlement reader at source `39cce61623794a123e61d25f5248b0c081eccf4a`
validates admitted receipts during delayed paid-usage reservation cleanup. Its
closed allowlist rejects the new URL transport field and message version. Deploy
the reviewed compatible `v1_entitlements.zip` before activating any new writer.
Direct lease recovery/deletion use a different projection; exact installed-source
compatibility tests must establish that they can retain their current packages.

## Selection and review

The override binds the baseline commit, SHA256 and S3 object version to the existing
selected worker tuple. The new tuple must name a different source commit, a changed
hash, the matching `url_consumer.zip` or `v1_entitlements.zip`, an immutable object
version and the same artifact bucket.
`provenance_reference` identifies the reviewed evidence file; a string reference
is not proof of compatibility or permission to deploy. The initial selector
changes selected no environment override; the reviewed selections below are
a separate deployment increment.

Before an actual deployment, qualify the producer contract and every changed strict
reader: URL assessment/consumer, message candidates, receipt summary and account
export. Preserve settled usage and original evidence timestamps. Never use the
receipt deadline as Google's match expiry or regenerate validity during replay.
Do not weaken validation to accept new fields silently in old clients.

## Coordinated rollout and rollback

1. Freeze exact Lambda source, versioned contracts, package hashes and automated
   compatibility results; record which packages changed and which did not.
2. Read actual Dev aliases, immutable artifact tuples and admission gates. Source
   defaults are not current-state proof. Preserve unrelated deletion/entitlement
   configuration and existing subject restrictions.
3. Select only reviewed packages. The private assessment uses its existing artifact
   input; the consumer and entitlement reader use their separate narrow overrides.
   Additional reader changes require their own reviewed selections. Keep admissions closed through incompatible
   producer/reader transitions; do not open gates merely to replace code.
4. Review saved plans for the exact intended package/alias changes and any other
   differences. Do not apply unexplained drift or use a broad multi-stack apply.
5. Qualify coordinated parser/expiry behavior in Dev under the existing engineering
   restrictions, then compare runtime hashes/gates and independent-worker pins.
   No deployment success alone proves expiry or billing behavior.
6. Rollback is a coordinated compatible artifact selection, with admission still
   closed where compatibility is uncertain. Restoring the old consumer does not
   make new receipts valid to its old strict readers. Preserve receipt/usage data;
   never discard records, reset allowances or call a provider to repair a replay.

Google's Lookup caching requirements remain a separate open compatibility review;
this change adds no cache or new retention policy. SEC233 retains unfinished
implementation/Dev acceptance; ATCR152 owns native warning behavior. Later combined
release tests belong to open ATCR62 and physical-only cases to ATCR148, with exact
build/contract pins and recorded pending status. No main/UAT/Production promotion,
provider call or runtime activation is performed by this source increment.

## Local validation

Terraform validate passed. The full URL-consumer mocked-provider suite passed
68 cases, including 15 consumer-only and 15 entitlement-reader selection cases,
coexistence of all three overrides, stale-baseline rejection and closed activation
gates.
These tests made no AWS calls and do not establish live deployment or provider
behavior. Those initial selector changes modified no environment tfvars or runtime
package tuple; the subsequent selection is documented below.

The unset-override Dev baseline plan at source `012f728a9f27a51f176d89ee59aa5c5a0864a052`
returned exit 0 with no managed-resource changes. Saved-plan SHA256:
`ef37115d8baa0e407fa58dcbbdc095d94e7ce1935fa46659f6d54a2112a681e8`.
This read-only check did not apply or activate anything.

## Reviewed Dev artifact selection

Lambda source `27ba230f6a96fe5bf1c96719903c3c7016765bbb` is integrated through
PR82 (release merge `7910e199a27d838ac1d2f709cbb8b09c6593ed9a`). It passed
1,091 relevant tests and seven isolated archive checks. Independent review matched
all seven complete archives against a separate frozen-source build, checked their
Python members and AArch64 native libraries, and compared four installed archives.
[Immutable publication evidence](evidence/sec233-freshness-artifact-publication.json)
records S3 object versions and readback hashes. Package publication alone changes
no runtime. Original manifest SHA256:
`7c0847a3dadbb124f583c9ce0fca95d3eeaf4e408b61459178167779f12608da`.

Dev selects the assessment, consumer, entitlement reader and export reader only.
Message and feedback packages are published for later coordinated activation,
without creating or changing those services. The entitlement archive replaces only
`shared_check_authority/purchase_usage.py`; its other 24 members match the installed
39cce baseline exactly. Export campaign-work/locator modules match the installed
a25e archive; compatibility with work source9147 remains unchanged. The export
contract mode flags remain false/pending, so deploying the reader does not enable
new export access or Play-token export.

The API baseline initially proposed removing SEC333's disabled support route
because its reviewed deployment values had been supplied only through a local
override. The three existing support configuration values are now recorded in Dev
tfvars from the prior restoration plan, including null activation. A baseline plan
with those exact preserved values returned exit0/no changes before selecting any
new package. This preserves existing resources; it does not grant new support
admission, alter its code or change its protected route.

Selection is prepared for exact saved-plan review. No apply or new runtime
qualification is claimed here. Review must allow only these four Lambda code
changes and their three live alias updates; preserve all environment values, gates,
permissions and unrelated artifacts. Keep general admission closed. The later
source/fixture/native QA evidence does not substitute for Dev runtime validation,
provider behavior, cache policy or release qualification.

Saved candidate plans contain exactly four Lambda code updates and three aliases,
with no environment, IAM, route, storage or independent-worker changes. Their
[minimized plan review](evidence/sec233-freshness-plan-review.json) contains exact
plan fingerprints. The plans have not yet been applied.
