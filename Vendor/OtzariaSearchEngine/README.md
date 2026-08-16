# OtzariaSearchEngine native iOS adapter

This folder builds the canonical, pinned Otzaria Rust/Tantivy engine for native Swift/iOS.
SQLite/seforim.db is only the indexing source; searches run against Tantivy.

The C layer is a panic-safe JSON adapter. Query construction, normalization,
highlighting, grouping, fingerprints, compatibility and semantic fusion remain
in the upstream crate.

## Build on macOS

```bash
Vendor/OtzariaSearchEngine/build_xcframework.sh
```

The script builds arm64 device, arm64 simulator and x86_64 simulator slices
with the production semantic feature. The app target supplies libc++,
Accelerate, Metal, MetalKit and Foundation at the final Apple link.

## Updating upstream

```bash
python3 Vendor/OtzariaSearchEngine/Scripts/sync-otzaria-search-upstream.py --latest
```

That command resolves `origin/refactor`, updates the exact pin and manifests,
syncs hashed dictionaries, prepares a pristine checkout, and validates the
locked bridge. It extracts `DEFAULT_GENERATION_ORDER` from the pinned source;
CI fails on manifest/source drift. Production builds read the pin and this
validated default through Rust build information (currently `5`).

## Index lifecycle

Maktabah keeps `final`, `building`, and `previous` directories. A coordinator
invokes one bounded batch at a time (16 books, 20,000 documents, 16 MiB raw
text, or 20 seconds, whichever is reached first), commits once, atomically
writes a checkpoint, closes SQLite/Rust state, and returns. A single book may
exceed a byte/document bound because upstream's canonical whole-book API is
the indivisible unit.

A compatible final index seeds incremental builds. Canonical upstream book
fingerprints detect content and metadata changes; delete+add is transactional
and replay-safe. Promotion happens only after bulk-off, final commit, optimize,
compatibility, count, and fingerprint checks.

Recoverable per-book input/PDF failures roll the whole writer transaction back,
are written to a source-identity-bound failure ledger, then replay from the
same checkpoint. The replay skips only the matching failed source and continues
with later books; changing the database/source identity makes it eligible for a
retry. Unknown SQLite/writer/commit failures remain fatal. An oversized book is
logged and isolated as the only book in its batch.

Upstream PDF fingerprints are intentionally zero and are never freshness
evidence. Swift stores an orchestration-only identity over the SQLite-backed
PDF pages plus index metadata; matching identity and indexed path are both
required to skip a PDF. This does not change Rust search semantics.

Before any copy or build, Swift checks important-usage free space. A seeded
build budgets a full final copy plus `max(50% of seforim.db, 256 MiB)` growth; a
fresh build budgets `max(2x seforim.db, 256 MiB)`, and both retain a 512 MiB OS
reserve. `previous` is the rollback copy and is deleted only immediately before
the next validated promotion replaces it.

## Runtime resources and semantic identity

`OtzariaMagicDictionaryManager` discovers the latest
`Otzaria/SeforimMagicIndexer` release over HTTPS, streams `lexical.db` with
`URLSession.download`, validates release size and SHA-256, and atomically
promotes a `.part` file with a version marker. A prior hash-valid file remains
usable after network failure; without one, upstream fuzzy fallback remains
available. No downloader exists in Rust and no downloaded database is tracked.

The production semantic feature is compiled into Apple artifacts. The GGUF
model itself is intentionally not vendored; callers must use the upstream
artifact/license flow recorded in `Upstream/RESOURCE_MANIFEST.json`. When an
authorized model is configured, its model ID, SHA-256, corpus identity,
embedding dimension and pinned semantic sidecar revision form the optional
semantic artifact identity. Runtime semantic UI remains off without that
validated artifact.

## Acceptance harnesses

The macOS CI policy harness exercises A/B-good, C-recoverable, D-good replay,
commit/checkpoint failure, PDF freshness, changed-source retry and oversized
batch decisions. A real corpus can be run on an isolated iPad simulator with:

```bash
bash Scripts/run-otzaria-corpus-acceptance.sh /absolute/path/to/seforim.db 7030
```

It builds the production-semantic XCFramework and full Swift app, indexes the
database through the same Swift/Rust path, and writes a JSON report checking
book count, indexed paths, categories, `/base`, authors and quarantine count.

## Structure

```text
include/otzaria_search_engine.h         C ABI used by Swift
ios_bridge/                             Rust staticlib adapter + Cargo.lock
Upstream/                               tracked pin and identity manifests
Checkout/otzaria_search_engine/         ignored pristine checkout
Resources/                              tracked, hash-verified lexical resources
```
