# Reject obsolete original History results

Separate corrective change after metadata commit `1330c29fd259ce74d30b3e39b2e020b60bb57700`. The original array publication was reproduced failing in a source/domain asynchronous control. The prior metadata checkpoint correctly refused navigation proof but still allowed those obsolete arrays to replace current cards.

## Reproduction and change

The actual original loadBooksData body starts a Task, awaits qualified records, then reads the active backend and assigns the original History/Favorites arrays. With controlled actor-read completion, an older request can finish after a newer one. A backend/resource transition or sidecar publication can also occur before its result reaches the original MainActor publication.

The baseline ran eight cases: two passed and six failed. The failures replaced current visible-model cards with an older task's cards, old entries filtered against another active backend, an A→B→A source, changed same-backend resources, an aborted transition, or a retired sidecar snapshot.

The corrective hunk is exactly one four-line read-only helper in HistoryViewModel and one two-line guard after the original weak-self check in History+Database. It checks the already-captured latest-load revision, backend, generation, transition and sidecar token before the original active-backend/filter/array statements. It adds no cancellation, retry, replacement model or fallback. A current load still executes the original array assignments in their original order; native legacy-path arrays are preserved.

The candidate passed all eight cases. Actual production helper/load bytes were then compared to those previously compiled proposed bytes; the only harness instrumentation is a completion defer inside the Task, with no data mutation or suspension. No duplicate test was run after applying the identical source hunk.

## Evidence boundary

These controls compile the actual load method and actual publication/token methods over explicit backend/catalog/BooksData/actor-read substitutes. Actor completions are controlled to reproduce permitted await ordering; the fixture completion defer makes task completion observable. They are source/domain controls, not an original app, SwiftUI, database-provider or native screen run. No new native, SDK or physical pass is claimed.

The guard tests token validity at original publication entry. The downstream native record transaction still requires the metadata token lock for its final synchronous report and one-shot original @Observable model reads across waits. This patch does not add an actor notification/reload framework or claim to track external sidecar file edits.

Original legacy integer-only record identity remains unresolved for typed record navigation. Qualified duplicate numeric row IDs remain fail-closed. Exact remembered-position reader.open, typed record/card navigation and installed-app acceptance remain separate outstanding work.

## Preservation and provenance

All baseline and candidate compiler commands, outputs, exits, source inputs and generated source remain in attempt-1. PRODUCTION_EQUIVALENCE.json proves the applied bytes match the compiled proposal and reverse-removing this hunk restores metadata1330 exactly. production.diff.gz is a lossless copy of the exact diff; the raw diff and executable files remain on the host and are hashed in EVIDENCE_MANIFEST.json.

Both original History source files retain their upstream derivation and require final authentic source-bound review. Root explicitly approved this exact corrective lease after the baseline reproduction. No original selectors, gate counts, signatures or source data were modified.

To reconstruct the two controls in a new empty directory, run make-controls.py with attempt-1/inputs as its source root and an explicit new output path. The original candidate and baseline evidence is immutable.
