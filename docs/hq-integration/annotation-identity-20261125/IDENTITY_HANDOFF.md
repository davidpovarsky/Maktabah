# Explicit legacy annotation exchange identity

Base: 04b59e07d05b4073d9f879453a7f421bf03a1864. Branch: codex/otzaria-annotation-identity-20261125.

The original AnnotationRepository backfill produces legacy_<book>_<content>_<start>_<created> CloudKit names. They are not UUIDs. The downstream native editor previously required a UUID-valued ckRecordId, preventing those real saved notes from opening.

AnnotationExchangeIdentity resolves existing UUIDs unchanged or a previously registered legacy alias. registerLegacy is the only identity writer: it uses the original SQLite transaction and writes one strictly validated owned table. It never rewrites annotations, ckRecordId, timestamps, tags, CloudKit queues, rich versions or outbox deliveries. Read, inspection and cancellation never install its schema or aliases.

The stable alias uses SHA-256 of UTF8("otzaria.annotation.backfill.v1\\0cloudkit-record-id\\0") followed by the exact original CloudKit name, takes the first 128 bits and sets UUID version 8 and RFC variant bits. The four canonical Int64 fields accept the exact original interpolation format. It never hashes a local row ID, account or profile. Duplicate originals, alias/direct UUID collisions, malformed identifiers, altered owned DDL, extra triggers/indexes and temporary shadows fail closed. Profile/session authority remains with the original captured repository connection and one-way lifetime.

The ledger resolves the original name read-only before witnessing all original row/tag bytes. Session, persistence, source observation and normal editor inspection use the same identity helper. Original saved CloudKit names remain the actual save/upload keys, including legacy names. Plain writes to mapped rich notes use the existing opaque-body guard.

Root owns explicit backfill Planner/View, batch transaction and project registration. New helper requiring all relevant app target memberships: Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeIdentity.swift. No upstream repository write paths, native SDK, shared Core or original UI layout were changed here.

The two original component drivers include the new helper; their original 43+2 and 28 assertions remain unchanged. Apple compilation and actual legacy identity tests are pending at this source checkpoint. This note does not grant runtime, native UI, cloud transport or TestFlight acceptance.
