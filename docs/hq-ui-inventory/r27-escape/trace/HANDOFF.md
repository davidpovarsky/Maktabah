# R27 Escape diagnostic-only handoff

Branch `codex/otzaria-r27-escape-trace-20261115`; source commit **914fa87f5b93e2667571001cd0c762ef58589d88**. Parent source behavior remains U75 (`75ea765d`); the two owned files match the failed native checkout6a54a44f before the diagnostic patch. This is **not a third behavioral correction** and is not a runtime-PASS claim. Existing UI01, workspace-race, U75/evidence branches are preserved; no other source or test path changed.

## Why instrumentation is now justified

Actual run43696201794: Apple SDK build-for-testing PASS; affected native window case **0 fresh PASS /1 FAIL**, Escape dismissal still fails, Inspector NOT_REACHED. Prior eight healthy reader passes remain prior-run evidence. See `../RUNTIME_FAILURE_02.md` for U's raw event/focus inspection.

T and Q independently verified the existing native build log SHA256 `05757479f780d12605c06f8d6b7ced5e5f5d0a00a28a4a2840d34c00121d00eb`: actual SwiftCompile10601/10607 names the changed local `CommandPaletteView.swift` in target CommandPalette;50275/50305 names the adapter in Maktabah-iOS. Packet copied as `compiled-input-evidence.json`. The app code-image hash changed to `dae681fe401bf6d15ad82df3ea67fb1dffba5a27f702fa7a82e645ecd44c54bc`. Existing artifact did not retain the binary or symbol dump; actual handler execution remains untraced. Stale package compilation is unsupported by this evidence. U waited for this evidence before changing source.

## Scope and privacy

Only the two exclusively leased files change, +82/-5:

- `Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift`
- `Source/ChavrusaText/ToolbarSearch/LibraryCommandPaletteAdapter.swift`

An iOS-only `OSLog.Logger` emits fixed stages and Boolean flags: `first`, `mounted`, `keyWindow`, `wantsFocus`, `callback`. No query, book title/text, locator, user/session identifier, path, clipboard content, raw key character/code, arbitrary selector or private view class is logged. Press/text input is classified only as Escape/other, and own action validation as Escape/arrow. There is no global/window interception or responder-tree traversal.

The existing query/focus logic, key commands, Escape matching, first-responder guard, callback actions and results remain the same. New become/resign/ended/cancelled overrides call their original superclass exactly once and return its original result when applicable; callbacks add one log then call the original closure once synchronously. No sleep, new queue, input injection, query rewrite, DEBUG workaround, acceptance flag or test-oracle change. Logging can affect timing; a diagnostic-only pass would require confirmation of the final non-instrumented correction before claiming resolution.

## Required trace contract

Subsystem: **com.davidpovarsky.chavrusatext**. Category: **R27PaletteInput**. Level: **info**.

T already agreed to collect bounded simulator unified logs with info/debug enabled **before owned simulator shutdown on both success and failure**, retaining capture status/stdout as artifacts. Retain code-image hashes and bounded native PaletteTextField symbols if available. Missing/empty logs or a failed collection are an evidence gap, not proof no callback ran. Normal input mount/edit stages establish that capture and the compiled class are active before interpreting absent Escape stages.

| Stages | What actual traces can discriminate |
| --- | --- |
| package/adapter.appear; input.didMoveToWindow/update | Whether this actual field mounted, and its native window/focus flags |
| become/resign.before/after; delegate.begin/endEditing | Actual focus transition ordering around Escape |
| input.keyCommands; input.validate.escape | Whether UIKit queried/validated this input's command |
| pressesBegan/Ended/Cancelled.escape/other; insertText.escape/other | Which event route reaches the input; no text/key contents |
| input.action.escape; input.dismiss.enter/callback/return | Whether the original first-responder gate accepts the event and forwards |
| package.dismiss.forward; adapter.dismiss.forward | Whether the original package/adapter dismissal closure is reached |
| package/adapter.disappear; input.dismantle | Whether the palette truly unmounts after callback delivery |

Do not conclude event consumption, a guard defect or stale state from AX alone. If the callback reaches the adapter without disappearance, any necessary next file/owner must be identified before edits. If no Escape route reaches the proven input while normal input traces are present, investigate delivery with Q/T before another input rewrite.

## T/Q execution and acceptance

T alone integrates **914fa87f5b93e2667571001cd0c762ef58589d88** on the existing U75 integrated source. Q's final compatible test-source tip is **c9295c85a51710e592dc2558e6edb5395b1ecca5**, parent8cbd8db156f63f3d7eaf9abdba68d4cae4d2b4e7, thenab23. It adds a same-hardware-API printable-key positive control (`typeKey("a")` with actual nonempty/changed UI value, no assumption about Latin output under Hebrew layout), real Clear search back to empty, then the original fixture query/result/Escape/dismissal/Inspector oracles. The8cbd parent adds a real post-Escape screen/hierarchy immediately after the same `typeKey` and before the same waiter/teardown. This separates key-injection calibration from application callback evidence. Q retains test-source ownership and the real visible-dismissal oracle. The eight healthy case bodies are unchanged; reuse remains T/Q's impact decision. These test changes have no native result yet.

Only the affected window case is needed for this diagnostic execution. Collect trace plus before/immediate-after Escape snapshots and normal test result. No native outcome is inferred from logs. Inspector stays NOT_REACHED unless the actual original assertions reach it. Q independently interprets events and test result; U handles any proved next source correction under the exact lease. No dispatch, CI, build, signing or simulator execution by U.

## Local verification and rollback

`py -3 docs/hq-ui-inventory/r27-escape/trace/verify_trace.py` records exact source hashes, iOS17/macOS14 syntax parses, whitespace and reverse-patch checks. These are **Windows parsing/source checks only**, with sysroot warnings retained; no Apple SDK typecheck or native UI test by U. The native build PASS above belongs to the preceding U75 run, not this diagnostic commit. No native behavior result exists yet for914fa87f.

T can remove the instrumentation with a normal reviewed revert of **914fa87f5b93e2667571001cd0c762ef58589d88**, restoring U75 behavior. Do not reset branches, delete sessions or alter workspace/database data. Remove diagnostic instrumentation or explicitly review any retained diagnostics as part of the eventual proved correction.
