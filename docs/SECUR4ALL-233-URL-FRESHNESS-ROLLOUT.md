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
is not proof of compatibility or permission to deploy. No environment selects an
override in this source change.

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
behavior. No environment tfvars or runtime package tuple changed.

The unset-override Dev baseline plan at source `012f728a9f27a51f176d89ee59aa5c5a0864a052`
returned exit 0 with no managed-resource changes. Saved-plan SHA256:
`ef37115d8baa0e407fa58dcbbdc095d94e7ce1935fa46659f6d54a2112a681e8`.
This read-only check did not apply or activate anything.
