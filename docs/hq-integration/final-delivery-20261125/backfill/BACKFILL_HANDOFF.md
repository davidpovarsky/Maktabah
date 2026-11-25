# Explicit local preparation of existing notes ? 25 November 2026

## Scope and source

This checkpoint adds the normal iOS Settings entry for explicit, bounded local
preparation of saved annotations. It consumes the original Repository connection,
SQLite transactions, immutable exchange ledger and stable legacy identity map
from d0bc03f9a3767e4c14e50324a29ceb3cff38a874. Existing CloudKit record names,
annotation rows, tags, pending CloudKit operations and native rich bodies remain
authoritative. No destination is selected and no network acknowledgement is made.

The planner scans a captured high-water mark in batches of at most 100 rows
(default 50), skips metadata-only highlights and pending deletions, records
separate local plan versions, preserves earlier committed batches on cancellation,
and reuses exact current receipts after restart. Plain text is never labelled as
native Anytype data. Existing native bodies are referenced without flattening.

## Verification state at this source checkpoint

- The actual Apple plist parser accepted the project changes: 12 added objects,
  five explicitly modified source/resource/group arrays, no removed objects and
  all other existing objects unchanged.
- Actual iOS 27 Swift syntax parsing passed for planner, Settings and view.
- This is syntax/project graph evidence only; compilation, component runtime,
  application UI and native conversion are pending.
- The new Foundation gate compiles whole original source files. Its intended
  coverage is 13 functional/measurement cases, actual local preparation at
  100/1,000/5,000 notes, independent Python SQLite/hash verification, a separate
  5,000-note reopen process, and a writer intentionally exiting 73 after the first
  committed 50-row batch followed by a separate resume process.
- The historical 43 + two cold-reopen and 28 exchange assertions remain owned by
  the identity lane. No unchanged Core4194 or NativeHeart66 run is duplicated.
- The component gate explicitly uses the existing unrelated UI/catalog/CloudKit
  boundaries. Its timings are local preparation timings, not Anytype or UI latency.

## Remaining integration

Consume actual results before claiming success. Merge original Receive/native
conditional-update work, run the real integrated application and native editor,
finish real multi-client synchronization and native 5,000-note performance,
and then refresh the strict final source-admission manifest to the actual final
source. The earlier 3a7d048 source-profile proof is historical and cannot admit
these changed product bytes. Native116, Release114+2, owner verification, Archive,
upload, Apple processing and TestFlight installation remain open.
