# Original TOC load lifecycle repair

Source fix: `bbc68b0d8125a47f8c195653db77a7f771854837`, base `29a731e273f9a757c743c49e182fece0e8047d46`.

The whole original `BookTOCViewModel.swift` and `TOCNode.swift` compiled with Apple Swift 6.4, strict concurrency, optimization, and the actual SwiftUI/Observation/OSLog frameworks on Xcode 27.0 (27A266a). Delayed backend and database continuations are explicit test boundaries. This is source-level lifecycle evidence; it executes no application UI, production database or physical iPad scenario.

| Same regression | Compile | Runtime | Result |
| --- | --- | --- | --- |
| Original 29a731e2 | 0 | 1 | 20 passed, 14 failed |
| Candidate bbc68b0d | 0 | 0 | 34 passed, 0 failed |

All 34 case names, boundary bytes and test bytes are identical. Original and candidate inputs retain exact hashes in INPUTS.json. Runtime and compiler logs and the exact command, compiler version and executable hash remain in each RESULT.json. Native binaries and unchanged source snapshots remain on the Mac under `/Users/m1/builds/otzaria-wave2-reader-controls-20261127`.

The defect allowed an older cancelled request to clear the current loading indicator. The original native database branch also never published terminal loaded/failed state, and previous ranges and navigation structures could remain after switching or cleanup. One generation now owns each load, its completion and its loading callback; the original native loader is released for every acquisition. Empty success and failure have distinct terminal states.

Covered: same-work retries; new books; backend-to-native and native-to-Embedded transitions; previous success/failure while a new request waits; cancellation during fallback; immediate loading state; stale range/cache reset; explicit cleanup and late completion; offline/corrupt/general errors; retry; genuinely empty success; and exact loader release counts.

An initial fixture attempt in `baseline/` failed compilation because the fixture registry was erroneously MainActor-isolated. The actual registry is a nonisolated synchronized class. The boundary was corrected to the same threading contract before the before/after comparison; no production source was changed to accommodate it. This first attempt is retained and is not counted as a product failure.

Required next: full original app compilation and source-bound Sefaria/Otzaria native UI journeys. No existing native result is transferred to this changed source, and R/PERF source tasks remain open.
