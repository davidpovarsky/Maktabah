# Workspace Settings boundary correction

Root review of 26ebcfe9 identified a real mismatch: Workspace parent selection cleared the original Settings binding, while the new contract requires unrelated presentations to block. This follow-up removes that dismissal and requires the original Settings flag to remain false at every Workspace readiness check.

Cold admission now also reads the existing MaktabahNativeWindowSource.isPresentationReady(in:). That original scene-owned predicate rejects presented UIKit controllers and unfinished controller transitions even after a SwiftUI sheet binding becomes false. A begun observation is insufficient to skip this check. Only the exact command/request with an already applied, retained original Workspace source can await its own original mount.

Warm original Profiles/Overview sheets use their own existing host evidence because the generic no-presented-controller predicate would reject the expected original sheet. Their passive witness checks the actual key foreground scene/window, clipping and visibility, top presented controller ancestry, appearance, and ancestor/top transition state. The full native destination witness remains separately required for a receipt. Settings, donation, reader popover, book-info, note-editing and study-chat blockers are never exempted by an applied Workspace command.

## Dependency and source scope

Apply this narrow commit after shared 26ebcfe9 and feature 674a9784 + 2135f160. The latter provides the read-only isContinuingAppliedRequest(parent:requestID:), which validates the exact applied pending request, retained source and original host tokens without calling the Session validator recursively, preparing authority or changing state.

Only MaktabahNativeSceneBindings.swift and MaktabahNativeSceneSession.swift change in product source. The Notes root selection fix, previous 11 native Workspace selectors, historical 20-control evidence, original 294 inventory, Native116 and Release114 selectors/counts/deadlines remain intact.

## Actual checks

The Mac executed 32 source predicate controls: 32 passed, zero failed. The harness includes five verbatim production method/property bodies. The UIKit window readiness result, original parent facets and retained-proof API are explicit synthetic boundary inputs; these controls do not execute UIKit, Core admission, App Intents, the app target or simulator tests.

Three deliberately weakened source variants compiled and failed as expected:

- Restoring Settings dismissal and removing its blocker: 29 passed, 3 failed.
- Removing the cold native window gate: 27 passed, 5 failed.
- Treating a merely begun matching command as applied: 29 passed, 3 failed.

The source files also passed iOS27 syntax parsing. This is not Apple app SDK type checking. All 11 original-system Workspace selectors remain unrun here and require the integrated original candidate.

The existing private Mac module cache was reused. The new private control directory used 818534 bytes; measured free disk changed from 20648275968 to 20647333888 bytes. No app source, app build checkout or shared SDK/DerivedData cache was changed.

SOURCE.json is the immutable pre-execution input manifest and correctly records NOT_RUN at its creation. MAC_RESULT.json plus the four exact raw logs are the subsequent actual execution evidence. Old failure/control artifacts are retained.
