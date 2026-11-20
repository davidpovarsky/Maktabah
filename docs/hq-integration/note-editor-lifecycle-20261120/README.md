# Original note editor callback lifecycle

Final application fix: `7c6b7998796d817ac915ea4973658236f79234a1`, based on `0bc6be41f03855412d7dd24ee72608a7824fb5a7`. The exact source owner, text-view callback, dismissal callback and workspace setter passed **15/15 portable lifecycle controls** on Windows Swift 6.3.3. This does not establish Native acceptance.

## Defect and correction

One Reader workspace ID survives multiple presentations of the original note editor. The original editor sends its UITextView through a deferred `onCreated` callback and sends nil from `onDisappear`. Before the fix, a callback from an older sheet could replace or clear the current view, rearm presentation activity after dismissal, or invalidate the current scene.

The original `editingAnnotation` remains the single binding. Its existing manual open, Core open, cancel and save-completion assignments use one small setter which creates a UUID before every nonnil assignment. Reopening an equal unsaved Annotation therefore receives a distinct presentation identity. Nil preserves that identity until a later entry replaces it.

The editor closure captures its presentation UUID as a value. The original owner compares it with the live workspace identity and requires an existing annotation. Disappearance retires that identity, including when it arrives before deferred creation. Rejected callbacks return before scene invalidation.

Independent review found that the first fix still invalidated the scene after a rejected `didDismiss`. The follow-up also captures the dismissal UUID in the original sheet modifier, validates it in the owner, rejects duplicate dismissal, and returns a Bool so the scene invalidates only after an accepted transition. An old A dismissal cannot retire a closing B when supplied with its original A token.

## Actual validation

| Evidence | Exact app source | Runtime result | Interpretation |
|---|---|---:|---|
| `red/` | `0bc6be41` | 7 PASS / 6 FAIL / 13 | Original source reproduced six stale creation/disappearance defects. |
| `red-same-driver/` | `0bc6be41` | 7 PASS / 6 FAIL / 13 | Same fixture/driver as first candidate; same generated original Swift unit. |
| `green/` | `19e74a6b` | 13 PASS / 0 FAIL | First correction; historical result does not cover later dismissal controls. |
| `dismissal-red/` | `19e74a6b` | 12 PASS / 3 FAIL / 15 | Expanded exact-method controls reproduced stale live-draft invalidation, old dismissal during new closure, and duplicate invalidation. |
| `dismissal-green/` | `7c6b7998` | 15 PASS / 0 FAIL | Complete scoped fix, including original Session dismissal method. |

Every compile above exited 0 with zero warnings. Failing runtime controls exited 1; passing controls exited 0. The final six static source checks also passed; they are wiring checks, not six additional runtime tests. The final worktree was clean during execution, and all three app source hashes were checked against both the recorded run and the exact Git commit afterward.

SentinelX jobs were `job_a247d91e0b8a` (initial RED), `job_8e22e50ef6bb` (first matched RED/GREEN), and `job_b145889f8c6f` (expanded dismissal RED/GREEN). The initial source-assignment regex was narrowed to distinguish assignment from equality before the matched first comparison; the original generated Swift test unit remained identical. No runtime assertion was weakened.

Each evidence directory retains `RESULT.json`, raw compiler/test logs and the generated Swift unit. Results include source, extracted-method, fixture, driver and generated-source hashes and the exact compiler command. The harness compiles extracted original app methods. Its UIKit, SwiftUI Binding, Reader, Annotation and scene revision objects are explicitly named doubles. For historical signatures, the adapter supplies no missing presentation guard. The candidate setter's access is widened only in the test wrapper; its implementation is unchanged.

## Scope and ownership

Live upstream main was read as `d46af139b3a265399c16d87f5923acd8e3444024` in `bismillah-100/Maktabah`; its complete recursive tree contained 709 entries and none of the three edited app paths. The files are fork-owned, although the workspace resides in a shared namespace.

| Path | Ownership | Change |
|---|---|---|
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneBindings.swift` | Fork host integration | Original note owner checks presentation identity and retirement; dismissal reports whether it changed state. |
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift` | Fork host integration | Passes live identity and callback tokens; rejected creation/disappearance/dismissal does not invalidate the scene. |
| `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift` | Fork-owned original workspace | Adds ephemeral UUID state and a narrow setter/callback connection to the same annotation binding. |
| `Tests/HQ/navigation/NativeNoteEditorOwnerFixtures.swift`, `tools/hq-native-note-editor-ownership.py` | Downstream acceptance tooling | Source-bound regression with explicit boundary doubles. |

The actual editor file `iOSAnnotationEditorSheet.swift`, sheet type, Annotation model, persistence routines, original save/delete/cancel operations, Core contracts, Registry, SDK, database and signing remain outside this diff. No package or Xcode membership was added. `SOURCE_DELTA.patch` records the exact app delta. Reverting the two fix commits restores the previous app behavior; the evidence can remain.

The independent reviewer `github_native_audit` performed source review only. The reviewer identified the intermediate dismissal gap and, after reading `7c6b7998`, found no additional blocking source issue. The reviewer did not run tests.

## Reproduction and remaining gates

Run from the exact checked-out source, with Swift 6 and its runtime on PATH:

```text
python tools/hq-native-note-editor-ownership.py --artifacts-dir <new-empty-directory>
```

Use `--source-ref 19e74a6b3379b7da221806aff90ef8a06320f75f` with the final driver to reproduce the three dismissal failures. This fixture is portable; running it on macOS would still not make it a UIKit presentation test.

The integrated app still requires its existing Apple compile/typecheck and original Native note draft show/cancel/reopen, Save/Cancel, selection/source ownership, scene/background, RTL/accessibility and persistence regressions. Physical iPad acceptance remains separate. In particular, the fixture proves rejection when an old callback carries token A; it does not prove which closure SwiftUI retains or invokes during a real transition. The original `.sheet` and `onDismiss` must be observed in the Native gate. No embedding, persistence, Core, Simulator or device PASS is asserted by these results.
