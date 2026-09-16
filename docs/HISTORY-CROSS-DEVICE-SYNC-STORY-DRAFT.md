# Versioned History synchronization story draft

Status: proposal only; no issue ID assigned, contract approved, source change or
deployment. Requested for ITCR-38. This is independent of ITCR-78 environment
setup, though live verification still requires approved isolated infrastructure.

## Current V1 Gap

Verified against published Lambda `c0396535d7ebe2f9f60a98b6c62f48ea1981b3ca`,
contractVersion 1.0.0. `historyListResponse` contains items, generations, server
time and an optional nextCursor. It has no tombstones, per-item versions,
collection revision, snapshot fence, change watermark or sync-gap signal.

Delete-one marks an internal locator DELETED and removes content/replay without
advancing historyGeneration. Clear advances History generation; badge reset
advances only recognitionGeneration. Internal dedup/deletion locators are not a
public synchronization contract. Do not expose their full database representation.

List queries use ConsistentRead individually, ordered by content sort key.
Cursors bind subject/generation/last key and expire after 900 seconds; they do
not freeze the collection. Multiple individually consistent queries are not a
cross-page snapshot. Inserts, delete-one and retention expiry can change the
visible collection while a client is paging. Missing a record from one page is
not proof of deletion. V1 cannot fulfill ITCR-38's cross-device tombstone criterion.

## Proposed Backend Story

Title: Versioned History deletion feed and restartable cross-device pagination.

Relate to ITCR-38; existing backend ownership is SECUR4ALL-224 (reads),
SECUR4ALL-225 (completion), SECUR4ALL-226 (mutations), SECUR4ALL-223
(infrastructure), with SECUR4ALL-196 isolation verification. Those references are
not evidence that this new criterion is already implemented or scoped there.
Create/link an actual owner-approved backend story before claiming it tracked;
this draft does not create or modify YouTrack issues or close mobile criteria.

Goal: reconnecting clients can reconcile deletions and converge without stale
responses resurrecting erased items, and can detect when paginated reads must
restart. Keep cost proportional to bounded user-key queries, not table scans.

Proposed contract requirements, exact routes/field names/version still pending:

1. Define a new negotiated/versioned surface. Frozen V1 has
   additionalProperties=false; do not add fields to V1 responses silently.
   Preserve V1 routes, schemas and already accepted request IDs.
2. Introduce an ordered per-user collection revision distinct from History and
   recognition generations. Completion, delete-one and clear must atomically
   update the collection version and their minimum synchronization metadata.
   Accepted sequence/time alone is not a completed-change order. Retries must
   not create another logical change or consume quota again.
3. Expose content-free deletion notices with only the approved request ID,
   ordering/version and necessary operation kind. Clear can be a collection
   invalidation marker rather than thousands of per-record notices. Do not
   include assessment, submitted text, fingerprint or other users' identifiers.
4. Expose an opaque, subject/query/version-bound change continuation and explicit
   retention-floor/gap behavior. Approve numeric sync-metadata retention; the
   existing 120-day dedup policy is a candidate ceiling, not automatic approval
   for a new public event history. Expired/gapped tokens require a clean rebuild,
   not a falsely successful empty change page or endless retry.
5. Choose and document deterministic restart-on-change pagination as the cheaper
   initial option, not immutable historical snapshots. Bind each page to a
   collection fence; check relevant state before/after reads and invalidate on
   concurrent mutations. Explicitly handle logical retention expiry even before
   its cleanup worker runs. A query upper bound alone is insufficient for deletes.
   Define page-limit, byte-limit, tie ordering and cursor-expiry behavior.
6. A complete rebuild replaces the local collection only after all pages and
   the terminal consistency check succeed. Partial/failed pages cannot establish
   deletion by omission. Prevent older in-flight responses/replayed pages from
   overriding a newer deletion/clear revision. Keep recognition reset independent.
7. Enforce verified-token subject and active binding on every page/change token;
   reject cross-account, tampered, expired and wrong-query/version tokens.
   Never accept caller-selected user IDs or rely on an obscure URL.

## Acceptance Tests

- Two clients for one synthetic account: delete-one on A produces a notice or
  explicit invalidation on B and no stale response restores the item.
- Clear invalidates old History cursors/cache while preserving badges; reset
  affects progress without deleting History. Same-operation retries do not
  advance collection/progress/quota twice.
- Insert, delete, clear and logical expiry between page requests either yield a
  valid bounded traversal or an explicit restart; never claim a mixed result is
  a consistent snapshot. Exercise equal timestamps and boundary page sizes.
- Offline beyond sync retention triggers reset and complete atomic replacement;
  network failure midway preserves uncertainty and does not manufacture deletion.
- Cross-subject token/detail/change access and tampered cursors are rejected.
- Completion/metadata transactions fail atomically; lifecycle retries do not
  duplicate notices or emit content. Metadata expiry does not erase active jobs.
- New fields/routes require new contract fixtures; V1 fixtures remain identical.
  Redacted cost evidence shows bounded queries, transaction size and metadata.

## Ownership and Work Ready Locally

Lambda: contract proposal, version negotiation, writer/mutation/lifecycle atomic
metadata, read/change pagination, cursor validation, fixtures and race tests.

Infrastructure: only after storage/API design is agreed, plan any key/index or
TTL changes, exact IAM/query permissions and versioned routes. Prefer existing
tables/keyspace when bounded queries fit; do not promise no new index before
review. No OpenSearch, public stream exposure or polling service is assumed.

Mobile now: continue V1 History UI, account/session-bound requests, local
suppression for known deletes, stale-request fencing, empty/error/loading states
and explicit refresh. Do not infer remote deletion from a partial page. Contract
fakes for future sync must be marked proposed, not parsed as V1. Keep ITCR-38's
backend-dependent criterion open or explicitly blocked; do not silently narrow it.

Local schema, deterministic fake-clock, transactional and cross-user cursor tests
need no new AWS resources. Actual API/IAM/cleanup and cross-device convergence
acceptance remains separate, with ITCR-78 setup and linked mobile/backend tests.
