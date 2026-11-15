# Escape descriptor/dispatch observation — no behavior correction

Source **5c6670b6f213f8a0defb1eadc32260e85c976dc6**, branch `codex/otzaria-r27-escape-dispatch-20261115`, base86a8b8b4. Exactly one already-leased path changes: `Source/ChavrusaText/Dependencies/CommandPalette/Sources/CommandPalette/Views/CommandPaletteView.swift` (+46/-1). The two U914 source paths at that base equal the completed failing checkout5b46c400. Prior branches/evidence remain preserved. No test, project, window, app-global event or data change.

## Completed native baseline

Run [43708796409](https://github.com/davidpovarsky/Maktabah/actions/runs/43708796409), checkout5b46c400, completed normally/uncancelled. Full summary/tree/raw log align on **0 fresh UI passed /1 failed /0 skipped**, original visible-dismissal assertion182 after actual ordinary hardware calibration, clear, fixture query/result and Escape synthesis. Inspector NOT_REACHED. Cancellation is no longer a confound. Prior eight Q-certified healthy reader passes remain separate reused evidence.

U independently parsed the58event,96,402byte stream SHA256 `de01a33897216e8fc71d254aadd29b85ab8438491d00a8a65186208dcd7ed093`; capture status exit0/forced_stop=false and byte/hash checks agree. Native field/ordinary hardware edit stages establish real class execution. Raw Escape requestt141.31, synthesis143.02, immediate post-Escape capture150.36–150.95, assertion failure182. Near the event, `input.keyCommands` at raw11:57:39.099UTC and surrounding updates retain first/mounted/keyWindow/wantsFocus/callback=true. No Escape validation/action/raw-press/input/dismiss/forward/disappear stage is recorded. Resignation starts only at cleanup11:58:08.905UTC. This is a pre-handler gap, with no evidence that the current first-responder guard rejected the event or that dismissal-state forwarding failed.

U read both pre/post trees C68400C8/68BC3D27 and viewed both55C199FC/93EB0B0A images: same375x486window,345x290palette, actual query/result and keyboard remain visible; field stays KeyboardFocused after Escape. This is not an inference from teardown or AX alone. Q independently verified the visuals, complete trace, actual runtime failure and frozen input/runtime provenance.

Raw root: `C:/Users/DAVID/Code/Maktabah-hq-integration-20261115/docs/hq-integration/.cache/run-43708796409-selective/artifacts/`. The adjacent `baseline.json` pins the inspected files and preserves fixed-stage events, without query/book content.

## Public API investigation

Apple's [inputEscape](https://developer.apple.com/documentation/uikit/uikeycommand/inputescape) is the public Escape string; the existing constructor uses it and explicitly sets priority. [Key-command priority](https://developer.apple.com/documentation/uikit/uikeycommand/wantspriorityoversystembehavior) requests dispatch before text/focus behavior. [target(forAction:withSender:)](https://developer.apple.com/documentation/uikit/uiresponder/target(foraction:withsender:)) normally checks whether a responder can perform the action, then returns that responder or continues up the chain. [validate(_:)](https://developer.apple.com/documentation/uikit/uiresponder/validate(_:)) is documented for command/menu validation; it is **not guaranteed on every hardware press**, so absence of this stage alone is not a defect. These are supported APIs available below the package's iOS17 floor. Windows parsing is not installed-Apple-SDK typechecking.

Static source inspection finds the same command descriptor recreated in `keyCommands` and combined with `super.keyCommands`. Actual inherited Escape descriptors, selector response and system target resolution were not observed in U914. A duplicate/shadowed descriptor is only a hypothesis; no unsupported claim about UIKit duplicate ordering or system consumption is made. Do not filter inherited commands, rename selectors or change handlers before actual evidence warrants it.

## Exact diagnostic delta

Same info category/subsystem: **R27PaletteInput / com.davidpovarsky.chavrusatext**. Existing U914 stages remain.

- `input.registry.escape`: known-input match, empty modifiers, priority, disabled flag, own-action match, `responds(to:)` for the existing own selector, counts of inherited unmodified-Escape matches and their priorities. These are booleans/counts only. Inherited commands and original ordering are preserved; superclass keyCommands is read once, as before.
- `input.target.escape.enter/return/result`: only when UIKit actually asks for the own Escape selector or passes an unmodified-Escape command as sender. Calls `super.target` once, returns its exact result, records own-action/known-sender/non-null/returns-self flags. It never probes target resolution manually.
- `input.validateCommand.escape/result`: only for an actual validation of the own selector or unmodified-Escape command. Calls `super.validate` once, then observes disabled/priority flags; it makes no attribute mutation or synthetic validation call.

No raw key strings/codes, arbitrary selector names, class names, user/query/book text or user IDs are emitted. `responds(to:)` checks only the known own selector; it never invokes it. All existing action/press/input/focus/dismiss logic remains byte-identical after the added block, as does the preceding UI/state code. No new consuming keyboard hook, forced target, manual action invocation, first-responder-guard removal, callback rewrite, hidden control or DEBUG branch. Diagnostic logging can affect timing, so logs alone cannot establish acceptance.

## Interpret before changing behavior

| Actual next observation | Bounded implication |
| --- | --- |
| Own descriptor/selector invalid or disabled | Inspect the specific proven descriptor defect before choosing a correction |
| Inherited Escape matches present | Confirms descriptors exist; does not by itself prove which command wins |
| Actual target resolves nil/elsewhere | Locates a target boundary; do not force self without evidence and review |
| Valid own descriptor, no target/validation/action route | Continue delivery/command-selection investigation; absence of menu validation alone is insufficient |
| Actual handler and callback eventually execute | Correlate native outcome; do not generate artificial calls or infer a UI PASS from logs |

## Handoff, checks and rollback

Q reviews this exact observational delta/impact first. T alone integrates source5c6670b6 on existing U914 with unchanged Qad790 oracles and chooses the authorized affected-case execution. No next CI/run is queued by U. Keep full terminal results, raw category stream/status, immediate pre/post focus screenshots/trees, source/code-image/fixture/runtime provenance and cleanup. Do not rerun eight healthy reader cases without a new impact reason.

`py -3 docs/hq-ui-inventory/r27-escape/dispatch/verify_dispatch.py` records actual iOS17/macOS14 syntax parses, unchanged UI-prefix/action-tail source comparisons, exact source hashes/path scope, whitespace and reverse-patch checks. This is a **source audit/parsing only**: no Apple SDK build or native UI test of5c6670b6 by U. Baseline native failure remains open; new descriptor values and target-route results are **NOT_RUN**.

Normal reviewed revert of **5c6670b6f213f8a0defb1eadc32260e85c976dc6** removes only this extension and restores U914 instrumentation/behavior. Do not reset branches or alter session/workspace/database/index data. Physical iPad acceptance remains open.
