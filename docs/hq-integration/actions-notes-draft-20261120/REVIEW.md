# Original note draft action — implementation review

## Scope and source

Base: Maktabah integration commit `5d8ef991554b01ba6bf3d39222c5ef6cc00a264b`.
Isolated branch: `codex/otzaria-notes-draft-20261120`.
Original upstream HEAD was verified with `git ls-remote` during this change:
`d46af139b3a265399c16d87f5923acd8e3444024`.

This change implements `notes.prepareDraft` in the existing ActionCore and native scene composition. The original `iOSReaderWorkspaceView.editingAnnotation` binding, `ReaderViewModel.makeAnnotationDraft` factory and `iOSAnnotationEditorSheet` remain the owners of the editable, unsaved note. There is no new note store, persistence call, parallel editor, resolver, agent or UI executor.

The exact selected locator must already belong to the original active reader. Its UTF16 range must come from the original rendered segment or Otzaria database line anchor and must be visible in the original reader. There is no first-character, line-zero or whole-book fallback. A supplied selection must match the source bytes exactly. Proposals and selections retain the existing catalog bounds. The original factory creates the draft, and the same original selected locator override used by the existing Add Note flow is retained.

## Purpose, ownership and completion

The Core-issued one-use navigation preparation privately retains the exact note request. Generic surface/reader grants cannot be borrowed for a note; notes cannot authorize other surfaces, readers or changed proposals. A new typed Registry wrapper requires the exact semantic descriptor, sheet presentation, invocation and scene. The original NativeSceneNavigationOrchestrator is unchanged.

Preparation retains the original reader, selected locator/range, content identity, text mode and source bytes. It then issues/adopts the original scene admission. Native apply changes only the original editable annotation binding. Acknowledgement requires the actual editor's live UIKit text view, exact proposal text, foreground scene, sheet owner, effective unclipped viewport and visible TextKit glyphs for nonblank text. An independent NativeSurfaceWitness proves the actual sheet. The retained binding and admission live through the full Core result.

The final Core completion check runs the live backend/authority validation and then a synchronous original-source/editor/visibility observation on MainActor. It introduces no later backend callback or await within that final observation. The action never turns a failed post-effect check into a claim that no effect occurred. Native failures preserve a sanitized reason and status through ActionNativeUIFailure with retryable=false; post-acknowledgement loss is native_effect_uncertain.

The editor remains under the user's original Save/Cancel after completion. Native routing stays blocked during its actual presentation and dismissal, including after the editable binding becomes nil and before the original sheet's onDismiss callback. Other native routes and Hanlin context readiness do not treat that interval as an uncovered reader.

## Ownership and authorization

| Paths | Ownership at verified upstream | Change |
| --- | --- | --- |
| Source/Otzaria/Actions and Source/Otzaria/UIRouting | Downstream owned | Typed contract, Core execution, purpose-bound grant, existing Registry wrapper, portable regressions |
| Source/ChavrusaText/UIRoutingHost/Integration | Downstream owned | Retained original editor owner, scene projection and passive witnesses, Composition forwarding |
| Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift | Absent from upstream; downstream owned | Attach original editing binding and existing sheet's actual lifecycle to the host |
| Source/Features/Reader/iOS/iOSAnnotationEditorSheet.swift | Upstream owned; previously mixed legacy file | Three minimal passive observation hunks only |

The current owner explicitly authorized all necessary changes, runs, commits, pushes and merges without another permission request in the 2026-11-19 continuation instruction. The delegated execution instruction specifically requires the original note editor and actual visible receipt. This is standing task authorization; it is **not** a claim that the owner reviewed an unseen exact hunk.

The upstream-owned sheet adds an optional callback with a nil default, calls it from its existing actual UITextView creation callback, and clears it from the original disappearance callback. Its controls, initialization, Save, Delete, Cancel, text rendering, annotation coordinator and persistence methods are unchanged. A wrapper can witness the sheet container but cannot prove the private original text view or its text without that hook. Global UIKit introspection, a second editor and model-only/onAppear-only success were rejected.

Protected patch SHA256: `9a91dc8544df5d1ea7d343db30255a52727af7e83f0374aa64cd2a9265f77fb9` (git diff against the base, saved byte-exact in ORIGINAL_EDITOR.diff.gz).

## Review findings resolved

A separate read-only review by the native audit agent identified:
1. Window intersection alone could accept an editor clipped by ThemeForm's viewport. The proof now intersects actual clipping ancestors, rejects nonfinite geometry and reuses the existing TextKit glyph visibility helper for nonblank text.
2. Binding=nil can precede actual sheet dismissal. The original owner's presentationActive flag now remains true until the existing sheet's actual onDismiss.

The reviewer re-read those corrections and found no further demonstrated blocker in the focused ownership/lifecycle review. This is source review, **not** Apple compilation or Native runtime evidence.

## Verification and limits

Portable execution completed with Core 103/103 PASS (17 new note tests), UIRouting 94/94 PASS (9 new purpose/receipt tests), and native-host contract package 127/127 PASS: 324/324 total, zero failures. Exact commands, log hashes, toolchain and job ID are in portable-result.json. The native-host package here is portable contract testing, not Apple SDK or Native UI evidence.

Apple SDK compilation and actual Native editor execution for this new action: **NOT_RUN** by this implementation agent. They require the coordinator's subsequent exact-source Native run. Existing studyNotes UI evidence is not evidence that this new Core action ran.

The public action does not add Hanlin tools, content-read rights or external model access. The local scene-bound Composition entry is implemented; unsupported selection, hidden original reader, missing source, unavailable editor or unproven backend reference remain unavailable. Compact layouts whose original reader is covered remain unsupported until real visibility is proved. Search work belongs to a separate change; exact occurrence counts remain unavailable.

## Rollback

Revert only this isolated notes change. No database/schema, source corpus, upstream engine, dependency pin or original branch was changed. Re-review the three passive sheet hunks at the next upstream update. The commentary commit f17d06856fbe2258d17cd6db20052af4801e4486 remains unchanged.

Raw Windows stdout/stderr is preserved byte-exact in deterministic .raw.log.gz archives. Readable .log copies normalize trailing CR/space only; portable-result.json records both raw and normalized SHA256 values. portable-result-initial.json retains the original raw log hashes. The protected original-editor diff is also archived byte-exact to preserve its standard context-line spaces.
