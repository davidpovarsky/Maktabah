# Native iPadOS 27 Study Sheet — isolated implementation candidate

**Base:** `40c1eaa6bb0092336f1ee687ad1ce1425eaf4223` (M40). **Status:** source candidate; Apple Swift compilation, Foundation execution and all new Native cases **NOT_RUN**. No workflow, branch or active F4/F6 source was changed or activated. Later Root M409 changes Faithful capture behavior; this candidate never replaces Faithful and its retained M40 file is evidence only. Root reviews and integrates this packet before any actual Apple execution.

The current user authorization explicitly starts task `1219643110971002`; it supersedes the old PLANNED/no-code sentence retained verbatim in `TASK_CONTEXT.json`. The task's old SDK pin/deployment/CI descriptions are historical. The actual original TorahInspectorKit pin is **19d1b35397af4f10ae70cfb3f444c9de87383b53**, verified from M40 Package.resolved and the retained seven upstream files. No Kit, Hanlin e004, FloatingPanel, backend, engine, store or Core implementation is changed.

## Product ownership and presentation

`iOSReaderWorkspaceView` keeps its original Reader, `inspectorSession`, selected tool and content UUID. On feature-enabled iPad at iOS 27 it presents one actual SwiftUI `.sheet(item:)` from the stable workspace detail owner. The same Reader subtree remains in place when horizontal size class changes. The native path disables that owner's existing FloatingPanel presentation; the original phone, older-OS and feature-off branches are retained. Only the original iOS app target gains the new presenter source.

The system sheet uses `.height(155)`, `.medium` and `.large`, a visible grabber, system material and background interaction through medium. Logical leading is requested in RTL, trailing in LTR, to express physical right. **This is source intent, not measured geometry.** The Native tests must prove actual placement and same-iPad narrow adaptation against the real window; the presenter does not impose widths or padding to manufacture an oracle. Apple references are retained in the task context: [placement](https://developer.apple.com/documentation/swiftui/view/presentationplacement(_:)), [detents](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:selection:)), [background interaction](https://developer.apple.com/documentation/swiftui/view/presentationbackgroundinteraction(_:)).

The original `TorahInspectorView` stays mounted in the same structural branch at every detent. At Peek it is hidden from input/accessibility and visually clipped behind a compact display-only projection of the same current selection/loaded section. The projection has no repository or navigation stack and no source/note action implementation. It shows title, selected/current passage, selected tool, original close action, and a normal expand button. Hebrew passage direction remains RTL even under an English shell. The Kit uses its existing minimal chrome for the native sheet, avoiding a second material/rounded host.

Backend generation changes still run the original session replacement and close behavior. A text-mode change still performs the original mode-specific session replacement. This candidate does not preserve a stale source authority across a real backend/book change. Existing source-link, tab and backend regressions must remain in the final acceptance matrix; passing the new detent tests alone would not prove those transitions.

## Original notes and actual dismissal ordering

A small Foundation state retains the exact parent presentation UUID until real `onDismiss`. A note is routed either to the original root note sheet or to a sheet attached inside that specific study presentation, using the **same** original annotation editor, editor presentation UUID, callbacks, original NativeSurfaceWitness and original session owner. Its Save/Delete implementations, store calls and Core completion guards remain unchanged. A displayed child blocks background interaction and interactive parent dismissal.

Closing the parent or opening TOC while its note is present first dismisses the original note. The parent remains until that child's actual callback. TOC is published only after the parent's actual `onDismiss`. An explicit reopen during dismissal queues behind the old UUID; it cannot reuse the closing presenter. Late/duplicate callbacks are ignored using exact owner IDs. A real parent callback can also retire its exact child, without pretending that the child callback was independently observed; the diagnostic event labels this fallback separately.

Peer review exposed an unintended reopen: an item-nil callback changed only the sheet state while `readerInspectorVisible` stayed true, so a layout callback could request reopening. The corrected setter requires a captured **nonnull current UUID** and a currently presented owner, then synchronously invokes the unchanged `closeReaderInspector` after recording dismissal. Nil/stale callbacks and duplicate callbacks during a queued reopen cannot close a new owner. The exact earlier draft is preserved in `interactive-dismissal-before.swift`; no old Native failure is attributed to this new candidate-only issue.

The original close method deliberately clears selected segment/line state. Consequently the tests require selection-token equality across detent/size changes, and do **not** claim selection equality across an explicit original close/reopen. Reader/session/source identity and actual new presentation identity are still required there.

## Tests and their boundaries

* **20 Foundation lifecycle controls:** compile the whole new production file on macOS; iOS-only declarations are excluded by their real conditional. They cover child/parent ordering, root notes, TOC priority, queued reopening and stale/double callbacks.
* **5 owner-callback controls:** compile complete original Workspace binding/update/toggle/dismiss bodies and the unchanged original Reader close body, extracted byte for byte. The explicitly declared boundary supplies property storage, Binding and animation plus Reader data fields. It does not implement SwiftUI/UIKit mounting. The retained pre-fix draft must execute exactly **3 PASS / 2 FAIL** (the named owner-close-before-layout and duplicate-nil/queued-reopen cases); the candidate must execute **5 PASS**. Neither compile failure, timeout, missing rows nor process signal qualifies as RED. These expected outcomes are **NOT_RUN**, not observed results.
* **12 new real-app Native methods:** `NATIVE_CASES.json` names each method and separates three programmatic lifecycle races from actual controls/gesture geometry. RTL/LTR exercise actual drag detents; the same iPad shrinks below 748pt and returns wide; original Reader scroll, TextKit instance/source/anchor, original note Save/Edit/Delete/Cancel, actual TOC, embedded Sefaria and phone fallback are checked. Cases require the normal `realUI` bootstrap and original independently derived fixture identity. No new case permits a skip or a successful fake consumer.
* **Original acceptance remains required:** no existing UI test body, original Native116 declaration, Release114 selection, 600s case budget, Core receipt, 98% witness, Notes guard or SDK pin is edited. The scope map names existing Notes/TOC/source-link/new-tab regressions that must run alongside this new work. A phone screenshot cannot qualify iPad adaptation.

The Native observation is opt-in DEBUG only: exact command-line flag `-NativeStudySheetAcceptanceEnabled YES`, matching defaults, actual `miniTest10` and valid UUID namespace. It has bounded event/input/output sizes, one-use action IDs plus independently observed bounded delivery IDs, real UIKit parent/child/closing checks and current source/owner binding. It records object identities and source/selection digests, **no text/query content**. Only the existing close, TOC and toggle actions can be invoked. It cannot create a Core ACK, edit selection, save annotations or set presentation state. The three programmatic race cases require actual child/closing observation, actual dismiss callbacks, UI disappearance/new UUID, stale/refused input and unchanged original owner. A replay is not overwritten until its exact new delivery UUID is actually observed as refused. Their inputs are not credited as gestures.

Each new case attaches the actual small report plus the original screenshot/hierarchy collector. The final test teardown retains evidence on failure. Therefore the existing xcresult/attachment export path retains these reports without adding a separate product collector. No new runtime or workflow path has been introduced.

## Execution and freeze instructions

First source-review the packet and run its read-only verifier. On the complete candidate checkout, the bounded macOS command is:

```bash
python3 tools/hq-native-study-sheet-lifecycle.py \
  --root . \
  --output build/native-study-sheet-foundation-attempt1 \
  --before-workspace docs/hq-integration/native-study-sheet-20261120/interactive-dismissal-before.swift
```

The driver retains compiler/runtime stdout and stderr, declared/executed IDs, complete generated sources, original source hashes before/after and the precise original method hashes. Its compile cap is 180s and execution cap 30s per fixture; no timeout increase or module/SDK copy. The existing real Apple app/XCTest build must independently compile all new iOS/UI code; these Foundation fixtures cannot qualify it.

The existing synchronized `Maktabah-iOSUITests` group admits the new UI test file. `PROJECT_MEMBERSHIP.json` proves exactly four PBX additions next to the original Workspace file, in **Maktabah-iOS F30576DD2FA46222005732C6 / Sources F30576E22FA46222005732C6**, with unused deterministic IDs. No widget, macOS or test target gets this iOS presenter source.

At a future Root-owned freeze, update the exact application/source/UI pins and the project proof at **`Scripts/CI/hq-stage2-otzaria-test-additions.json` → `excluded_build_inputs["Maktabah.xcodeproj/project.pbxproj"]`**, then its manifest SHA in `hq-stage2-focused-apple.inputs.json`. The new project blob is in `PROJECT_MEMBERSHIP.json`. The four-line inverse must accompany that pin update. Framework producer, 78 additions, build exclusions and resource/package/SDK pins otherwise remain unchanged. Current active F4/F6 pins are immutable.

## Evidence retained now

`SOURCE_AUTHORITY.json` binds 20 original M40 inputs and seven actual pinned Kit files. `SOURCE_INVERSE.json` and `PROPOSED.patch` contain exact old/new ranges for the two original product files and project. The new file, UI test, Foundation fixtures and driver are complete in the candidate. Original methods are independently checked for preservation by the packet verifier. The local Python controls validate the evidence qualifier and extraction refusal paths; they do not execute or simulate Swift.

`PREPARATION_ATTEMPT01.json` retains an interrupted source-packet preparation (expensive character-level PBX diff; exit130, zero Swift/tests). Its replacement uses bounded line-level inverse ranges. `preparation/SOURCES.json` and the generated baseline/candidate bodies show the actual source extraction, still **zero Swift executions**.

Remaining gates include Apple typecheck/build, actual detent availability at narrow heights, system UIKit presentation geometry, parent/child callbacks, all new Native cases, actual nonempty selection/navigation depth and original cross-tab/backend/Notes regressions. No task completion or new Native PASS is claimed by this packet.
