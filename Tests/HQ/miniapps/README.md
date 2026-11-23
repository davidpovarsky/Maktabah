# Otzaria MiniApps consumer checks — 2026-11-23

Base: `acdf25482541199e2d7fe331cc7e557ee462cddc`; isolated branch `codex/otzaria-miniapps-bridge-20261123`.

## Changes and persistence ownership

The existing reader selection menu and original annotation editor toolbar invoke the shared MiniApps picker. Only the Foundation bridge and SwiftUI picker are linked; execution stays in the separate Hanlin MiniApps app. Existing URL schemes handle warm and cold return. The scene owner and original annotation identity are stored with each request. A reader quotation creates an attached note using the original annotation writer; source books remain read-only. Existing note edits use captured original SQLite ownership, original row mapping and CloudKit pending queue. An external result and its receipt commit in the same SQLite transaction before the shared transport is acknowledged. File results are copied into the host Documents/MiniApps directory before recording their URL in the original plain-text note.

Original editor callers differ: some save synchronously, some catch errors, and one schedules asynchronous persistence. Therefore a generic onSave callback cannot establish a durable acknowledgement boundary. The bridge uses the original captured database connection plus row writer directly, and then refreshes the original caches, CloudKit queue, reader and open editor. No alternative note storage or editor is introduced.

## Executed evidence

Swift 6.4.3 on Oracle Linux aarch64 compiled the production document adapter against the already compiled real shared bridge, and the production receipt journal against the unchanged original `SQLiteDatabase.swift`. A Linux-only fail-loud Zstd symbol makes the original file linkable; these tests access TEXT columns only and deliberately do not test compressed book decoding.

Document checks (10 passed, zero failed):

```text
PASS cold_capture_roundtrip_hebrew_anchor_profile
PASS actual_note_utf16_selection_replacement
PASS read_only_reader_selection_returns_annotation_not_book
PASS insertion_uses_original_note_selection
PASS empty_document_replacement_is_retained
PASS url_result_is_preserved_in_plain_note
PASS attachment_result_references_host_retained_file
PASS missing_file_never_becomes_empty_note
PASS changed_original_selection_preserved
PASS display_operation_does_not_edit_document
RESULT 10 PASS / 0 FAIL
```

Receipt checks (7 passed, zero failed):

```text
COMMITTED_WITHOUT_TRANSPORT_ACK
REPLAYED_WITHOUT_SECOND_EDIT
PASS edit_and_receipt_commit_in_original_sqlite_transaction
PASS same_result_replay_does_not_run_edit
PASS conflicting_callback_preserves_original_edit
PASS profile_retirement_rolls_back_edit_and_receipt
PASS failed_native_edit_never_leaves_ack_receipt
PASS first_process_durably_saves_before_callback_ack
PASS new_process_replays_saved_receipt_without_duplicate
RESULT 7 PASS / 0 FAIL
```

The last two checks execute separate OS processes against the same real file-backed SQLite database. This proves durable host receipt replay after a commit/ack interruption; it does not assert an iOS cold-launch pass.

All four additive Swift files and the three narrow native hooks passed `swiftc -frontend -parse -target arm64-apple-ios27.0`. This is syntax validation only. Project source memberships and the two lean package products were checked, both original App Groups were preserved, all 620 existing localization entries were unchanged, and `git diff --check` passed. Source and shared dependency hashes are in `evidence-20261123.json`.

Initial compile setup attempts exposed the new SwiftPM products layout and Linux Foundation's lack of `String(localized:)`; the portable adapter now uses NSLocalizedString. Linking original SQLite required the explicit unreachable compression test support above. Those initial attempts did not run tests and are not counted as passes. Shared bridge acceptance owned by the SDK lane was reused, not rerun.

## Reproduction

The already compiled SDK products directory used in this run was:

`/mnt/development/projects/worktrees/hanlin-miniapps-bridge-core-20261123/Packages/HanlinMiniAppsBridge/.build/out/Products/Debug-linux-aarch64`

```sh
python3 Tests/HQ/miniapps/run_checks.py --bridge-products /path/to/already-built/Products/Debug-linux-aarch64
```

The runner creates and removes only its own temporary binaries and SQLite module map. It does not build the shared SDK or repeat any unrelated suite.

## Native acceptance still required

The source at this checkpoint has not been Apple typechecked, built or exercised in Simulator/device. Scheme `Maktabah-iOS`, project `Maktabah.xcodeproj`, runner `xcode-27`, iOS 27, bundle `com.davidpovarsky.chavrusatext`, development team `NA6HPWARQ2`. Both existing Debug and Release URL schemes remain intact. Root integration owns the final HanlinSDK gitlink and provisioning for the newly appended shared group.

The new native lane should reuse `Scripts/CI/hq-stage2-focused-apple.py --build-for-testing` for the real Pods/React/native graph, then run only the new reader/editor/callback cases. Existing native workflows are `otzaria-original-editor-stageb-native.yml` (Original editor saved annotation native acceptance), `otzaria-completion-focused-native.yml` (Original fresh-read no-send native diagnostic), and `otzaria-hanlin-live-native.yml` (Original Hanlin live consumer native acceptance). They are references for original build mechanics, not evidence that the new MiniApps hooks passed. Previously accepted unrelated journeys are not rerun by this change.

## Added real two-app native lane

`MiniAppsAnnotationAcceptanceTests/testOriginalNoteReturnsTextFromActualMiniAppsAndPersistsAfterRelaunch` creates and saves a blank annotation through the original UI, opens the actual shared picker, launches the separately built Hanlin MiniApps TextStudio, types a unique Hebrew/English result through its actual editor, uses the actual Return button, and checks the original row and atomic receipt before and after a real Otzaria process restart. It does not fabricate a producer, request result or saved note.

The existing `sefaria-embedded-validation.yml` workflow's supported `runtime27_mode=ui` and source-controlled native subset mechanism execute this single new case. All original catalog case entries remain present; the new case is supplemental and the result remains selected-only acceptance. No workflow YAML is changed. `Scripts/CI/otzaria-miniapps-native.py` installs the exact original producer artifact into the original matrix-owned iPad simulator and records both apps resolving the same group, actual XCTest captures, shared transport record and original SQLite receipt. The immutable producer inputs are recorded separately. The original native build uses the existing `hq-stage2-focused-apple.py` path.

Peer source review found a presentation race when several queued results arrive and a duplicate picker dismissal. Result presentations are now serialized per source scene, display-only results are acknowledged when the user closes them, and the shared picker owns its dismissal. The updated coordinator passed Apple-target syntax parsing; this is not Apple typecheck evidence. The new test declaration and changed Python source syntax were checked. The existing 17 portable checks were not repeated because their tested source and shared contract did not change.

At authoring time this lane is prepared, not executed. Apple SDK compilation, actual UI outcome and physical provisioning must be reported from their actual runs.

### First actual Apple run

Run [45271246360](https://github.com/davidpovarsky/Maktabah/actions/runs/45271246360), checkout `6a9e10235c73f2da7967d25e50349a4b93f03807`, compiled the new real XCTest successfully with Xcode 27.2 (27B52), Apple Swift 6.4.2 and the iOS Simulator SDK. Original app-target membership also passed. Its unmodified compiler report is retained in `apple-sdk-compile-45271246360.json`. This is SDK compile evidence; no native UI case executed.

The following original app-build preflight stopped because its reviewed project Git blob still referenced the project before the four MiniApps adapter files and two products were added. Review of the complete project diff confirmed those additive registrations only: the standalone engine test package remains absent, every original entry is preserved, and the other three excluded build input blobs did not change. The exact exclusion manifest/pinned digest now records that review; the validator is unchanged. Subsequent native runs reuse the successful standalone UI SDK compile only when every source hash, compiler driver, project blob, Xcode/Swift version and SDK path match. The actual app build and first native UI execution remain required.

### Cold source callback and final source corrections

The same single new native case additionally invokes TextStudio from the reopened original note, types a second unique result, terminates Otzaria while TextStudio stays foreground, and presses the real Return button. It waits for Apple's callback to launch Otzaria and for the original saved annotation editor to become visible; it performs no manual launch, activation or navigation after terminating the source. Both actual requests must have distinct durable receipts for the same original annotation UUID/row, and the first receipt must remain unchanged.

The original application data profile can already be selected through its embedded `OtzariaDefaultDataProfile`. This lane uses the existing `OTZARIA_DEFAULT_DATA_PROFILE=miniTest10` build setting through an explicit simulator-only option in the original build runner. This retains the normal native bootstrap and profile across Apple's cold URL launch, where XCTest process arguments are absent. The built Info.plist is verified and hashed; app binaries and Info.plist are unchanged after the build. Production/default builds retain their original profile.

Run 45272705731 reused the exact successful Apple test-source compilation with zero repeated compiler invocations, then stopped in strict package resolution before app compilation: the canonical HanlinPresentationSDK requires streaming-markdown 5cbb4b6 while the inherited lock still held 6bde022. Only that one of the 17 locked dependencies was corrected. The strict resolver remains enabled. The added cold journey changes XCTest source, so its next Apple compile is necessary; the unchanged 17 portable document/receipt checks remain reused.

Cold presentation now waits for a real visible source presenter. Already acknowledged URL callbacks are no-ops and cannot reapply the edit or display a false changed-document conflict. Final actual build/UI results must be recorded from the selected native run; these source corrections do not themselves prove native execution.
