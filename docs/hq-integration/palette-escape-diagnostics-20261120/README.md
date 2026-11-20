# Escape diagnostics in the original command palette

## Status and scope

This change adds **observations only** to the existing iOS command palette and its two original reader hosts. It does not repair or claim a successful Escape dismissal. Apple typechecking and Native execution of this change are **NOT_RUN**.

The source baseline is **0f5111e8f8e379e17da558ddbe2aab5214ac0315**. The branch is `codex/otzaria-palette-escape-diagnostics-20261120`.

The historical first failure is Release run [44665679661](https://github.com/davidpovarsky/Maktabah/actions/runs/44665679661), application source **7e777509d486a17bec5b4bd437a9ac7f51d3a43a**. The iPad11 case `FaithfulReaderUIAcceptanceTests/testPointerHoverClickAndHardwareKeyboardDismissal` typed a query, displayed its original result, sent Escape, then failed its unchanged 15-second dismissal assertion. The retained recording shows the palette, caret and software keyboard after the command. The existing record does not prove which application responder/callback received the key.

The independent source/video review is already preserved at commit **836fd2affd7ad5c69808bfbf1e665d289ed1e2fe**, under `docs/hq-integration/release-library-admission-20261120/ESCAPE_READ_ONLY_REVIEW.json` and `ESCAPE_FRAME_RECEIPT.json`. The raw Release log is retained in **f2a4eef9**, under `docs/hq-integration/release96-44665679661-20261120`. No video download or Native execution is repeated here.

## Source ownership and preserved behavior

The instrumented package is the existing workspace-owned local package:

`Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift`

It is an ordinary tracked Git blob, referenced by the project's existing `CommandPalette source fork` local Swift package. Its existing MIT notice remains unchanged. This is not the Hanlin or TorahInspector upstream SDK. **Vendor/HanlinSDK remains e00498e33f106cc43be0476ffa2e09329c8ca300.** Vendor trees, package pins and the Xcode project have no diff.

Product additions are inside `#if DEBUG` in four existing files: the palette view, `LibraryCommandPaletteAdapter.swift`, `ChavrusaReaderHost.swift`, and `ReaderSidebarPageCoordinator.swift`.

Every original keyboard branch, return, first-responder guard, focus operation, callback and presentation-state assignment remains. The selector method and one existing adapter closure are expanded from a single line to insert observations; their original statements remain in the same order. No replacement control, responder, shortcut, model or dismissal path is introduced.

The existing Native test gains an explicit diagnostic launch flag. Its original pointer operations, Escape command, result checks, frame check, dismissal assertion and timeout remain. Other tests leave the flag off.

## Default-off gates and bounded schema

Both package emission and application collection require all of the following:

- The explicit `-CommandPaletteEscapeTraceEnabled` argument is present.
- Its original UserDefaults argument-domain Boolean is true.
- The launched environment selects `OTZARIA_DATA_PROFILE=miniTest10`.
- The existing `studyWorkspaceTestingNamespace` parses as a UUID.

The host additionally verifies the actual `OtzariaDataProfileRegistry.activeProfileID` is miniTest10. A persisted Boolean without the explicit launch argument cannot activate the trace. Release compilation contains no emitter, subscriber or diagnostic writer.

The package posts an in-process notification containing fixed stage values, Boolean ownership/focus flags and, only for observed Escape dispatch, the fixed HID code 41. The host accepts only those fields and stages. Query strings, typed characters, work identifiers, content and model/provider data are not recorded. The UUID is only an activation guard and is not logged.

Identical repeated state queries are deduplicated. The host retains at most 256 ordinary trace events per process, then writes `stage=trace.limit` once. A capped trace is explicitly incomplete evidence. The diagnostic counter does not control any UI branch.

| Trace stage | What it observes |
|---|---|
| `adapter.appeared` / `adapter.disappeared` | The existing SwiftUI adapter's lifecycle callback |
| `key.commands` / `key.can.escape` | The field's original registration and original admission predicates |
| `key.presses` | Whether the existing presses set contained Escape; no other key value is retained |
| `key.command.escape` / `key.insert.escape` | Entry through the original Escape selector or original escape-character fallback |
| `dismiss.enter` / `dismiss.admitted` | State before and after the existing first-responder guard |
| `dismiss.resigned` / `dismiss.returned` | State after the existing resign operation and after the existing callback |
| `reader.*` / `viewer.*` | Entry/return of the original open/close path and observed presentation-state changes |

The flags include actual first-responder ownership, window attachment, key-window status, foreground scene status, callback presence and desired focus. Host records include only presentation/focus Booleans. These records are not visibility acknowledgements. The existing XCTest remains the oracle.

## Persistent collection

The adapter forwards the allowlisted notification through the **original serial OtzariaFileLogger**, using the fixed `[NativePaletteEscape]` prefix. Its existing file is:

`<actual installed app container>/Documents/OtzariaLogs/otzaria-reader.log`

The collector's existing actual-container lookup and exact log copy remain. Its selection predicate now also includes the exact Escape case and a whole original Faithful suite selection, in addition to the unchanged routing suites. It retains:

- `build/artifacts/native-routing-logs-<label>/otzaria-reader.log`
- `build/artifacts/native-routing-logs-<label>/collection.json`, including actual container, byte count and SHA256, or the original MISSING/COLLECTION_ERROR status.

Collection still occurs after a failed case. It does not change failed UI status, relax verification, add a retry or extend a timeout. The original logger's timestamp is the time its serial writer formats the record; the trace is not a latency measurement. Sequence values order observations within a process, not a proof of unique UIKit event delivery.

## Verification actually executed

| Check | Actual result and boundary |
|---|---|
| Exact edit inverse | All 6 modified existing files reconstruct the original Git LF bytes. |
| Release source projection | All 4 product files retain the original source after excluding DEBUG additions and normalizing only blank lines and the two documented one-line expansions. |
| Swift parse, final DEBUG source | Five files parsed successfully with Swift 6.3.3 on Windows and an Apple target; two cross-target warnings retained. Syntax only. |
| Swift parse, final Release source | Same five files parsed successfully without DEBUG; same two warnings. Syntax only. |
| Original collector baseline | 17 controls executed: **11 PASS, 6 FAIL**. The six failures demonstrate that the original collector did not select or retain Escape evidence. |
| Candidate collector | The same 17 controls executed: **17 PASS, 0 FAIL**. |
| Apple module/type checking | **NOT_RUN** for this change. |
| Native / physical UI execution | **0 executed** for this change. |

The collector fixture executes the actual Python selection expression and the actual original collection body extracted from the script's AST. It doubles only the existing `xcrun simctl get_app_container` boundary. File writes, relocation, copies, byte equality, SHA calculation and collection JSON are real temporary-file operations. It proves failed status stays FAIL, routing collection stays available, exact Escape collection is added, missing/error states remain explicit, and unrelated selections cause no collection.

The first fixture attempt is preserved: baseline **10/17 PASS, 7 FAIL** and candidate **15/17 PASS, 2 FAIL**. Its two shared failures were a fixture assumption that a relative Path string used POSIX separators on Windows. The fixture was corrected to require the exact platform-native relative path produced by the unchanged original collector. No production collector body was changed for this correction.

The first syntax/source validation before the explicit argument-presence guard is also retained separately. The final source hashes and final syntax invocation are in `SOURCE_PRESERVATION.json` and `SYNTAX_PARSE.json`. Current product bytes are tied to those final results; earlier parsing is not transferred to a different source revision.

Root independently reviewed all six source/test/collector changes and found no blocking source issue. That review is source-only.

## Commands and evidence

The focused portable command is:

```text
python tools/test-palette-escape-diagnostics.py --out build/palette-escape-diagnostics-20261120/candidate-collector.json
```

The actual command arrays, source hashes, case names, parse warnings, original collector snapshot, first attempt and exact inverse manifest are retained as lossless gzip under `raw/`. `EVIDENCE_MANIFEST.json` binds compressed and uncompressed bytes. Readable summary JSON is retained alongside this README.

The next authorized Native run must use the unchanged original case and inspect the persisted trace together with its actual XCTest outcome. Missing dispatch records alone do not prove a specific UIKit defect; the adapter activation, ownership flags, cap marker and original failure must be considered. No new run was dispatched by this diagnostics change.
