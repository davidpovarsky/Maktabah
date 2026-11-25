# Focused real Picker locale acceptance

The existing iPad English acceptance retains five real producer callback journeys: plain warm return, plain cold return, read-only reader linked note, warm original rich editing with a newer unsaved second block, and cold rich return with replay protection.

A separate selector, `MiniAppsAnnotationAcceptanceTests/testSharedPickerHebrewRTLUsesNativeEditingAndPersistsPreferences`, is intended to run on the same qualified consumer app/test bundle on iPhone Hebrew and iPad Hebrew. It opens the original reader's Notes action, starts an unsaved original annotation, and invokes its actual MiniApps toolbar. It never writes a result fixture, changes the canonical database directly, or launches an invocation to manufacture acceptance.

The shared helper exercises actual More/Edit, one native Done, add/remove favorites, dragging native reorder handles, persisted ordering after reopening, visibility, and new-window preference. It restores the original preferences through the UI and verifies that dismissing the chooser has enqueued no request. Hebrew asserts the real Hebrew labels, mirrored toolbar positions, and left-side native trailing reorder handles. Each stage retains original app screenshots, Accessibility hierarchy, and the actual preference envelope. A JSON attachment retains observed app launch arguments, device, window frame/count, actual toolbar labels and positions.

Native control translations were read from the installed iOS 27 UIKit resources and the exact shared Picker source; see LOCALIZATION_REFERENCE_READ.json. The source-owned Notes translation was read from the retained original TorahInspectorKit source. Runtime selector/hierarchy differences must be diagnosed from real execution; assertions may not be dropped to manufacture a pass.

## Verified in this checkpoint

The actual Apple Swift 6.4 compiler compiled all 22 files belonging to the UI test target with the new selector and helper. Receipt and complete compressed compiler logs are in picker-locales-complete-target. The changed MiniApps test SHA-256 is 0767c4d2c868c8271bc6bb1ae417005b439dcbdfa9c043abfec8d85de1536359.

This is source compile evidence only. Zero native app UI acceptance cases have executed for this checkpoint. Original consumer app build, binary dependency audit, actual callback tests, Hebrew phone/tablet screenshots, official signing and TestFlight remain pending.
