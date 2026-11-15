# R27 focused native-input Escape correction — candidate, native verification pending

U / Maya, independent primary chat `01a1dc8a-c7c4-7080-8a49-d61dd056fa47`. Branch `codex/otzaria-r27-escape-20261115`, failed-checkout base `29f8b4d39c7ea7b49d359a8c57236094e623a9ad`. Source commits, in order: `83c13b412e8c38ec354b112d699d53c83d2352d8`, then `75ea765de3d768402bf89798b6006b2aea7f9477` (final source). Lead granted the two exact source paths in `lease.json`; no other application file changed. Existing UI01 `0b19ded4265ae0f0b6d05571b1c23b7bb3d423f8` and workspace-race `f3358012844e1790b8f0e57f25f0be85c46b9549` branches remain preserved. No new application file or target membership.

## Actual failure and evidence boundary

Q reports actual run [43688380348](https://github.com/davidpovarsky/Maktabah/actions/runs/43688380348): **8 UI passed /1 failed /0 skipped** at base29f8. All four iPad reader and four iPhone reader scenarios pass after the prior workspace correction. The sole remaining window case fails line169 after the palette input is keyboard-focused, a fixture title has produced a real hittable result, and `input.typeKey(Escape)` synthesizes an actual event at t85.08–87.11. The palette remains mounted. Inspector assertions are **NOT_REACHED**.

U independently inspected the raw window log154–209, pre-Escape hierarchy `FC8183BB-6BDE-4144-8239-E57AAF8EDEA0.txt` (Keyboard Focused / Focused on the actual search input), and restored screenshot `B7263F5A-2C1D-43AE-A826-E06D13FB060E.png`, which visibly retains the palette. Sources:

`C:/Users/DAVID/Code/Maktabah-hq-integration-20261115/docs/hq-integration/.cache/run-43688380348-selective/artifacts/`

The original adapter already advertises a priority `UIKeyCommand` on an ancestor `UIHostingController`. The original package already places `.onKeyPress(.escape)` on its SwiftUI `TextField`. Therefore a missing shortcut declaration is not the explanation. No event-handler trace from this failed run proves which responder consumed the event. The input/responder delivery gap is an inference from the real failure, not a demonstrated UIKit internals claim.

## Exact correction

- `LibraryCommandPaletteAdapter.swift`: remove the now-superseded ancestor controller wrapper and its Escape command. Mount the same original `CommandPaletteView` directly. Canonical command construction, original book actions, external library query binding, palette identifier and Safari toolbar field are unchanged.
- `CommandPaletteView.swift`: on iOS only, the existing search-field slot is an owned native `UITextField` through `UIViewRepresentable`. This actual editable, focusable input owns Escape/up/down key commands with priority. Unhandled raw Escape presses and the Escape control character through `UIKeyInput.insertText` use the same dismissal path; ordinary presses/text forward to UIKit. Dismissal requires the field itself to be first responder, resigns that field, then calls the existing `onDismiss` closure. This is production input handling, with no DEBUG path or fabricated UI success.
- Native editing changes write the same `$query`; the existing external query synchronization, command matching, rows, recents and selection model are unchanged. Return invokes the existing `runSelection`; up/down invoke the existing selection methods. On iOS, an ordinary State boolean retains focus intent and drives the actual field when attached to its own window; it does not depend on an unattached SwiftUI FocusState. Delegate updates keep this state in sync; dismantling removes callbacks/delegate and resigns only this field. macOS retains its original FocusState/SwiftUI input.
- The input remains a plain clear field, system20 font, label color, original placeholder/accessibility label, no autocorrection/capitalization, Go return key. Layout direction determines native text alignment/semantics. Original search icon, clear action, `esc` hint, material, corner radius, shadow, padding, results/footer and macOS SwiftUI input remain unchanged. Native text metrics/IME/focus/visual parity still require runtime verification.

The exact zero-context diff is `source.patch` (+152/-93 across the two authorized paths). No private hierarchy traversal or class lookup, swizzle, responder-chain replacement, global/window key interception, hidden duplicate text field, focus-stealing controller, dismiss-button substitution, query clearing on Escape, test assertion change, fake rendered reader, database/index or CI/signing change.

## Supported API basis and rejected alternatives

Apple documents that press events target the focused object and unhandled events traverse the responder chain: [Using responders](https://developer.apple.com/documentation/uikit/using-responders-and-the-responder-chain-to-handle-events). [UIKeyCommand priority](https://developer.apple.com/documentation/uikit/uikeycommand/wantspriorityoversystembehavior) reverses the normal text-input/focus-before-command delivery order. [keyCommands](https://developer.apple.com/documentation/uikit/uiresponder/keycommands) are resolved through the active responder chain. [SwiftUI onKeyPress](https://developer.apple.com/documentation/swiftui/view/onkeypress(_:action:)) depends on keyboard focus and hardware key delivery. These documents justify the supported input-owned route; they do not prove the candidate works on iPadOS27.

Rejected: repeating the already-failed ancestor key command or adding another SwiftUI Escape modifier; making the ancestor first responder and taking focus away from editable input; probing private SwiftUI text-field subviews to attach handlers; application/window-wide interception; replacing the Escape oracle with a tap, hiding an AX element, or relaxing the timeout; a broad palette rewrite or new search/selection model. The package input seam was necessary to own the real responder without private traversal; lead extended this exact additional path before editing it.

## Executed verification

`py -3 docs/hq-ui-inventory/r27-escape/verify_source.py` records actual commands/output and immutable source hashes in `verification.json`:

- Swift6.3.3 Windows syntax parses of the two changed files with **active iOS17** and **active macOS14** targets: exit0. Windows sysroot/SDK-settings warnings are retained. This is parsing only: **no Apple SDK typecheck/build**.
- Exact two-path source diff against failed base and normalized source bytes against immutable candidate: checked.
- `git diff --check` and exact patch reverse-check: exit0.
- Native/UI behavioral tests executed by U: **0**. No fake UIKit port-double test or native-PASS claim. Actual baseline remains **8 passed /1 failed** until Q/T produce new evidence. Existing eight passes are prior-run evidence, not reruns of this candidate.

## T/Q acceptance and rollback

T alone integrates both source commits in the stated order through final source `75ea765de3d768402bf89798b6006b2aea7f9477` and performs actual Mac compilation. Q owns the test oracle. Rerun the single failed window case at the exact integrated SHA, preserving real focused-input typing, actual book-result hitability, synthesized Escape and true visible dismissal. Capture before/after artifacts; Inspector must then be reached and independently pass its existing assertions. A remaining visible palette is still a failure.

The changed input also needs targeted preservation evidence for external query updates/clear, Hebrew RTL and LTR/narrow field presentation, Return selection, up/down selection, focus retention, normal typing/paste and marked-text composition. These are identified impact checks, **NOT_RUN by U**; do not count unrelated reader passes as proof of keyboard behavior. T/Q may reuse the eight healthy reader cases only under their existing impact-review policy. Physical iPad acceptance remains open.

Rollback is a normal reviewed revert of `75ea765de3d768402bf89798b6006b2aea7f9477` followed by `83c13b412e8c38ec354b112d699d53c83d2352d8` through T. No destructive reset or deletion of sessions/workspace/database data; schema is unchanged. No main merge, remote CI, signing or release by U.
