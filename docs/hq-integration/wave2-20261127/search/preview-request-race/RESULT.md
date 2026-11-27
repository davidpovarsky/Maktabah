# Current-request fence for original Search preview

## Observed defect and change

Wave3 review on coordination task 1220939535420506, comment 1220940976617000, identified that an old provider can finish with an ordinary error after SwiftUI cancels its preview task. In baseline 780ede48, the generic catch still publishes that old error and the trailing assignment clears the newer request's loading state. The existing CancellationError catch itself returns without that assignment; it was not silently credited with the generic-catch defect.

The original SearchResultContextPreview now allocates one UUID per live request. An already-cancelled task returns before starting a request or mutating state. Success publications require the same current UUID. Ordinary error publications require that UUID and a live task. A single defer finishes loading only for the same live request. Superseded completions cannot modify the newer request's segments, error or spinner. A current provider CancellationError also stops its own spinner when the task itself is still live.

The selected-edition provider call, default provider call, canonical identity, grouping, sorting, unit mode, UI structure and original actions are unchanged. There is no network injection or acceptance-only product path.

## Actual source-qualified controls

| Evidence | Baseline | Candidate | Scope |
| --- | --- | --- | --- |
| Apple Swift6.4 compile of verbatim original task body | Exit0 | Exit0 | Actor-isolated component harness with a held fixture provider |
| Same deterministic assertions | 22 pass /15 fail | 37 pass /0 fail | Seven out-of-order/cancellation schedules plus current failure, empty result, already-cancelled start and selected-version forwarding |
| Whole actual original preview view on iPhoneSimulator27.0 SDK | Not repeated | Typecheck exit0, empty diagnostic log | Original State/AppStorage/task/View body with explicit unrelated model compile boundaries |
| Original file Linux syntax / Git diff whitespace | Not repeated | Exit0 /exit0 | Syntax and patch checks only |

The held provider intentionally does not automatically honor Task.cancel(). It can resolve an old call as an ordinary error, CancellationError or success before or after the newer call. Assertions inspect the actual extracted task's segments, error and loading publications. The original branch fails the expected race conditions; these are not tests that merely reproduce an implementation's happy path.

All37 assertions and the15 baseline failures are retained in baseline-run.json and candidate-run.json. Actual commands, Apple compiler/SDK identity, source and binary SHA256 values are in apple-control-receipt.json. The whole-view SDK command and explicit compile boundary are retained separately in whole-view-typecheck-receipt.json, SearchResultContextPreview.verbatim.swift and SwiftUIViewCompileBoundary.swift.

## Source identity and reproduction

- Baseline commit: 780ede48ca90c65bcda1d8349b059dd2dd095ac3.
- Original source: Source/Features/Search/iOS/SearchResultsListView.swift.
- Baseline source SHA256: f2e04982fed6c3f6fa83fa57255c693ae7b96ad1a1c11f46b9053e4af01f0ec7.
- Candidate source SHA256: 50608dd921aad1290a0ced53628fd5674b6476432c8b3cb58f66c3ce39ac7baf.
- Actual Mac control directory: /Users/m1/builds/otzaria-wave2-search-20261127/preview-request-race-20261127.

build_preview_request_race_control.py extracts the final original .task body and SearchPreviewSegment declaration verbatim from each input source. baseline-source.txt retains the actual prior file. extraction.json records the inputs and exact generated source digests. The unrelated fixture state/model/provider boundary is explicit in the generator; it is not the real network provider or a SwiftUI lifecycle simulation.

The whole-view typecheck includes the complete current SearchResultContextPreview and SearchPreviewSegment declarations verbatim. It checks the actual Apple SwiftUI property wrappers, actor isolation and View expressions but supplies compile-only model/helper boundaries. Neither compile establishes a full application build.

## Remaining acceptance

This is a source regression fix with actual Apple component controls and SwiftUI SDK typechecking. It does not close native UI, full-v40, full-v32, physical offline, published-index installation, VoiceOver or integrated-candidate acceptance. The original integrated Search UI cases must still execute against their separately qualified corpus, provider and app build. No existing source/data/Native116 receipts are relabelled.
