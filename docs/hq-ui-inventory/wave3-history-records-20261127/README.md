# Qualified History publication — source checkpoint

This is the passive source prerequisite for exact original History/Favorites record navigation. Base application source: `5d4b110a61882dea413c110b3d4f8026f4aa2b54`. It changes exactly three existing source files. No record route or App Intent is shipped by this checkpoint.

## Original identity and scope

The original sidecar HistoryEntry.id is the full TextLocator.persistenceKey, including backend, work and position. Original BooksData.id is a numeric work identity. Two saved positions can therefore share the original ForEach row ID. Discovery must retain the actual original published card object, exact locator, section membership and unambiguous original numeric row identity. This code never calls an allocating identity registry or reconstructs a record from an integer.

The original load publishes legacy arrays first, then awaits qualified records and can publish a late result. All original array assignments, ordinary open/favorite/delete behavior, mutation order and persistence remain in place. A late Task can still replace arrays or clear current metadata. This checkpoint does not claim to repair that original UI loading behavior.

## Passive source proof

QualifiedLocatorStore now owns a monotonically advancing nullable publication revision. Every original state mutation advances it before mutation, including legacy association; an absent remove remains the original nonmutation. Exhaustion permanently refuses observation. Actor initialization reads its existing file before any token can escape; no reload/reset method exists. External edits to the sidecar file are outside the original actor's in-memory ownership and are not claimed to be synchronously watched.

entriesWithObservation reads the same original entries and captures the token within one actor turn. A recursive lock protects only publication metadata. withCurrent holds that metadata through a short synchronous report/revalidation, with no actor call, suspension or encoding in that boundary. A failed original persistence operation still invalidates earlier source proof.

HistoryViewModel records one load revision and captures actual backend, generation, transition token and qualified-path state before the actor await. Metadata can publish only for the latest load, the same source and a still-current store token, after the original cards are published. Legacy/unqualified cards, duplicate full record keys, wrong section membership and duplicate original numeric row IDs fail closed. The metadata retains the actual BooksData objects and checks their exact locators/order.

This equality proof is not an Observation latch for model/search changes. The downstream route must retain one-shot reads of the actual @Observable owner across every await, validate exact scene/route/view before and after callbacks, and keep the actor token locked for the final synchronous report. Record reveal will remain separate from canonical reader.open at the remembered reading position.

## Executed verification

- Initial component compile failed because the new nested Load lacked explicit @MainActor. Its inputs and full compiler output remain in attempt-1.
- The corrected initial candidate ran 28 controls with 0 failures in attempt-2.
- The final exact source ran 31 controls with 0 failures in attempt-3, including three synchronous report-token controls.
- Removing only original store publication retirement produced 23 passes / 8 failures.
- Removing latest-load and backend generation/transition guards produced 27 passes / 4 failures.

These compile and execute the verbatim actual sidecar actor, including original persistence, actual TextLocator/BackendID contracts, and the new original-owned publication methods. BackendCoordinator, BooksData and the minimal History owner shell are explicitly declared domain substitutes. Reordered load boundaries are exercised directly; the original asynchronous app load task, Observation macro, Core, SwiftUI, UIKit and native screen are not executed. These are source/domain component results, not original app or native acceptance.

No persistence errors appeared in the passing final log. That observation is not a cross-platform durability acceptance claim. Generated synthetic fixtures stay separate from production data. Exact generators, sources, counterfactuals, commands, exits and logs are retained. Host-only executables are hashed separately and not committed.

## Ownership and pending work

QualifiedLocatorStore is a downstream source file absent from pinned upstream. Both History files are derived from upstream; exact base/current/upstream hashes and full diffs are in PROVENANCE.json. Root explicitly reserved this narrow passive metadata seam. Fresh authentic source-bound owner review remains required by final integration policy; no signature or historical approval was changed.

The actual record binding, original-card reveal/witness hooks, typed system entities, installed app compilation and new native tests remain separate pending work. Original Native116/Release114+2, all294 mappings and51 acceptance families are unchanged.
