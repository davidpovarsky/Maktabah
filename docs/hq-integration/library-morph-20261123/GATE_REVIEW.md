# Narrow 9401 composition gate update

Root source review identified a concrete stale condition before the new Apple run: verify-9401-exact-source.py expected a magnifying-glass label and the original palette adapter invocation inside the sidebar file, plus byte equality to the much older FEATURE adapter. The approved morph moves the visual shell to the split and retains that same original palette behind explicit active/surface parameters.

The existing focused build did not invoke that historical verifier; its only existing repository caller was the original adversarial test module. This update makes the required morph guard explicit in the new focused source preflight instead of leaving a future integration conflict.

## Exact scope and review

- Added library_morph_issues and its pinned canonical baseline/path constants.
- Replaced only the two historical palette-layout checks with a branch: existing pre-morph sources keep the unchanged old conditions; a morph source must pass the new composition checks.
- Every unrelated original verifier byte is preserved. Removing the added helper and restoring those two checks reproduces the original verifier byte for byte.
- The existing replacement-palette negative control retains the identical CURRENT_PALETTE_MUST_BE_REUSED rejection assertion. Only its mutation target follows the actual moved invocation, with the historical target retained for older layouts.
- New focused preflight verifies actual working bytes for the four relevant source inputs, executes the morph composition guard, and retains those bindings.
- No native XCTest assertion or expected runtime result changes.

Root approved this gate adaptation and its two test files before edits under the current user's standing execution authorization. This is a required composition-policy update for the requested feature, not evidence of runtime acceptance.

## Enforced behavior

Removing exactly the three-line split-level overlay hook must reproduce the canonical workspace member. This rejects a second surface or a move back inside the detail parent while protecting the original reader and toolbar ownership.

The actual native Button, its existing identifier and frame bridge must remain unique. The single retained shell must contain one original adapter; its real query binding and complete canonical book commands must stay. The shell must retain both children with clipping, opacity, accessibility and hit-testing gates and one SafariGlass surface. An added shadow, conditional child swap or whole-panel drag is rejected.

The original palette results, query synchronization, selected action, recents and UIKit keyboard implementation are compared with canonical source. Only the explicit inactive-action guard and active-focus/shortcut gating are admitted. Standalone defaults remain true.

## Actual verification

Exactly 21 source controls ran once and passed: 13 new positive/mutation controls, plus eight existing controls covering the original toolbar, TOC blob, title duplication, duplicate reader, replacement palette, Inspector action, native profile toolbar and profile switching. GATE_CONTROLS.json and its stdout/stderr bind the actual executed file bytes.

The complete historical 9401 snapshot gate and every historical suite were not executed and are not claimed PASS. The source inventory's broader historical classifications and later approved application changes remain the integration owner's review scope. These controls cannot establish native hit-testing, keyboard behavior, visual fidelity, full-library behavior or physical-device acceptance; the seven source-bound Apple cases remain the decisive next verification.
