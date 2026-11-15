# U native Cancel candidate — 15 November 2026

Worktree `C:/Users/DAVID/Code/Maktabah-hq-sidebar-20261115`, branch
`codex/otzaria-r27-escape-dispatch-20261115`, clean baseline
`1c4bf763ebd78030dfe61b827e99d64900168b60`. Live upstream main verified by
`git ls-remote` at `d46af139b3a265399c16d87f5923acd8e3444024`.
Actual owner thread `01a1df8a-3373-79e3-b7fa-f6a06cc8b578`, lane U.
Current authorization: HQ `single-manager-wave-20261115/OWNER_ACTIVATION.md`.

| File | Ownership / origin | Change / alternative | Validation |
| --- | --- | --- | --- |
| Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift | Downstream licensed component adaptation, introduced 2a46d52c; absent upstream pin; MIT notice retained | Turn existing visible esc hint into a real standard Cancel button with SwiftUI cancelAction shortcut. Keep existing editable input and command/result model. Repeating failed text-responder interception is insufficient. | Existing focused R27 real native case; visible input disappearance, Inspector close, text/locator/window restoration. |
| Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift | Downstream UI oracle | Import exact retained ad790 test from 3b2619bf; strengthen disappearance with app-wide actual-input query and post-wait screenshot; retain every prior oracle. | Actual XCUITest on existing R27 workflow. |
| Scripts/CI/runtime27.py, existing focused CI dependencies and R27_CASES.json | Downstream CI/test infrastructure | Reuse exact retained 3b2619bf tools in U's worktree; refresh immutable source/test pins, current executor, actual CLI availability. No automatic trigger expansion. | Focused Python checks; native workflow's actual tool/device preflight. |

No Maktabah upstream-owned source, imported engine, project, SDK pin, signing,
release gate or user database edit. Normal reviewed revert restores the candidate.
Existing branch refs and ignored logs remain untouched. No automated upstream
boundary guard claimed; manual lineage review performed.

## Actual baseline

Read original retained `run-43713120298-selective` raw summary, input timeline,
AX tree and screenshots from integration read-only. 0 fresh PASS / 1 FAIL;
67 diagnostic events. The input was first responder in the key window, registry
reported correct Escape/priority/enabled descriptor, but no own action,
validation, raw Escape or dismiss forwarding event occurred. Pre/post screenshot
retains query/caret/result. The AX container disappearance waiter nevertheless
returned and Inspector Close was not hittable. This proves neither dismissal nor
a particular UIKit internal consumer. Do not weaken the oracle or infer a pass.

## Candidate semantics

The presentation now exposes its existing esc affordance as a real Button using
the standard native Cancel shortcut. Pointer/touch/keyboard use the same actual
onDismiss operation, updating the host's existing presentation state. This is a
production control, not a diagnostic callback or AX-only concealment. Native
runtime acceptance is pending until the focused run completes.

Apple documents cancelAction as unmodified Escape:
https://developer.apple.com/documentation/swiftui/keyboardshortcut/cancelaction
The text field's existing priority command was already present in the failing
build; its registration alone does not establish dispatch.
