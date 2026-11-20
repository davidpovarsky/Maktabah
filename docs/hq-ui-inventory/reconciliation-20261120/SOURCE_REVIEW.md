# Narrow follow-up seams, not enabled by this crosswalk

Reviewed source: `0e879ae85c4533a7687095cf640f1dc02baf0e60`.

## Hanlin exposure

`MaktabahNativeRoutingComposition.context` issues only `.navigation` and `.discovery`, with empty `contentRights`. `ActionPolicy` requires `.contentRead` and a right for the backend for risk-tier-1 actions. `issueHanlinHostSession` explicitly limits `availableReadActions` to three metadata actions. The adapter's existing `search.query` transport mapping is therefore behind a deliberate authority boundary; it is not merely an omitted advertised string.

A future read-search integration needs a trusted host issuer that establishes actual content rights, allowed work scope, exact backend generation/RPC epoch, current scene/tab/source and SDK session. Then the existing Core advertisement and execution policy can evaluate `search.query`. Neither the model, catalog metadata nor selected text grants that authority. Recheck cancellation, source changes and revocation across awaits. Keep the production exposure closed until those paths have meaningful rejection tests and the actual provider/native gate.

The new `openSearchResults`, `openCommentary` and `prepareNoteDraft` wrappers already connect Core to the original host owners. Their new callers in the frozen source are DEBUG acceptance probes; the original manual UI continues its original path. Adding a Hanlin consumer requires typed SDK host-action metadata, proper UI-risk treatment, original chat dismissal/foreground sequencing, revalidation of the same owner, and only an observed native receipt/session transition as completion. Private query/draft content must not be placed in a public URL. This does not authorize `notes.saveDraft` or persistent mutation. No such exposure is added here.

## Annotation envelope/ledger seam

The original `AnnotationRepository` already uses a shared `SQLiteDatabase` handle and transactional CloudKit pending sync. `SQLiteDatabase.transaction` holds the original recursive lock and uses SAVEPOINT for nested transactions. A downstream, explicitly invoked ledger can therefore use the injected original handle and join a caller-owned transaction without replacing storage or changing the existing Save/Cancel flows.

The original `lastModified` derives from whole-second wall-clock time. It is not a monotonic revision and must not be treated as one. An isolated codec/ledger implementation should compare a defined canonical source snapshot/digest under the same transaction and maintain its own ledger revision. Preserve the existing UUID, exact rich payload and unknown versions, destination/account/Space scope, tombstones and idempotent replay. ACK must bind the exact destination, UUID, revision and payload digest and must never consume CloudKit pending rows.

The first implementation can remain capability OFF and explicitly invoked, with no automatic migration/backfill, live transport or protected Save hook. Binding a long-lived consumer to current database/account lifetime requires a separate production integration contract; the `db` accessor alone does not establish that lifetime. Meaningful temporary-SQLite tests should cover schema constraints, optimistic rejection, rollback after enqueue failure, reopen and crash-style durability, cross-destination ACK refusal, replay/tombstones/account switching and byte-identical CloudKit rows. These are planned component tests in a separate branch, not executions or sync/editor acceptance in this crosswalk.
