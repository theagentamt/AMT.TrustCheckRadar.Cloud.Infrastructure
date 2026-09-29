# SEC233 / ATCR152: provider freshness rollout boundary

The URL consumer baseline requires all worker artifacts to originate from the same
release. Replacing that complete set merely to change URL evidence would also move
entitlement, lease-recovery and deletion workers. The optional Dev-only
`consumer_artifact_override` instead selects one reviewed consumer package while
preserving that baseline and the separate deletion correction. Null is unchanged.
It introduces no IAM, route, secret, table, environment or activation changes.

## Selection and review

The override binds the baseline commit, SHA256 and S3 object version to the existing
consumer tuple. The new tuple must name a different source commit, a changed hash,
`url_consumer.zip`, an immutable object version and the same artifact bucket.
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
   input; the consumer uses the narrow override. Additional reader changes require
   their own reviewed selections. Keep admissions closed through incompatible
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
53 cases, including 15 new consumer-only selection cases, coexistence with the
existing deletion override, stale-baseline rejection and closed activation gates.
These tests made no AWS calls and do not establish live deployment or provider
behavior. No environment tfvars or runtime package tuple changed.
