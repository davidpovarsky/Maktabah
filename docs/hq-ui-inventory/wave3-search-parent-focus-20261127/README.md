# UI-03 Search parent and original query input

Base: `cbf619cc897e17aae723112ecef31ff65f819eba`. This packet adds the finite
component `native.search.queryEntry` to the existing `native.search` parent.
The title is **Open query input / פתיחת שורת השאילתה**. It opens the original
parent from another page and focuses the same original `UISearchTextField`.
The old `native.search.query` / **Search field** contract still requires the
original field to be visible already; its original rejection test is unchanged.

## Original ownership and implementation

The original registry, public v2 adapter, composition, Core admission, scene
command, deadline and receipt remain the execution path. Discovery reads actual
availability. Before the first Core await, the scene retains one original
parent proof, then the existing component owner retains that same proof. It
does not acquire a replacement grant or retry through another executor.

`MaktabahNativeSearchEntry.swift` contains the downstream binding and fixed
anchor. It captures the original scene/workspace mapping owner and epochs,
backend publisher, Search session/model identity and input read set. Original
Observation inputs use a one-shot invalidation latch; the original Zayit
`matchMode` Combine publisher has its own one-shot subscription. Restoring an
earlier query, scope, filter, selected-book set or owner cannot restore proof.
No query, scope, private book/node identifier or executable closure is added to
the public component token.

The original `iOSMainView` continues to own its `@State selectedTab` and
`showSettings`. A scene-lived publication object contains only two monotonic
counters. Its wrappers forward the original Binding and Transaction unchanged,
recording every write before SwiftUI can coalesce it, including equal writes.
All three original layout/routing injections, fourteen original DEBUG tab
assignments, the original Settings sheet/Done path and DEBUG Settings assignment
use those wrappers. No currentMode publisher or switchToMode call is added.
The original manager records each existing currentMode publication separately.
All counters fail closed permanently on overflow and have no public reset.

The retained transition expects precisely zero or one original tab write and
the matching original TabView mode publication. It expects zero Settings writes
and, on a phone only, precisely zero or one pop of the same currently presented
Reader. The active group/profile/tab/model remain owned by the original store.
Settings, Donation, book information, other original modals, advanced options
and local Search overlays block the command; no modal or query is cleared.
Original local overlay setters retire proof synchronously before their writes.

The field bridge is attached to the original `NativeGlobalSearchField`.
Replacement or detach/reattach rotates its lifetime and retires proof. Only
actual original field layout, original mode publication, parent visibility or
canonical apply to an already-visible field can continue rendering. The same
retained validator is checked before and after first-responder acquisition.
ACK still requires the actual parent witness plus original-field first responder,
exact window/scene, visibility through clipped ancestors and scroll viewport,
and the fixed new component witness. No timer, forced layout, synthetic ACK or
direct decoder call was introduced.

## Actual validation and preserved failures

| Evidence | Observed outcome | Scope |
| --- | --- | --- |
| Lifecycle attempt 2 | Compilation failed | Explicit boundary declarations were internal while the unchanged original owner exports public types; no app acceptance |
| Lifecycle attempt 3 | 39 PASS / 0 FAIL | Actual entry, shared parent setter, original manager metadata, original component owner/latch over explicit UIKit/Combine/app-domain/lifetime inputs |
| Original root-publication baseline, attempt 4 | 41 PASS / 3 FAIL, exit 1 | Demonstrates tab A→B→A before delayed mode publication, tab ABA after parent apply, and Settings true→false before mount |
| Publication candidate, attempt 5 | 52 PASS / 0 FAIL | All original 39 scenario bodies retained, plus original-root/history/overflow/transaction/advanced-options cases |
| Final source, attempt 6 | 52 PASS / 0 FAIL | Verifies all source hashes and complete root caller hooks; reuses the compiled attempt-5 executable only after proving all six compiled inputs byte-identical, then actually runs it again |
| Deliberate one-shot-removal variant | 42 PASS / 10 FAIL, exit 1 | Removes only `try observation.validate();` from an isolated copy; app source is unchanged |
| iOS 27 syntax checks | All 12 changed Swift files parse | Linux frontend syntax, with final MainView and Session receipts overriding their earlier hashes; no Apple app typecheck |
| Four new original native selectors | NOT RUN | Require a qualified integrated app and genuine system delivery |

The generator's first missing-input failure is retained separately. Raw compile
and run logs, exact generated source capsules, hashes, stopped/failed attempts
and explicit fixture boundaries remain under `validation/`. The private
Foundation/Observation module cache was reused; no dependency tree or full
checkout was copied. The standalone proof does not compile the SwiftUI owning
body, run the real app domain, issue a Core grant or prove actual UIKit layout.
The complete app SDK build and original native acceptance remain required.

The prior **187,907 bytes** of `NativeRoutingAcceptanceTests.swift` are exact,
with original Git blob `54b4aa02f673921ab7ce83cac9fcd584f98f8acd`. In particular,
`testPublicV2SearchComponentRequiresAlreadyVisibleOriginalField` is untouched.
No Native116 or Release114+2 selector, count, timeout or assertion is replaced.

## Four focused native selectors

The new `NativeSearchEntryAcceptanceTests.swift` declares two iPad selectors and
two phone selectors; only these explicit selectors are proposed, not inherited
whole suites. Cold cases start on the original canonical Reader, discover the
distinct real system entity and execute the original App Intent. Warm cases
type a private query through the original field, navigate to original History,
then deliver the real public v2 URL. A second warm delivery exercises the
already-selected parent without a redundant root write.

Each case requires actual original field geometry/hittability, real keyboard,
one fresh strict native receipt, the corresponding exact fixed-component receipt
in the same original scene, unchanged original workspace ownership/order/backend/
book identity, and no automatic Search submission. Warm cases also compare the
private query and original visible mode/book-filter labels. Typing after delivery
uses the system's current responder without tapping the field. These checks do
not claim full Reader selection, viewport, TOC expansion or restoration coverage.

## Integration and remaining acceptance

Register only the new `Integration/MaktabahNativeSearchEntry.swift` in the iOS app
Sources phase beside the existing native routing integration files. The existing
test target uses synchronized file membership; root should verify the new test
file is admitted without duplicate PBX membership. Root owns the shared PBX edit.

The English/Hebrew title is an explicit integration dependency. Root reports it
has added the exact pair to the current shared catalog; this branch does not
edit `Localizable.xcstrings`. Protected original MainView/manager/view changes
need the project's authentic source-bound ownership workflow on the integrated
candidate. Historical signatures are not manufactured or reused for new bytes.

This closes a source implementation gap for opening and focusing one original
query input, subject to integrated SDK/native acceptance. It does not implement
new public query/scope/mode setters, submit Search, select an arbitrary result,
relax existing Search-results limits, or prove all 294 inventory rows. The current
294/51 audit remains a separate source-bound checkpoint. Complete native cold/
warm behavior, original already-visible refusal, background/window/keyboard
transitions, Hebrew/English/RTL/VoiceOver behavior and final production acceptance
remain pending. Physical iPad/iPhone testing has not been performed by this lane.

The original attempt-2 compiler diagnostic is committed as lossless COMPILE.log.gz because its original caret gutters contain trailing spaces. validation/RAW_LOG_STORAGE.json binds both byte streams; no diagnostic line was edited or discarded. Its raw file and executed control binaries remain on the execution host.
