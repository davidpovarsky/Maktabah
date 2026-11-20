# Native98 note editor witness placement candidate

## Status and source

This is a source candidate for the original failing NativeRoutingAcceptanceTests/testCoreNoteDraftUsesOriginalUnsavedEditorAndCancelOnPad. Candidate Native execution and Apple typechecking are **NOT_RUN**. The checks here establish source preservation and Swift syntax only; no runtime test was executed for the placement candidate.

The isolated base is fa65529611f65cd6a145d99dec49e10e01ffd52f. The actual failed run is [44723902453](https://github.com/davidpovarsky/Maktabah/actions/runs/44723902453), attempt 1, checkout 60a57972acb28739ec738565083bf17fb7503028, application/test source 87b783ac3f0257e8461762e0ea9dfa5248dd06e8. REVIEW.json records exact old, base and candidate hashes, including the files that changed between the failed source and the current base. This candidate is not attributed to that earlier run.

## Actual failure evidence

The retained original result reports cancelled / deadline_exceeded, with the original unsaved editor, exact proposed note and unchanged annotation store all observed. The original screenshot and accessibility hierarchy show the editor. Source-owned diagnostics report a valid owner, binding, source and projected note surface, but markerRegistered=false at the recorded boundaries, including the deadline. The text view and its window/scene were present at that boundary.

Registration happens unconditionally in NativeSurfaceWitness.updateUIViewController, before its visibility and geometry guards. The evidence therefore establishes that this registration was absent, not why SwiftUI failed to mount/update it. It does not prove a TextKit, geometry, scheduling or Observation root cause.

The 35,944,918-byte primary evidence ZIP (artifact 14632383919) was independently rehashed here as 1dec4baa131deaa5cfdb1f2f62b3dea6a84ee7713bccf67a2e62a41f1ff72310. The selected capture receipt binds artifact 14632274701 to the same run/source. Only selected entries of that approximately 775 MB capture archive were retrieved and CRC/SHA checked; the full capture archive was not downloaded or hashed. The retained PNG is the exact original capture, without crop, rotation or pixel transformation.

## Narrow candidate

The editor gains an optional, default-nil @MainActor () -> AnyView observation closure. The same existing .noteDraft modifier, with the same reader and locally captured editing annotation, moves from outside the editor's NavigationStack to the background of its actual ThemeForm. The editor remains independent of the routing package. Save, Cancel, deletion, binding, UUID ownership, text view callback and persistence statements are unchanged.

Two DEBUG-only fixed diagnostic strings record the existing witness make and update boundaries. They do not report visibility, fabricate evidence, acknowledge navigation or change callback order. The normal diagnostic callback remains the existing host-supplied one.

No Session, Bindings, Projection, orchestration, Native test assertion or timeout was changed. The original 5-second action deadline and 600-second Native case limit remain. Search cold-readiness and the separate commentary setup uncertainty are separate investigations, not results of this change.

## Actual validation and review

- Three exact source inverses reconstruct the base files.
- Six guard/oracle files match the base byte for byte after normal Git newline canonicalization.
- Three DEBUG Swift syntax parses completed at 14:05:27â€“14:05:29 UTC on 2026-11-20 with Swift 6.3.3 on Windows, targeting the iOS syntax path. Each returned 0 and emitted the two retained cross-target SDK warnings. This was not an Apple SDK typecheck.
- Runtime tests executed: **0**. Candidate Apple typecheck: **NOT_RUN**. Candidate Native/UI: **NOT_RUN**.
- Root approved the narrow placement scope. Independent peer source review found no blocker in the three hunks; actual SwiftUI mount and completion still require Native execution.

Run the bounded evidence/source verifier from the repository root:

    python docs/hq-integration/native98-note-witness-20261120/verify-evidence.py --repo .

ARTIFACTS.json binds every retained raw gzip, screenshot, review, README and verifier. Gzip entries retain the exact original uncompressed bytes and include both compressed and uncompressed SHA-256. Verification is source/evidence-only and does not rerun Swift or Native.

The three authored text files use canonical Git LF bytes in the manifest; raw gzip payloads and PNG bytes are never newline-normalized.
