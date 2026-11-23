# Library search morph — implementation and focused native continuation

Task: 1220036884173010. Base: 1969b2065469b55e38e42cbb838a469ffa6a80f7.

## What changed

The actual iPad workspace NavigationSplitView now mounts one persistent search shell. A three-line upstream hook connects the downstream view; the original detail reader, title, toolbar actions, sidebar/TOC, Inspector, scene lifecycle and iPhone composition remain in place.

The genuine native toolbar Button reserves its actual proposed compact bounds, keeps its identifier, accessibility label/value and original activation role, and passes its full CGRect through the existing nonvisual window bridge. The compact visual shell passes through hit testing so that Button handles activation. The bridge requires the anchor and split overlay to belong to the same actual UIWindow; no global key-window lookup or new window is introduced.

Both children stay in one ZStack at their natural sizes. The outer frame and rounded corners animate with the supplied spring (response 0.52, damping 0.86); clipping reveals the expanded child without squeezing its layout. Child opacity, hit testing and accessibility switch together. The single SafariGlass surface owns the background. There is no dark backdrop, extra glass or added shadow.

The expanded child is the original CommandPaletteView using the real LibraryViewModel.searchQuery binding and existing book commands. Its only new opt-in arguments allow a retained inactive palette and an external surface owner. Defaults preserve the existing standalone background, shadow and autofocus for other callers. Inactive input receives wantsFocus=false immediately, resigns the original UIKit first responder, cancels a pending autofocus task, and releases its keyboard shortcut. Existing query, result/selection, recents, arrow/Return/Escape handling and original errors remain.

Gelatin-derived stretch/offset belongs only to a dedicated 16-point drag handle above the palette; text entry and results never inherit that gesture. Compact press observation uses the native ButtonStyle isPressed state. Reduce Motion disables these effects and the morph spring.

## Geometry and native ownership

A detail-child overlay can draw above its parent at toolbar coordinates without being hittable there. The approved split-level hook gives the surface a parent containing the real native toolbar. Both measurements use the same actual window, and the container measurement is attached to the exact positioned ZStack before safe-area expansion. The overlay includes the top container safe area while retaining keyboard avoidance. The native title keeps its original placement; the search slot reduces to a native-sized icon in narrow detail columns.

This is an implementation decision, not a runtime geometry PASS. Actual screenshots, hit targets, keyboard bounds and source-pinned XCTest outcomes determine acceptance.

## Validation prepared

Two additive native tests preserve every earlier test byte/assertion:
- outside-tap dismissal preserves the canonical query, original reader identity/locator/offset and native compact frame;
- repeated open/close verifies production autofocus with real HID, then verifies a hidden field cannot accept HID input or reclaim focus.

The dedicated focused continuation selects these plus original window-resize/Inspector, keyboard dispatch, pointer/reopen/result, English/LTR and system Reduce Motion cases. It reuses the existing original build and native runner, with an exact product commit/tree pin and owned simulator cleanup. Existing broad accepted suites are not replayed or relabelled.

SOURCE_CONTROLS.json records Linux syntax parsing and actual-byte digests only. Apple SDK compilation, these native tests, physical iPad behavior, full-library 100+ results, both backend journeys and final distribution stay unaccepted until their genuine evidence exists.

## Sources

- Owner-provided MorphingSearchPlaygrounds.swift and SafariToolbarSearch-Playgrounds.zip are retained unchanged with their verified hashes in OWNERSHIP.md.
- Original CommandPalette and Gelatin pins/notices are preserved.
- Apple glassEffect semantics and availability: https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- Apple focus-scoped keyboard event handling: https://developer.apple.com/documentation/swiftui/view/onkeypress(_:action:)
- Exact Apple SDK/compiler behavior is verified by the selected existing Xcode authority runner; Linux parsing is not a substitute.
